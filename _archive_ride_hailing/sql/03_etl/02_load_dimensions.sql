/* ============================================================
   LOAD dimensions (must run before the fact table).
   Every dimension gets a 'Not Applicable' member where the source
   legitimately has no value, so fact foreign keys are never NULL.
   ============================================================ */
USE DWBI_RideHailing;
GO

/* Fact first (FK dependency), then dimensions */
DELETE FROM dw.FactRideBooking;
DELETE FROM dw.DimDate;
DELETE FROM dw.DimTime;
DELETE FROM dw.DimCustomer;
DELETE FROM dw.DimVehicleType;
DELETE FROM dw.DimLocation;
DELETE FROM dw.DimPaymentMethod;
DELETE FROM dw.DimBookingStatus;
DELETE FROM dw.DimCancellationReason;
GO

/* ---------- DimDate: full 2024 calendar, not just dates present in data ---------- */
SET DATEFIRST 7;  -- Sunday = 1, so DayOfWeek is deterministic
WITH d AS (
    SELECT CAST('2024-01-01' AS DATE) AS dt
    UNION ALL SELECT DATEADD(DAY, 1, dt) FROM d WHERE dt < '2024-12-31'
)
INSERT INTO dw.DimDate (DateKey, FullDate, DayOfMonth, DayName, DayOfWeek, IsWeekend,
                        MonthNumber, MonthName, Quarter, Year)
SELECT
    YEAR(dt) * 10000 + MONTH(dt) * 100 + DAY(dt),
    dt, DAY(dt), DATENAME(WEEKDAY, dt), DATEPART(WEEKDAY, dt),
    CASE WHEN DATEPART(WEEKDAY, dt) IN (1, 7) THEN 1 ELSE 0 END,
    MONTH(dt), DATENAME(MONTH, dt), DATEPART(QUARTER, dt), YEAR(dt)
FROM d
OPTION (MAXRECURSION 400);
GO

/* ---------- DimTime: every minute of the day ---------- */
WITH n AS (
    SELECT 0 AS m
    UNION ALL SELECT m + 1 FROM n WHERE m < 1439
)
INSERT INTO dw.DimTime (TimeKey, HourNumber, MinuteNumber, TimeOfDayBand)
SELECT
    (m / 60) * 100 + (m % 60), m / 60, m % 60,
    CASE WHEN m / 60 BETWEEN 5  AND 11 THEN 'Morning'
         WHEN m / 60 BETWEEN 12 AND 16 THEN 'Afternoon'
         WHEN m / 60 BETWEEN 17 AND 21 THEN 'Evening'
         ELSE 'Night' END
FROM n
OPTION (MAXRECURSION 1500);
GO

/* ---------- DimCustomer ---------- */
INSERT INTO dw.DimCustomer (CustomerID)
SELECT DISTINCT CustomerID FROM stg.RideBookings_Clean;
GO

/* ---------- DimVehicleType: category/capacity/fuel sourced from the Fleet Management System (Excel) ---------- */
INSERT INTO dw.DimVehicleType (VehicleType, VehicleCategory, SeatingCapacity, FuelType)
SELECT DISTINCT c.VehicleType, f.VehicleCategory, CAST(f.SeatingCapacity AS TINYINT), f.FuelType
FROM stg.RideBookings_Clean c
JOIN stg.VehicleFleetMaster f ON f.VehicleType = c.VehicleType;
GO

/* ---------- DimLocation: union of pickup and drop names, city/region sourced from Geo Mapping Service (JSON) ---------- */
WITH loc AS (
    SELECT PickupLocation AS LocationName FROM stg.RideBookings_Clean
    UNION
    SELECT DropLocation FROM stg.RideBookings_Clean
)
INSERT INTO dw.DimLocation (LocationName, City, Region)
SELECT loc.LocationName, z.City, z.Region
FROM loc
JOIN stg.LocationZoneReference z ON z.LocationName = loc.LocationName;
GO

/* ---------- DimPaymentMethod ---------- */
INSERT INTO dw.DimPaymentMethod (PaymentMethod)
SELECT DISTINCT PaymentMethod FROM stg.RideBookings_Clean;
GO

/* ---------- DimBookingStatus ---------- */
INSERT INTO dw.DimBookingStatus (BookingStatus, IsCompleted, IsCancelled)
SELECT DISTINCT BookingStatus,
    CASE WHEN BookingStatus = 'Completed' THEN 1 ELSE 0 END,
    CASE WHEN BookingStatus LIKE 'Cancelled%' THEN 1 ELSE 0 END
FROM stg.RideBookings_Clean;
GO

/* ---------- DimCancellationReason ---------- */
INSERT INTO dw.DimCancellationReason (ReasonText, ReasonSource)
SELECT DISTINCT ReasonText, ReasonSource FROM stg.RideBookings_Clean;
GO

SELECT 'DimDate' t, COUNT(*) n FROM dw.DimDate UNION ALL
SELECT 'DimTime', COUNT(*) FROM dw.DimTime UNION ALL
SELECT 'DimCustomer', COUNT(*) FROM dw.DimCustomer UNION ALL
SELECT 'DimVehicleType', COUNT(*) FROM dw.DimVehicleType UNION ALL
SELECT 'DimLocation', COUNT(*) FROM dw.DimLocation UNION ALL
SELECT 'DimPaymentMethod', COUNT(*) FROM dw.DimPaymentMethod UNION ALL
SELECT 'DimBookingStatus', COUNT(*) FROM dw.DimBookingStatus UNION ALL
SELECT 'DimCancellationReason', COUNT(*) FROM dw.DimCancellationReason;
GO
