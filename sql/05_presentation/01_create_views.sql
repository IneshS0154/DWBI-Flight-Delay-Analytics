/* ============================================================
   Presentation-layer views for Power BI (Task 7).
   Flattened, human-readable, one row per grain — Power BI connects
   to these directly instead of navigating the star schema's
   surrogate keys and joins itself.
   ============================================================ */
USE DWBI_FlightDelay;
GO

IF OBJECT_ID('dw.vw_FlightDetail', 'V') IS NOT NULL DROP VIEW dw.vw_FlightDetail;
GO
CREATE VIEW dw.vw_FlightDetail AS
SELECT
    f.FlightDepartureKey,
    f.FlightNum,
    f.TailNum,
    d.FullDate, d.DayName, d.MonthName, d.MonthNumber, d.Quarter, d.Year, d.IsWeekend,
    t.TimeOfDayBand AS ScheduledDepartureTimeOfDay,
    t.HourNumber AS ScheduledDepartureHour,
    c.CarrierCode, c.CarrierName,
    oa.IATA AS OriginIATA, oa.AirportName AS OriginAirportName, oa.City AS OriginCity, oa.Country AS OriginCountry,
    da.IATA AS DestIATA, da.AirportName AS DestAirportName, da.City AS DestCity, da.Country AS DestCountry,
    cr.CancellationCode, cr.Description AS CancellationReason,
    f.ScheduledElapsedMinutes, f.ActualElapsedMinutes, f.AirTimeMinutes,
    f.DepDelayMinutes, f.ArrDelayMinutes, f.TaxiInMinutes, f.TaxiOutMinutes, f.DistanceMiles,
    f.CarrierDelayMinutes, f.WeatherDelayMinutes, f.NASDelayMinutes,
    f.SecurityDelayMinutes, f.LateAircraftDelayMinutes,
    f.OriginTempMaxC, f.OriginTempMinC, f.OriginPrecipitationMm, f.OriginWindSpeedMaxKmh,
    f.DestTempMaxC, f.DestTempMinC, f.DestPrecipitationMm, f.DestWindSpeedMaxKmh,
    f.IsCancelledFlag, f.IsDivertedFlag,
    CASE WHEN f.ArrDelayMinutes <= 15 THEN 1 ELSE 0 END AS IsOnTimeFlag
FROM dw.FactFlightDeparture f
JOIN dw.DimDate d              ON d.DateKey = f.DateKey
JOIN dw.DimTime t              ON t.TimeKey = f.ScheduledDepTimeKey
JOIN dw.DimCarrier c           ON c.CarrierKey = f.CarrierKey
JOIN dw.DimAirport oa          ON oa.AirportKey = f.OriginAirportKey
JOIN dw.DimAirport da          ON da.AirportKey = f.DestAirportKey
JOIN dw.DimCancellationReason cr ON cr.CancellationReasonKey = f.CancellationReasonKey;
GO

IF OBJECT_ID('mart.vw_DailyCarrierAirportPerformance', 'V') IS NOT NULL DROP VIEW mart.vw_DailyCarrierAirportPerformance;
GO
CREATE VIEW mart.vw_DailyCarrierAirportPerformance AS
SELECT
    d.FullDate, d.DayName, d.MonthName, d.MonthNumber, d.Quarter, d.Year, d.IsWeekend,
    c.CarrierCode, c.CarrierName,
    a.IATA AS OriginIATA, a.AirportName AS OriginAirportName, a.City AS OriginCity, a.Country AS OriginCountry,
    m.FlightCount, m.CancelledCount, m.DivertedCount, m.OnTimeRatePct,
    m.AvgDepDelayMinutes, m.AvgArrDelayMinutes,
    m.AvgCarrierDelayMinutes, m.AvgWeatherDelayMinutes, m.AvgNASDelayMinutes,
    m.AvgSecurityDelayMinutes, m.AvgLateAircraftDelayMinutes,
    m.AvgOriginTempMaxC, m.AvgOriginPrecipitationMm
FROM mart.FactDailyCarrierAirportPerformance m
JOIN dw.DimDate d      ON d.DateKey = m.DateKey
JOIN dw.DimCarrier c   ON c.CarrierKey = m.CarrierKey
JOIN dw.DimAirport a   ON a.AirportKey = m.OriginAirportKey;
GO

SELECT TOP 3 * FROM dw.vw_FlightDetail;
SELECT TOP 3 * FROM mart.vw_DailyCarrierAirportPerformance;
GO
