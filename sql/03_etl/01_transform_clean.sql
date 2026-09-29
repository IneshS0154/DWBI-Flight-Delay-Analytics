/* ============================================================
   TRANSFORM: stg.Flights (raw text) -> stg.Flights_Clean (typed)

   Issues found during profiling and handled here:
     1. Every column landed as text (VARCHAR)      -> TRY_CAST to proper types
     2. Missing numeric values are empty strings    -> NULLIF(..., '') -> real NULL
        (structural: only cancelled/diverted flights that never completed have these nulls)
     3. Delay-cause columns null when ArrDelay < 15 -> left as NULL (BTS's own convention,
        not a data quality defect); COALESCE to 0 only where a "total delay" measure needs it
     4. No time-of-day bucket key in source          -> derived ScheduledDepTimeKey (HHMM)
   ============================================================ */
USE DWBI_FlightDelay;
GO

IF OBJECT_ID('stg.Flights_Clean', 'U') IS NOT NULL DROP TABLE stg.Flights_Clean;
GO

WITH c AS (
    SELECT
        TRY_CAST(Year AS SMALLINT)              AS Year,
        TRY_CAST(Month AS TINYINT)               AS Month,
        TRY_CAST(DayofMonth AS TINYINT)           AS DayOfMonth,
        TRIM(UniqueCarrier)                       AS UniqueCarrier,
        TRIM(FlightNum)                           AS FlightNum,
        TRIM(TailNum)                             AS TailNum,
        TRY_CAST(NULLIF(CRSDepTime, '') AS INT)   AS CRSDepTime,   -- scheduled dep, HHMM as int (e.g. 1350)
        TRY_CAST(NULLIF(CRSElapsedTime, '') AS DECIMAL(6,1)) AS CRSElapsedTime,
        TRY_CAST(NULLIF(ActualElapsedTime, '') AS DECIMAL(6,1)) AS ActualElapsedTime,
        TRY_CAST(NULLIF(AirTime, '') AS DECIMAL(6,1))            AS AirTime,
        TRY_CAST(NULLIF(ArrDelay, '') AS DECIMAL(6,1))           AS ArrDelay,
        TRY_CAST(NULLIF(DepDelay, '') AS DECIMAL(6,1))           AS DepDelay,
        TRIM(Origin)                               AS Origin,
        TRIM(Dest)                                  AS Dest,
        TRY_CAST(NULLIF(Distance, '') AS DECIMAL(7,1))           AS Distance,
        TRY_CAST(NULLIF(TaxiIn, '') AS DECIMAL(6,1))             AS TaxiIn,
        TRY_CAST(NULLIF(TaxiOut, '') AS DECIMAL(6,1))            AS TaxiOut,
        TRY_CAST(Cancelled AS BIT)                 AS Cancelled,
        TRIM(CancellationCode)                     AS CancellationCode,
        TRY_CAST(Diverted AS BIT)                  AS Diverted,
        TRY_CAST(NULLIF(CarrierDelay, '') AS DECIMAL(6,1))       AS CarrierDelay,
        TRY_CAST(NULLIF(WeatherDelay, '') AS DECIMAL(6,1))       AS WeatherDelay,
        TRY_CAST(NULLIF(NASDelay, '') AS DECIMAL(6,1))           AS NASDelay,
        TRY_CAST(NULLIF(SecurityDelay, '') AS DECIMAL(6,1))      AS SecurityDelay,
        TRY_CAST(NULLIF(LateAircraftDelay, '') AS DECIMAL(6,1))  AS LateAircraftDelay
    FROM stg.Flights
)
SELECT
    ROW_NUMBER() OVER (ORDER BY Year, Month, DayOfMonth, UniqueCarrier, FlightNum) AS SourceRowID,
    Year, Month, DayOfMonth,
    Year * 10000 + Month * 100 + DayOfMonth AS DateKey,
    UniqueCarrier, FlightNum, TailNum,
    CRSDepTime,
    (CRSDepTime / 100) * 100 + (CRSDepTime % 100) AS ScheduledDepTimeKey,  -- HHMM key into DimTime
    CRSElapsedTime, ActualElapsedTime, AirTime, ArrDelay, DepDelay,
    Origin, Dest, Distance, TaxiIn, TaxiOut, Cancelled,
    -- CancellationCode is always populated in this file ('N' = Not Cancelled)
    CancellationCode,
    Diverted,
    CarrierDelay, WeatherDelay, NASDelay, SecurityDelay, LateAircraftDelay
INTO stg.Flights_Clean
FROM c;
GO

SELECT COUNT(*) AS CleanRowCount FROM stg.Flights_Clean;
GO
