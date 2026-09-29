/* ============================================================
   Staging tables for the Flight Delay project.
   One staging table per source, mirroring each source's native
   shape. No cleansing here — that happens in sql/03_etl/.
   ============================================================ */

IF DB_ID('DWBI_FlightDelay') IS NULL
BEGIN
    CREATE DATABASE DWBI_FlightDelay;
END
GO

USE DWBI_FlightDelay;
GO

IF SCHEMA_ID('stg') IS NULL
    EXEC('CREATE SCHEMA stg');
GO

/* ---------- Source 1: Flight On-Time Performance (CSV, US DOT/BTS via Kaggle) ---------- */
IF OBJECT_ID('stg.Flights', 'U') IS NOT NULL DROP TABLE stg.Flights;
CREATE TABLE stg.Flights (
    Year                    VARCHAR(10),
    Month                   VARCHAR(10),
    DayofMonth              VARCHAR(10),
    DayOfWeek               VARCHAR(10),
    DepTime                 VARCHAR(20),
    CRSDepTime              VARCHAR(20),
    ArrTime                 VARCHAR(20),
    CRSArrTime              VARCHAR(20),
    UniqueCarrier           VARCHAR(10),
    FlightNum               VARCHAR(20),
    TailNum                 VARCHAR(20),
    ActualElapsedTime       VARCHAR(20),
    CRSElapsedTime          VARCHAR(20),
    AirTime                 VARCHAR(20),
    ArrDelay                VARCHAR(20),
    DepDelay                VARCHAR(20),
    Origin                  VARCHAR(10),
    Dest                    VARCHAR(10),
    Distance                VARCHAR(20),
    TaxiIn                  VARCHAR(20),
    TaxiOut                 VARCHAR(20),
    Cancelled               VARCHAR(5),
    CancellationCode        VARCHAR(5),
    Diverted                VARCHAR(5),
    CarrierDelay            VARCHAR(20),
    WeatherDelay            VARCHAR(20),
    NASDelay                VARCHAR(20),
    SecurityDelay           VARCHAR(20),
    LateAircraftDelay       VARCHAR(20)
);
GO

/* ---------- Source 2: Airport Reference (CSV, OpenFlights) ---------- */
IF OBJECT_ID('stg.Airports', 'U') IS NOT NULL DROP TABLE stg.Airports;
CREATE TABLE stg.Airports (
    AirportID   VARCHAR(20),
    Name        VARCHAR(200),
    City        VARCHAR(100),
    Country     VARCHAR(100),
    IATA        VARCHAR(10),
    ICAO        VARCHAR(10),
    Lat         VARCHAR(30),
    Lon         VARCHAR(30),
    Alt         VARCHAR(20),
    TZOffset    VARCHAR(10),
    DST         VARCHAR(5),
    TZ          VARCHAR(50),
    AirportType VARCHAR(20),
    SourceName  VARCHAR(30)
);
GO

/* ---------- Source 3: Historical Weather (JSON, Open-Meteo API) ---------- */
IF OBJECT_ID('stg.Weather', 'U') IS NOT NULL DROP TABLE stg.Weather;
CREATE TABLE stg.Weather (
    IATA              VARCHAR(10),
    WeatherDate       VARCHAR(20),
    TempMaxC          VARCHAR(20),
    TempMinC          VARCHAR(20),
    PrecipitationMm   VARCHAR(20),
    SnowfallCm        VARCHAR(20),
    WindSpeedMaxKmh   VARCHAR(20)
);
GO
