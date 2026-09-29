/* ============================================================
   VALIDATION: every check should return Result = 'PASS'.
   Screenshot this output for the ETL validation section of the report.
   ============================================================ */
USE DWBI_RideHailing;
GO

SELECT * FROM (
    SELECT 1 AS CheckNo, 'Row count: raw staging = clean staging' AS CheckName,
        CASE WHEN (SELECT COUNT(*) FROM stg.RideBookings) = (SELECT COUNT(*) FROM stg.RideBookings_Clean)
             THEN 'PASS' ELSE 'FAIL' END AS Result
    UNION ALL SELECT 2, 'Row count: clean staging = fact table',
        CASE WHEN (SELECT COUNT(*) FROM stg.RideBookings_Clean) = (SELECT COUNT(*) FROM dw.FactRideBooking)
             THEN 'PASS' ELSE 'FAIL' END
    UNION ALL SELECT 3, 'No orphan foreign keys (all 9 dimension joins resolve)',
        CASE WHEN NOT EXISTS (
            SELECT 1 FROM dw.FactRideBooking f
            LEFT JOIN dw.DimDate d              ON d.DateKey = f.DateKey
            LEFT JOIN dw.DimTime t              ON t.TimeKey = f.TimeKey
            LEFT JOIN dw.DimCustomer c          ON c.CustomerKey = f.CustomerKey
            LEFT JOIN dw.DimVehicleType v       ON v.VehicleTypeKey = f.VehicleTypeKey
            LEFT JOIN dw.DimLocation pl         ON pl.LocationKey = f.PickupLocationKey
            LEFT JOIN dw.DimLocation dl         ON dl.LocationKey = f.DropLocationKey
            LEFT JOIN dw.DimPaymentMethod p     ON p.PaymentMethodKey = f.PaymentMethodKey
            LEFT JOIN dw.DimBookingStatus b     ON b.BookingStatusKey = f.BookingStatusKey
            LEFT JOIN dw.DimCancellationReason r ON r.CancellationReasonKey = f.CancellationReasonKey
            WHERE d.DateKey IS NULL OR t.TimeKey IS NULL OR c.CustomerKey IS NULL OR v.VehicleTypeKey IS NULL
               OR pl.LocationKey IS NULL OR dl.LocationKey IS NULL OR p.PaymentMethodKey IS NULL
               OR b.BookingStatusKey IS NULL OR r.CancellationReasonKey IS NULL)
             THEN 'PASS' ELSE 'FAIL' END
    UNION ALL SELECT 4, 'No literal ''null'' strings or quote characters remain in clean IDs',
        CASE WHEN NOT EXISTS (SELECT 1 FROM stg.RideBookings_Clean
                              WHERE BookingID LIKE '%"%' OR CustomerID LIKE '%"%'
                                 OR PaymentMethod = 'null' OR ReasonText = 'null')
             THEN 'PASS' ELSE 'FAIL' END
    UNION ALL SELECT 5, 'No failed type conversions (dates/times parsed)',
        CASE WHEN NOT EXISTS (SELECT 1 FROM stg.RideBookings_Clean WHERE RideDate IS NULL OR RideTime IS NULL)
             THEN 'PASS' ELSE 'FAIL' END
    UNION ALL SELECT 6, 'Total fare reconciles: staging vs fact',
        CASE WHEN (SELECT SUM(TRY_CAST(NULLIF(BookingValue,'null') AS DECIMAL(18,2))) FROM stg.RideBookings)
                = (SELECT SUM(BookingValue) FROM dw.FactRideBooking)
             THEN 'PASS' ELSE 'FAIL' END
    UNION ALL SELECT 7, 'Ratings within 1-5 range',
        CASE WHEN NOT EXISTS (SELECT 1 FROM dw.FactRideBooking
                              WHERE DriverRating NOT BETWEEN 1 AND 5 OR CustomerRating NOT BETWEEN 1 AND 5)
             THEN 'PASS' ELSE 'FAIL' END
    UNION ALL SELECT 8, 'Fares and distances are positive when present',
        CASE WHEN NOT EXISTS (SELECT 1 FROM dw.FactRideBooking WHERE BookingValue <= 0 OR RideDistanceKm <= 0)
             THEN 'PASS' ELSE 'FAIL' END
    UNION ALL SELECT 9, 'Exactly one status flag set per booking',
        CASE WHEN NOT EXISTS (SELECT 1 FROM dw.FactRideBooking
             WHERE CAST(IsCompletedFlag AS INT) + IsCancelledByCustomerFlag
                 + IsCancelledByDriverFlag + IsIncompleteFlag > 1)
             THEN 'PASS' ELSE 'FAIL' END
) v ORDER BY CheckNo;
GO

/* Informational: data quality facts worth citing in the report */
SELECT COUNT(*) - COUNT(DISTINCT BookingID) AS BookingIDCollisions_KeptAsDistinctBookings
FROM dw.FactRideBooking;
SELECT BookingStatus, COUNT(*) AS Bookings FROM dw.FactRideBooking f
JOIN dw.DimBookingStatus b ON b.BookingStatusKey = f.BookingStatusKey GROUP BY BookingStatus ORDER BY 2 DESC;
GO
