/* ============================================================
   EXTRACT: load all three raw sources into staging, unmodified.
   Files are copied to $(DataDir) (a folder the SQL Server service
   can read) by run_pipeline.sh / run_pipeline.ps1 first.
   ============================================================ */
USE DWBI_FlightDelay;
GO

/* ---------- Source 1: Flights CSV ---------- */
TRUNCATE TABLE stg.Flights;
BULK INSERT stg.Flights
FROM '$(DataDir)flight_delays_2008_sample.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);
GO

/* ---------- Source 2: Airports reference (no header row in source) ---------- */
TRUNCATE TABLE stg.Airports;
BULK INSERT stg.Airports
FROM '$(DataDir)airports.dat'
WITH (FORMAT = 'CSV', FIRSTROW = 1, FIELDQUOTE = '"', FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);
GO

/* ---------- Source 3: Weather (JSON, parsed natively via OPENJSON) ---------- */
TRUNCATE TABLE stg.Weather;
INSERT INTO stg.Weather (IATA, WeatherDate, TempMaxC, TempMinC, PrecipitationMm, SnowfallCm, WindSpeedMaxKmh)
SELECT j.iata, j.weatherDate, j.tempMaxC, j.tempMinC, j.precipitationMm, j.snowfallCm, j.windSpeedMaxKmh
FROM OPENROWSET(BULK '$(DataDir)airport_daily_weather_2008.json', SINGLE_CLOB) AS raw
CROSS APPLY OPENJSON(BulkColumn, '$.records')
    WITH (
        iata            VARCHAR(10)  '$.iata',
        weatherDate     VARCHAR(20)  '$.date',
        tempMaxC        VARCHAR(20)  '$.tempMaxC',
        tempMinC        VARCHAR(20)  '$.tempMinC',
        precipitationMm VARCHAR(20)  '$.precipitationMm',
        snowfallCm      VARCHAR(20)  '$.snowfallCm',
        windSpeedMaxKmh VARCHAR(20)  '$.windSpeedMaxKmh'
    ) AS j;
GO

SELECT 'Flights' AS t, COUNT(*) AS n FROM stg.Flights
UNION ALL SELECT 'Airports', COUNT(*) FROM stg.Airports
UNION ALL SELECT 'Weather', COUNT(*) FROM stg.Weather;
GO
