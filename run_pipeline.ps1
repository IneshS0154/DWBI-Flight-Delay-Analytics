# Windows equivalent of run_pipeline.sh.
# Re-runs the full pipeline from scratch: schema -> extract -> transform -> load -> validate
#
#   .\run_pipeline.ps1                          # local SQL Server, Windows authentication
#   .\run_pipeline.ps1 -Server "localhost\SQLEXPRESS"
#   .\run_pipeline.ps1 -Docker                  # SQL Server in the dwbi-sqlserver container
param(
    [string]$Server  = "localhost",
    # Must be readable by the SQL Server service account (NT Service\MSSQLSERVER),
    # which usually cannot read your user profile (Desktop, Documents, ...).
    [string]$DataDir = "C:\DWBI_data\",
    # Docker mode: SQL authentication against the container published on $Port.
    [switch]$Docker,
    [string]$Container = "dwbi-sqlserver",
    [int]$Port = 14330,
    [string]$SaPassword = $env:MSSQL_SA_PASSWORD
)
$ErrorActionPreference = "Stop"
if ($Docker -and -not $SaPassword) {
    throw "Set `$env:MSSQL_SA_PASSWORD (or pass -SaPassword) to the container's sa password."
}
Set-Location $PSScriptRoot

$sources = @("data\raw\flight_delays_2008_sample.csv",
             "data\sources\airports.dat",
             "data\sources\airport_daily_weather_2008.json")

if ($Docker) {
    $env:DataDir = "/var/opt/mssql/"
    $auth = @("-S", "tcp:localhost,$Port", "-U", "sa", "-P", $SaPassword)
    foreach ($s in $sources) {
        docker cp $s "${Container}:/var/opt/mssql/$(Split-Path $s -Leaf)"
        if ($LASTEXITCODE -ne 0) { throw "docker cp failed for $s" }
    }
} else {
    if (-not $DataDir.EndsWith("\")) { $DataDir += "\" }
    $env:DataDir = $DataDir   # sqlcmd picks up $(DataDir) from the environment
    $auth = @("-S", $Server, "-E")
    New-Item -ItemType Directory -Force $DataDir | Out-Null
    Copy-Item $sources -Destination $DataDir -Force
}

$files = @(
    "sql\00_staging\01_create_staging.sql",
    "sql\01_dimensions\01_create_dimensions.sql",
    "sql\02_facts\01_create_fact.sql",
    "sql\00_staging\02_load_staging.sql",
    "sql\03_etl\01_transform_clean.sql",
    "sql\03_etl\02_load_dimensions.sql",
    "sql\03_etl\03_load_fact.sql",
    "sql\03_etl\04_validate.sql",
    "sql\04_datamart\01_create_datamart.sql",
    "sql\04_datamart\02_load_datamart.sql",
    "sql\05_presentation\01_create_views.sql"
)
foreach ($f in $files) {
    Write-Host "=== $f"
    sqlcmd @auth -C -b -W -i $f
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd failed on $f" }
}
