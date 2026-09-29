# DWBI Flight Delay Analytics

**IT3101 — Design and Implementation of a Data Warehouse and Business Intelligence Solution**
SLIIT, BSc (Hons) in Information Technology

A complete data warehouse and BI solution built on real US airline on-time performance data
(2008), designed and implemented end-to-end: dimensional modelling, ETL, a dependent data mart,
and an interactive Power BI dashboard.

The full task-by-task report is in **[Submission.md](Submission.md)**.

## Business scenario

Analysing US domestic flight delays to answer operational questions an airline or airport
operator actually needs answered: which delay causes dominate, how much weather really costs in
delay minutes, which carriers/airports underperform, and how delay varies by season and time of
day. See [Submission.md](Submission.md#task-1-dataset-selection-and-business-scenario-identification-10-marks)
for the full write-up.

## Data sources

Three genuinely independent, real, third-party-published sources — chosen specifically so every
join resolves on an exact key (IATA airport code, calendar date) rather than free-text matching:

| Source | Format | What it provides |
|---|---|---|
| [Airline Delay and Cancellation Data](https://www.kaggle.com/datasets/giovamata/airlinedelaycauses) (Kaggle, US DOT/BTS) | CSV | 200,000 flight records (stratified sample of 1.94M), with BTS delay-cause breakdown |
| [OpenFlights airport database](https://github.com/jpatokal/openflights) | CSV | Airport name/city/country/coordinates for all 304 airports used |
| [Open-Meteo Historical Weather API](https://open-meteo.com/en/docs/historical-weather-api) | JSON (live API) | Daily temperature/precipitation/wind for every airport, fetched for 2008 |

Full provenance, join verification and data-preparation steps: [Submission.md, Task 2](Submission.md#task-2-data-source-identification-and-preparation-10-marks).

## Architecture

```
Data Source Layer      →  Data Integration Layer (ETL)  →  Storage Layer            →  Presentation Layer
CSV / CSV / JSON API      Extract → Transform → Load        stg → dw (star schema)     Power BI
                                                              → mart (data mart)
```

Full diagram and component explanation: [Submission.md, Task 3](Submission.md#task-3-data-warehouse-architecture-design-10-marks).

## Star schema

- **Fact**: `dw.FactFlightDeparture` — one row per flight, 200,000 rows
- **Dimensions**: `DimDate`, `DimTime`, `DimCarrier`, `DimAirport` (role-played as Origin/Destination), `DimCancellationReason`
- **Data mart**: `mart.FactDailyCarrierAirportPerformance` — pre-aggregated by (Date, Carrier, Origin Airport), 93,729 rows

Full schema diagram, table descriptions, keys and design assumptions: [Submission.md, Task 4](Submission.md#task-4-dimensional-data-warehouse-design-and-implementation-20-marks).

## Tech stack

- **Database**: Microsoft SQL Server (Azure SQL Edge, via Docker — see below)
- **ETL**: T-SQL only (no external ETL tool)
- **BI**: Power BI Desktop, connected live to the warehouse
- **Source prep**: Python (only used to build/fetch the two reference sources in `data/sources/`, not for the ETL itself)

## Project structure

```
Submission.md                 Full task-by-task report (start here)
sql/
  00_staging/                 Staging table DDL + Extract scripts
  01_dimensions/               Dimension table DDL
  02_facts/                    Fact table DDL
  03_etl/                      Transform, dimension/fact Load, Validate
  04_datamart/                 Data mart DDL + load
  05_presentation/             Power BI-facing views (flattened, human-readable)
data/
  raw/                         Sampled flight delay CSV
  sources/                     Airport reference, weather JSON, fetch scripts
run_pipeline.sh                Rebuilds the entire warehouse from scratch
_archive_ride_hailing/         An earlier iteration of this project (ride-hailing dataset),
                               preserved for history — not part of the current submission
```

## Running the pipeline

Requires Docker.

```bash
# 1. Start SQL Server (Azure SQL Edge — works on both Apple Silicon and Intel/AMD)
docker run -e "ACCEPT_EULA=1" -e "MSSQL_SA_PASSWORD=<your-password>" \
  -p 1433:1433 --name dwbi-sqlserver \
  -v dwbi_sql_data:/var/opt/mssql \
  -d mcr.microsoft.com/azure-sql-edge:latest

# 2. Run the full ETL pipeline (creates schema, extracts, transforms, loads, validates)
MSSQL_SA_PASSWORD=<your-password> ./run_pipeline.sh
```

This rebuilds everything from scratch every run — safe to re-run any time. All 9 ETL validation
checks should report `PASS` (see [Submission.md, Task 5](Submission.md#task-5-etl-process-development-20-marks)
for what each check verifies).

## Connecting a BI tool

Power BI Desktop (Windows) or any SQL Server client can connect to `localhost,1433` (or the host
machine's LAN IP/hostname, if connecting from a separate VM), database `DWBI_FlightDelay`, SQL
authentication. Point the tool at the views in `dw.vw_FlightDetail` and
`mart.vw_DailyCarrierAirportPerformance` rather than the raw star schema tables — they're
pre-joined and human-readable. Full dashboard build spec (measures, visuals, pages):
[Submission.md, Task 7](Submission.md#task-7-olap-analysis-and-business-intelligence-dashboard-development-15-marks).

## Status

| Task | Status |
|---|---|
| 1. Dataset Selection & Business Scenario | Done |
| 2. Data Source Identification & Preparation | Done |
| 3. DW Architecture Design | Done |
| 4. Dimensional DW Design & Implementation | Done |
| 5. ETL Process Development | Done |
| 6. Data Mart Development | Done |
| 7. OLAP Analysis & BI Dashboard | In progress (Power BI) |
| 8. Business Insights & Recommendations | Done |

## AI usage

AI (Claude) was used as a supporting tool for brainstorming, SQL/ETL script drafting, and report
structuring throughout this project. See [Submission.md, Usage of AI](Submission.md#usage-of-ai)
for the full disclosure.
