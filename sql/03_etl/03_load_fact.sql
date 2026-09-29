/* ============================================================
   LOAD fact table: resolve business values to dimension surrogate
   keys, and bring in same-day weather at both origin and
   destination airports (Task 2 source 3, joined on IATA + date).
   ============================================================ */
USE DWBI_FlightDelay;
GO

IF OBJECT_ID('stg.Weather_Clean', 'U') IS NOT NULL DROP TABLE stg.Weather_Clean;
SELECT
    IATA,
    CAST(REPLACE(WeatherDate, '-', '') AS INT) AS DateKey,
    TRY_CAST(TempMaxC AS DECIMAL(5,1))        AS TempMaxC,
    TRY_CAST(TempMinC AS DECIMAL(5,1))        AS TempMinC,
    TRY_CAST(PrecipitationMm AS DECIMAL(6,1)) AS PrecipitationMm,
    TRY_CAST(WindSpeedMaxKmh AS DECIMAL(6,1)) AS WindSpeedMaxKmh
INTO stg.Weather_Clean
FROM stg.Weather;
GO
CREATE UNIQUE INDEX IX_WeatherClean ON stg.Weather_Clean(IATA, DateKey);
GO

INSERT INTO dw.FactFlightDeparture (
    FlightNum, TailNum, DateKey, ScheduledDepTimeKey, CarrierKey, OriginAirportKey, DestAirportKey,
    CancellationReasonKey, ScheduledElapsedMinutes, ActualElapsedMinutes, AirTimeMinutes,
    DepDelayMinutes, ArrDelayMinutes, TaxiInMinutes, TaxiOutMinutes, DistanceMiles,
    CarrierDelayMinutes, WeatherDelayMinutes, NASDelayMinutes, SecurityDelayMinutes, LateAircraftDelayMinutes,
    OriginTempMaxC, OriginTempMinC, OriginPrecipitationMm, OriginWindSpeedMaxKmh,
    DestTempMaxC, DestTempMinC, DestPrecipitationMm, DestWindSpeedMaxKmh,
    IsCancelledFlag, IsDivertedFlag)
SELECT
    f.FlightNum, f.TailNum, f.DateKey, f.ScheduledDepTimeKey,
    car.CarrierKey, oa.AirportKey, da.AirportKey, cr.CancellationReasonKey,
    f.CRSElapsedTime, f.ActualElapsedTime, f.AirTime, f.DepDelay, f.ArrDelay,
    f.TaxiIn, f.TaxiOut, f.Distance,
    f.CarrierDelay, f.WeatherDelay, f.NASDelay, f.SecurityDelay, f.LateAircraftDelay,
    ow.TempMaxC, ow.TempMinC, ow.PrecipitationMm, ow.WindSpeedMaxKmh,
    dw_.TempMaxC, dw_.TempMinC, dw_.PrecipitationMm, dw_.WindSpeedMaxKmh,
    f.Cancelled, f.Diverted
FROM stg.Flights_Clean f
JOIN dw.DimCarrier car             ON car.CarrierCode = f.UniqueCarrier
JOIN dw.DimAirport oa               ON oa.IATA = f.Origin
JOIN dw.DimAirport da                ON da.IATA = f.Dest
JOIN dw.DimCancellationReason cr      ON cr.CancellationCode = f.CancellationCode
LEFT JOIN stg.Weather_Clean ow          ON ow.IATA = f.Origin AND ow.DateKey = f.DateKey
LEFT JOIN stg.Weather_Clean dw_          ON dw_.IATA = f.Dest AND dw_.DateKey = f.DateKey
ORDER BY f.SourceRowID;
GO

SELECT COUNT(*) AS FactRowCount FROM dw.FactFlightDeparture;
GO
