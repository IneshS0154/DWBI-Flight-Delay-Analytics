/* ============================================================
   FactFlightDeparture
   Business process : Flight departure (a scheduled US domestic flight)
   Grain             : one row per flight record in the source sample
   ============================================================ */

USE DWBI_FlightDelay;
GO

IF OBJECT_ID('dw.FactFlightDeparture', 'U') IS NOT NULL DROP TABLE dw.FactFlightDeparture;
CREATE TABLE dw.FactFlightDeparture (
    FlightDepartureKey       BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,

    -- Degenerate dimensions (descriptive, not worth a separate dimension table)
    FlightNum                 VARCHAR(20)   NOT NULL,
    TailNum                   VARCHAR(20)   NULL,

    -- Foreign keys
    DateKey                     INT         NOT NULL REFERENCES dw.DimDate(DateKey),
    ScheduledDepTimeKey          INT        NOT NULL REFERENCES dw.DimTime(TimeKey),
    CarrierKey                    INT       NOT NULL REFERENCES dw.DimCarrier(CarrierKey),
    OriginAirportKey                INT     NOT NULL REFERENCES dw.DimAirport(AirportKey),
    DestAirportKey                   INT    NOT NULL REFERENCES dw.DimAirport(AirportKey),
    CancellationReasonKey             INT   NOT NULL REFERENCES dw.DimCancellationReason(CancellationReasonKey),

    -- Measures: schedule/operational performance
    ScheduledElapsedMinutes    DECIMAL(6,1) NULL,
    ActualElapsedMinutes       DECIMAL(6,1) NULL,
    AirTimeMinutes             DECIMAL(6,1) NULL,
    DepDelayMinutes            DECIMAL(6,1) NULL,
    ArrDelayMinutes            DECIMAL(6,1) NULL,
    TaxiInMinutes              DECIMAL(6,1) NULL,
    TaxiOutMinutes             DECIMAL(6,1) NULL,
    DistanceMiles              DECIMAL(7,1) NULL,

    -- Measures: BTS delay-cause breakdown (minutes)
    CarrierDelayMinutes        DECIMAL(6,1) NULL,
    WeatherDelayMinutes        DECIMAL(6,1) NULL,
    NASDelayMinutes            DECIMAL(6,1) NULL,
    SecurityDelayMinutes       DECIMAL(6,1) NULL,
    LateAircraftDelayMinutes   DECIMAL(6,1) NULL,

    -- Measures: same-day weather at origin airport (Task 2 source 3)
    OriginTempMaxC             DECIMAL(5,1) NULL,
    OriginTempMinC             DECIMAL(5,1) NULL,
    OriginPrecipitationMm      DECIMAL(6,1) NULL,
    OriginWindSpeedMaxKmh      DECIMAL(6,1) NULL,

    -- Measures: same-day weather at destination airport
    DestTempMaxC               DECIMAL(5,1) NULL,
    DestTempMinC               DECIMAL(5,1) NULL,
    DestPrecipitationMm        DECIMAL(6,1) NULL,
    DestWindSpeedMaxKmh        DECIMAL(6,1) NULL,

    -- Flags
    IsCancelledFlag            BIT NOT NULL,
    IsDivertedFlag             BIT NOT NULL,

    LoadDateTime               DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO

CREATE INDEX IX_FactFlightDeparture_DateKey ON dw.FactFlightDeparture(DateKey);
CREATE INDEX IX_FactFlightDeparture_CarrierKey ON dw.FactFlightDeparture(CarrierKey);
CREATE INDEX IX_FactFlightDeparture_OriginAirportKey ON dw.FactFlightDeparture(OriginAirportKey);
CREATE INDEX IX_FactFlightDeparture_DestAirportKey ON dw.FactFlightDeparture(DestAirportKey);
GO
