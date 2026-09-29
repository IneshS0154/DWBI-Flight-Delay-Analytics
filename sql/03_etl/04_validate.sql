/* ============================================================
   VALIDATION: every check should return Result = 'PASS'.
   ============================================================ */
USE DWBI_FlightDelay;
GO

SELECT * FROM (
    SELECT 1 AS CheckNo, 'Row count: raw staging = clean staging' AS CheckName,
        CASE WHEN (SELECT COUNT(*) FROM stg.Flights) = (SELECT COUNT(*) FROM stg.Flights_Clean)
             THEN 'PASS' ELSE 'FAIL' END AS Result
    UNION ALL SELECT 2, 'Row count: clean staging = fact table',
        CASE WHEN (SELECT COUNT(*) FROM stg.Flights_Clean) = (SELECT COUNT(*) FROM dw.FactFlightDeparture)
             THEN 'PASS' ELSE 'FAIL' END
    UNION ALL SELECT 3, 'No orphan foreign keys (all 6 dimension joins resolve)',
        CASE WHEN NOT EXISTS (
            SELECT 1 FROM dw.FactFlightDeparture f
            LEFT JOIN dw.DimDate d ON d.DateKey = f.DateKey
            LEFT JOIN dw.DimTime t ON t.TimeKey = f.ScheduledDepTimeKey
            LEFT JOIN dw.DimCarrier c ON c.CarrierKey = f.CarrierKey
            LEFT JOIN dw.DimAirport oa ON oa.AirportKey = f.OriginAirportKey
            LEFT JOIN dw.DimAirport da ON da.AirportKey = f.DestAirportKey
            LEFT JOIN dw.DimCancellationReason cr ON cr.CancellationReasonKey = f.CancellationReasonKey
            WHERE d.DateKey IS NULL OR t.TimeKey IS NULL OR c.CarrierKey IS NULL
               OR oa.AirportKey IS NULL OR da.AirportKey IS NULL OR cr.CancellationReasonKey IS NULL)
             THEN 'PASS' ELSE 'FAIL' END
    UNION ALL SELECT 4, 'All 304 flight airport codes resolved in DimAirport',
        CASE WHEN (SELECT COUNT(DISTINCT Origin) FROM stg.Flights_Clean
                   WHERE Origin NOT IN (SELECT IATA FROM dw.DimAirport)) = 0
             AND (SELECT COUNT(DISTINCT Dest) FROM stg.Flights_Clean
                   WHERE Dest NOT IN (SELECT IATA FROM dw.DimAirport)) = 0
             THEN 'PASS' ELSE 'FAIL' END
    UNION ALL SELECT 5, 'No failed type conversions on key numeric fields',
        CASE WHEN NOT EXISTS (SELECT 1 FROM stg.Flights_Clean WHERE DateKey IS NULL OR ScheduledDepTimeKey IS NULL)
             THEN 'PASS' ELSE 'FAIL' END
    UNION ALL SELECT 6, 'Total distance reconciles: staging vs fact',
        CASE WHEN (SELECT SUM(TRY_CAST(NULLIF(Distance,'') AS DECIMAL(18,1))) FROM stg.Flights)
                = (SELECT SUM(DistanceMiles) FROM dw.FactFlightDeparture)
             THEN 'PASS' ELSE 'FAIL' END
    UNION ALL SELECT 7, 'Weather populated for essentially all fact rows (origin)',
        CASE WHEN (SELECT CAST(COUNT(OriginTempMaxC) AS DECIMAL(12,4)) / COUNT(*) FROM dw.FactFlightDeparture) > 0.99
             THEN 'PASS' ELSE 'FAIL' END
    UNION ALL SELECT 8, 'Delay-cause minutes only present when ArrDelay >= 15 (BTS convention preserved)',
        CASE WHEN NOT EXISTS (
            SELECT 1 FROM dw.FactFlightDeparture
            WHERE CarrierDelayMinutes IS NOT NULL AND (ArrDelayMinutes IS NULL OR ArrDelayMinutes < 15))
             THEN 'PASS' ELSE 'FAIL' END
    UNION ALL SELECT 9, 'Cancelled/Diverted flags are 0 or 1 only',
        CASE WHEN NOT EXISTS (SELECT 1 FROM dw.FactFlightDeparture
                              WHERE IsCancelledFlag NOT IN (0,1) OR IsDivertedFlag NOT IN (0,1))
             THEN 'PASS' ELSE 'FAIL' END
) v ORDER BY CheckNo;
GO

/* Informational: data facts worth citing in the report */
SELECT CancellationCode, COUNT(*) AS Flights FROM dw.FactFlightDeparture f
JOIN dw.DimCancellationReason cr ON cr.CancellationReasonKey = f.CancellationReasonKey
GROUP BY CancellationCode ORDER BY 2 DESC;

SELECT CarrierName, COUNT(*) AS Flights, AVG(ArrDelayMinutes) AS AvgArrDelay
FROM dw.FactFlightDeparture f JOIN dw.DimCarrier c ON c.CarrierKey = f.CarrierKey
GROUP BY CarrierName ORDER BY Flights DESC;
GO
