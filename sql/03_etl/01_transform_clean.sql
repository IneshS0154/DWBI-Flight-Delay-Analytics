USE DWBI_FlightDelay;
GO

IF OBJECT_ID('stg.Flights_Clean', 'U') IS NOT NULL DROP TABLE stg.Flights_Clean;
GO

WITH c AS (
    SELECT
        TRY_CAST(Year AS SMALLINT)              AS Year,
        TRY_CAST(Month AS TINYINT)               AS Month,
        TRY_CAST(DayofMonth AS TINYINT)           AS DayOfMonth,
        TRIM(UniqueCarrier)                       AS UniqueCarrier,   -- join key -> DimCarrier
        TRIM(FlightNum)                           AS FlightNum,
        TRIM(TailNum)                             AS TailNum,
        TRY_CAST(NULLIF(CRSDepTime, '') AS INT)   AS CRSDepTime,   -- scheduled dep, HHMM as int (e.g. 1350)
        TRY_CAST(NULLIF(CRSElapsedTime, '') AS DECIMAL(6,1)) AS CRSElapsedTime,
        -- NULL only for cancelled/diverted flights that never completed (structural, not dirty data)
        TRY_CAST(NULLIF(ActualElapsedTime, '') AS DECIMAL(6,1)) AS ActualElapsedTime,
        TRY_CAST(NULLIF(AirTime, '') AS DECIMAL(6,1))            AS AirTime,
        TRY_CAST(NULLIF(ArrDelay, '') AS DECIMAL(6,1))           AS ArrDelay,   -- "81.0" -> 81.0; negative = early
        TRY_CAST(NULLIF(DepDelay, '') AS DECIMAL(6,1))           AS DepDelay,
        TRIM(Origin)                               AS Origin,   -- join key -> DimAirport (OpenFlights) + weather
        TRIM(Dest)                                  AS Dest,     -- join key -> DimAirport (OpenFlights) + weather
        TRY_CAST(NULLIF(Distance, '') AS DECIMAL(7,1))           AS Distance,
        TRY_CAST(NULLIF(TaxiIn, '') AS DECIMAL(6,1))             AS TaxiIn,
        TRY_CAST(NULLIF(TaxiOut, '') AS DECIMAL(6,1))            AS TaxiOut,
        TRY_CAST(Cancelled AS BIT)                 AS Cancelled,          -- "0"/"1" -> flag
        TRIM(CancellationCode)                     AS CancellationCode,   -- join key -> DimCancellationReason
        TRY_CAST(Diverted AS BIT)                  AS Diverted,
        -- Delay causes: BTS only records these when a flight is 15+ min late, so for smaller
        -- delays they stay NULL ("not recorded"), not 0 ("no delay from this cause").
        -- e.g. YV 7200 HDN->DEN, 4 min late: all five NULL. WN 1685 RNO->OAK, 81 min late:
        -- Weather 49 + LateAircraft 30 + NAS 2 = 81.
        TRY_CAST(NULLIF(CarrierDelay, '') AS DECIMAL(6,1))       AS CarrierDelay,
        TRY_CAST(NULLIF(WeatherDelay, '') AS DECIMAL(6,1))       AS WeatherDelay,
        TRY_CAST(NULLIF(NASDelay, '') AS DECIMAL(6,1))           AS NASDelay,
        TRY_CAST(NULLIF(SecurityDelay, '') AS DECIMAL(6,1))      AS SecurityDelay,
        TRY_CAST(NULLIF(LateAircraftDelay, '') AS DECIMAL(6,1))  AS LateAircraftDelay
    FROM stg.Flights
)
SELECT
    -- Source has no unique ID, so number every row (1..200,000) for traceability back to the CSV
    ROW_NUMBER() OVER (ORDER BY Year, Month, DayOfMonth, UniqueCarrier, FlightNum) AS SourceRowID,
    Year, Month, DayOfMonth,
    -- Date key into DimDate, e.g. 2008*10000 + 1*100 + 31 = 20080131
    Year * 10000 + Month * 100 + DayOfMonth AS DateKey,
    UniqueCarrier, FlightNum, TailNum,
    CRSDepTime,
    -- HHMM key into DimTime (e.g. 1835 -> Evening band). Note: the source is already HHMM and
    -- no value reaches 2400, so this expression returns CRSDepTime unchanged (1835 -> 1835).
    (CRSDepTime / 100) * 100 + (CRSDepTime % 100) AS ScheduledDepTimeKey,  -- HHMM key into DimTime
    CRSElapsedTime, ActualElapsedTime, AirTime, ArrDelay, DepDelay,
    Origin, Dest, Distance, TaxiIn, TaxiOut, Cancelled,
    -- CancellationCode is always populated in this file ('N' = Not Cancelled)
    CancellationCode,
    Diverted,
    CarrierDelay, WeatherDelay, NASDelay, SecurityDelay, LateAircraftDelay
-- SELECT ... INTO creates stg.Flights_Clean and fills it in one step
INTO stg.Flights_Clean
FROM c;
GO

-- Validation: should return 200,000 (same as stg.Flights) - no rows lost or duplicated
SELECT COUNT(*) AS CleanRowCount FROM stg.Flights_Clean;
GO
