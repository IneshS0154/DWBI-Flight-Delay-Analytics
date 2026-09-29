/* ============================================================
   LOAD fact table: resolve each business value to its dimension
   surrogate key. Inner joins are safe because every dimension was
   built from this same clean table, and 04_validate.sql proves
   no rows were lost.
   ============================================================ */
USE DWBI_RideHailing;
GO

INSERT INTO dw.FactRideBooking (
    BookingID, DateKey, TimeKey, CustomerKey, VehicleTypeKey,
    PickupLocationKey, DropLocationKey, PaymentMethodKey, BookingStatusKey, CancellationReasonKey,
    AvgVTAT, AvgCTAT, BookingValue, RideDistanceKm, DriverRating, CustomerRating, FarePerKm,
    IsCompletedFlag, IsCancelledByCustomerFlag, IsCancelledByDriverFlag, IsIncompleteFlag)
SELECT
    c.BookingID,
    YEAR(c.RideDate) * 10000 + MONTH(c.RideDate) * 100 + DAY(c.RideDate),
    c.TimeKey,
    cu.CustomerKey, vt.VehicleTypeKey, pl.LocationKey, dl.LocationKey,
    pm.PaymentMethodKey, bs.BookingStatusKey, cr.CancellationReasonKey,
    c.AvgVTAT, c.AvgCTAT, c.BookingValue, c.RideDistanceKm, c.DriverRating, c.CustomerRating, c.FarePerKm,
    c.IsCompletedFlag, c.IsCancelledByCustomerFlag, c.IsCancelledByDriverFlag, c.IsIncompleteFlag
FROM stg.RideBookings_Clean c
JOIN dw.DimCustomer           cu ON cu.CustomerID    = c.CustomerID
JOIN dw.DimVehicleType        vt ON vt.VehicleType   = c.VehicleType
JOIN dw.DimLocation           pl ON pl.LocationName  = c.PickupLocation
JOIN dw.DimLocation           dl ON dl.LocationName  = c.DropLocation
JOIN dw.DimPaymentMethod      pm ON pm.PaymentMethod = c.PaymentMethod
JOIN dw.DimBookingStatus      bs ON bs.BookingStatus = c.BookingStatus
JOIN dw.DimCancellationReason cr ON cr.ReasonText    = c.ReasonText
                                AND cr.ReasonSource  = c.ReasonSource
ORDER BY c.SourceRowID;
GO

SELECT COUNT(*) AS FactRowCount FROM dw.FactRideBooking;
GO
