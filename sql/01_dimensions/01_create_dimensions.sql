/* ============================================================
   Dimension tables — DWBI_FlightDelay data warehouse
   Star schema. DimAirport is role-played as Origin and Destination.
   ============================================================ */

USE DWBI_FlightDelay;
GO

IF SCHEMA_ID('dw') IS NULL
    EXEC('CREATE SCHEMA dw');
GO

-- Both fact tables reference the dimensions, so they must be dropped first on re-runs
IF OBJECT_ID('mart.FactDailyCarrierAirportPerformance', 'U') IS NOT NULL DROP TABLE mart.FactDailyCarrierAirportPerformance;
IF OBJECT_ID('dw.FactFlightDeparture', 'U') IS NOT NULL DROP TABLE dw.FactFlightDeparture;
GO

/* ---------- DimDate: full 2008 calendar (366 days, leap year) ---------- */
IF OBJECT_ID('dw.DimDate', 'U') IS NOT NULL DROP TABLE dw.DimDate;
CREATE TABLE dw.DimDate (
    DateKey         INT             NOT NULL PRIMARY KEY,   -- YYYYMMDD
    FullDate        DATE            NOT NULL,
    DayOfMonth      TINYINT         NOT NULL,
    DayName         VARCHAR(10)     NOT NULL,
    DayOfWeek       TINYINT         NOT NULL,               -- 1=Sunday..7=Saturday
    IsWeekend       BIT             NOT NULL,
    MonthNumber     TINYINT         NOT NULL,
    MonthName       VARCHAR(10)     NOT NULL,
    Quarter         TINYINT         NOT NULL,
    Year            SMALLINT        NOT NULL                -- hierarchy: Date -> Month -> Quarter -> Year
);
GO

/* ---------- DimTime: every minute of day, for scheduled departure time-of-day ---------- */
IF OBJECT_ID('dw.DimTime', 'U') IS NOT NULL DROP TABLE dw.DimTime;
CREATE TABLE dw.DimTime (
    TimeKey         INT             NOT NULL PRIMARY KEY,   -- HHMM, e.g. 1429
    HourNumber      TINYINT         NOT NULL,
    MinuteNumber    TINYINT         NOT NULL,
    TimeOfDayBand   VARCHAR(20)     NOT NULL                -- hierarchy: Time -> Hour -> TimeOfDayBand
);
GO

/* ---------- DimCarrier: airline codes enriched with real, publicly known airline names ---------- */
IF OBJECT_ID('dw.DimCarrier', 'U') IS NOT NULL DROP TABLE dw.DimCarrier;
CREATE TABLE dw.DimCarrier (
    CarrierKey      INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CarrierCode     VARCHAR(10)     NOT NULL UNIQUE,        -- BTS/IATA UniqueCarrier code, e.g. 'WN'
    CarrierName     VARCHAR(100)    NOT NULL                -- e.g. 'Southwest Airlines'
);
GO

/* ---------- DimAirport: sourced from OpenFlights (Task 2), role-played as Origin/Dest ---------- */
IF OBJECT_ID('dw.DimAirport', 'U') IS NOT NULL DROP TABLE dw.DimAirport;
CREATE TABLE dw.DimAirport (
    AirportKey      INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    IATA            VARCHAR(10)     NOT NULL UNIQUE,
    ICAO            VARCHAR(10)     NULL,
    AirportName     VARCHAR(200)    NOT NULL,
    City            VARCHAR(100)    NOT NULL,
    Country         VARCHAR(100)    NOT NULL,               -- hierarchy: Airport -> City -> Country
    Latitude        DECIMAL(9,6)    NOT NULL,
    Longitude       DECIMAL(9,6)    NOT NULL,
    AltitudeFt      INT             NOT NULL
);
GO

/* ---------- DimCancellationReason: BTS standard cancellation codes (real, publicly documented) ---------- */
IF OBJECT_ID('dw.DimCancellationReason', 'U') IS NOT NULL DROP TABLE dw.DimCancellationReason;
CREATE TABLE dw.DimCancellationReason (
    CancellationReasonKey  INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CancellationCode        CHAR(1)       NOT NULL UNIQUE,   -- BTS code: A/B/C/D/N
    Description              VARCHAR(50)   NOT NULL          -- Carrier/Weather/National Air System/Security/Not Applicable
);
GO
