USE DWBI_FlightDelay;
GO

TRUNCATE TABLE mart.FactDailyCarrierAirportPerformance;
GO

INSERT INTO mart.FactDailyCarrierAirportPerformance (
    DateKey, CarrierKey, OriginAirportKey, FlightCount, CancelledCount, DivertedCount,
    OnTimeRatePct, AvgDepDelayMinutes, AvgArrDelayMinutes,
    AvgCarrierDelayMinutes, AvgWeatherDelayMinutes, AvgNASDelayMinutes,
    AvgSecurityDelayMinutes, AvgLateAircraftDelayMinutes,
    AvgOriginTempMaxC, AvgOriginPrecipitationMm)
SELECT
    DateKey, CarrierKey, OriginAirportKey,
    COUNT(*),
    SUM(CAST(IsCancelledFlag AS INT)),
    SUM(CAST(IsDivertedFlag AS INT)),
    CAST(100.0 * SUM(CASE WHEN ArrDelayMinutes <= 15 THEN 1 ELSE 0 END)
         / NULLIF(SUM(CASE WHEN ArrDelayMinutes IS NOT NULL THEN 1 ELSE 0 END), 0) AS DECIMAL(5,2)),
    AVG(DepDelayMinutes),
    AVG(ArrDelayMinutes),
    AVG(CarrierDelayMinutes),
    AVG(WeatherDelayMinutes),
    AVG(NASDelayMinutes),
    AVG(SecurityDelayMinutes),
    AVG(LateAircraftDelayMinutes),
    AVG(OriginTempMaxC),
    AVG(OriginPrecipitationMm)
FROM dw.FactFlightDeparture
GROUP BY DateKey, CarrierKey, OriginAirportKey;
GO

SELECT COUNT(*) AS DataMartRowCount FROM mart.FactDailyCarrierAirportPerformance;
GO
