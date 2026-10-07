USE DWBI_FlightDelay;
GO

IF SCHEMA_ID('mart') IS NULL
    EXEC('CREATE SCHEMA mart');
GO

IF OBJECT_ID('mart.FactDailyCarrierAirportPerformance', 'U') IS NOT NULL
    DROP TABLE mart.FactDailyCarrierAirportPerformance;
GO

CREATE TABLE mart.FactDailyCarrierAirportPerformance (
    DailyPerformanceKey     BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,

    -- Conformed dimension keys, reused as-is from the EDW (no duplicated dimension tables)
    DateKey                 INT NOT NULL REFERENCES dw.DimDate(DateKey),
    CarrierKey              INT NOT NULL REFERENCES dw.DimCarrier(CarrierKey),
    OriginAirportKey        INT NOT NULL REFERENCES dw.DimAirport(AirportKey),

    -- Aggregated volume measures
    FlightCount             INT NOT NULL,
    CancelledCount          INT NOT NULL,
    DivertedCount           INT NOT NULL,

    -- Aggregated performance measures
    OnTimeRatePct           DECIMAL(5,2) NULL,   -- % of flights with ArrDelay <= 15 minutes
    AvgDepDelayMinutes      DECIMAL(6,2) NULL,
    AvgArrDelayMinutes      DECIMAL(6,2) NULL,

    -- Aggregated delay-cause measures (average minutes among flights with a recorded cause)
    AvgCarrierDelayMinutes      DECIMAL(6,2) NULL,
    AvgWeatherDelayMinutes      DECIMAL(6,2) NULL,
    AvgNASDelayMinutes          DECIMAL(6,2) NULL,
    AvgSecurityDelayMinutes     DECIMAL(6,2) NULL,
    AvgLateAircraftDelayMinutes DECIMAL(6,2) NULL,

    -- Aggregated same-day weather at the origin airport
    AvgOriginTempMaxC          DECIMAL(5,2) NULL,
    AvgOriginPrecipitationMm   DECIMAL(6,2) NULL,

    LoadDateTime            DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO

CREATE INDEX IX_DailyPerf_DateKey ON mart.FactDailyCarrierAirportPerformance(DateKey);
CREATE INDEX IX_DailyPerf_CarrierKey ON mart.FactDailyCarrierAirportPerformance(CarrierKey);
GO
