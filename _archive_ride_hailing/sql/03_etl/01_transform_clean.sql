/* ============================================================
   TRANSFORM: stg.RideBookings (raw text) -> stg.RideBookings_Clean (typed)

   Issues found during profiling and handled here:
     1. IDs wrapped in literal quote characters   -> strip quotes
     2. Missing values stored as the string 'null' -> NULLIF -> real NULL
     3. Everything landed as VARCHAR               -> TRY_CAST to proper types
     4. Three separate reason columns              -> one Reason + ReasonSource
     5. Free text may carry stray whitespace       -> TRIM
   NOT done on purpose: de-duplicating on BookingID. The repeated IDs are
   collisions between different bookings (different date/customer/vehicle),
   so all 150,000 rows are legitimate and are kept.
   ============================================================ */
USE DWBI_RideHailing;
GO

IF OBJECT_ID('stg.RideBookings_Clean', 'U') IS NOT NULL DROP TABLE stg.RideBookings_Clean;
GO

WITH c AS (
    SELECT
        REPLACE(TRIM(BookingID),  '"', '')                    AS BookingID,
        REPLACE(TRIM(CustomerID), '"', '')                    AS CustomerID,
        TRY_CAST(RideDate AS DATE)                            AS RideDate,
        TRY_CAST(RideTime AS TIME(0))                         AS RideTime,
        TRIM(BookingStatus)                                   AS BookingStatus,
        TRIM(VehicleType)                                     AS VehicleType,
        TRIM(PickupLocation)                                  AS PickupLocation,
        TRIM(DropLocation)                                    AS DropLocation,
        TRY_CAST(NULLIF(AvgVTAT, 'null')       AS DECIMAL(6,2))  AS AvgVTAT,
        TRY_CAST(NULLIF(AvgCTAT, 'null')       AS DECIMAL(6,2))  AS AvgCTAT,
        TRY_CAST(NULLIF(BookingValue, 'null')  AS DECIMAL(10,2)) AS BookingValue,
        TRY_CAST(NULLIF(RideDistance, 'null')  AS DECIMAL(6,2))  AS RideDistanceKm,
        TRY_CAST(NULLIF(DriverRatings, 'null') AS DECIMAL(3,2))  AS DriverRating,
        TRY_CAST(NULLIF(CustomerRating, 'null') AS DECIMAL(3,2)) AS CustomerRating,
        NULLIF(TRIM(PaymentMethod), 'null')                   AS PaymentMethod,
        NULLIF(TRIM(ReasonForCancellingByCustomer), 'null')   AS CustReason,
        NULLIF(TRIM(DriverCancellationReason), 'null')        AS DrvReason,
        NULLIF(TRIM(IncompleteRidesReason), 'null')           AS IncReason
    FROM stg.RideBookings
)
SELECT
    ROW_NUMBER() OVER (ORDER BY RideDate, RideTime, BookingID)  AS SourceRowID,
    BookingID, CustomerID, RideDate, RideTime,
    BookingStatus, VehicleType, PickupLocation, DropLocation,
    AvgVTAT, AvgCTAT, BookingValue, RideDistanceKm, DriverRating, CustomerRating,

    -- Missing payment only occurs when no fare was charged
    COALESCE(PaymentMethod, 'Not Applicable')                   AS PaymentMethod,

    -- Collapse the three reason columns into one
    COALESCE(CustReason, DrvReason, IncReason, 'Not Applicable') AS ReasonText,
    CASE WHEN CustReason IS NOT NULL THEN 'Customer'
         WHEN DrvReason  IS NOT NULL THEN 'Driver'
         WHEN IncReason  IS NOT NULL THEN 'Incomplete'
         ELSE 'Not Applicable' END                              AS ReasonSource,

    -- Derived attribute: fare per km (only for rides that have both values)
    CAST(BookingValue / NULLIF(RideDistanceKm, 0) AS DECIMAL(10,2)) AS FarePerKm,

    -- Derived attribute: HHMM key for DimTime
    DATEPART(HOUR, RideTime) * 100 + DATEPART(MINUTE, RideTime) AS TimeKey,

    -- Derived flags
    CASE WHEN BookingStatus = 'Completed'             THEN 1 ELSE 0 END AS IsCompletedFlag,
    CASE WHEN BookingStatus = 'Cancelled by Customer' THEN 1 ELSE 0 END AS IsCancelledByCustomerFlag,
    CASE WHEN BookingStatus = 'Cancelled by Driver'   THEN 1 ELSE 0 END AS IsCancelledByDriverFlag,
    CASE WHEN BookingStatus = 'Incomplete'            THEN 1 ELSE 0 END AS IsIncompleteFlag
INTO stg.RideBookings_Clean
FROM c;
GO

SELECT COUNT(*) AS CleanRowCount FROM stg.RideBookings_Clean;
GO
