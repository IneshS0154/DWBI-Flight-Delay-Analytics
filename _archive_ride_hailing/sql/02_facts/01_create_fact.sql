/* ============================================================
   FactRideBooking
   Business process : Ride booking (a customer requests a ride)
   Grain             : one row per booking (BookingID)
   ============================================================ */

USE DWBI_RideHailing;
GO

IF OBJECT_ID('dw.FactRideBooking', 'U') IS NOT NULL DROP TABLE dw.FactRideBooking;
CREATE TABLE dw.FactRideBooking (
    RideBookingKey          BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,

    -- Degenerate dimension. NOT unique: the source has ID collisions across
    -- genuinely different bookings, so RideBookingKey is the real identifier.
    BookingID                VARCHAR(50)   NOT NULL,

    -- Foreign keys
    DateKey                  INT           NOT NULL REFERENCES dw.DimDate(DateKey),
    TimeKey                  INT           NOT NULL REFERENCES dw.DimTime(TimeKey),
    CustomerKey               INT          NOT NULL REFERENCES dw.DimCustomer(CustomerKey),
    VehicleTypeKey            INT          NOT NULL REFERENCES dw.DimVehicleType(VehicleTypeKey),
    PickupLocationKey         INT          NOT NULL REFERENCES dw.DimLocation(LocationKey),
    DropLocationKey           INT          NOT NULL REFERENCES dw.DimLocation(LocationKey),
    PaymentMethodKey          INT          NOT NULL REFERENCES dw.DimPaymentMethod(PaymentMethodKey),
    BookingStatusKey          INT          NOT NULL REFERENCES dw.DimBookingStatus(BookingStatusKey),
    CancellationReasonKey     INT          NOT NULL REFERENCES dw.DimCancellationReason(CancellationReasonKey),

    -- Measures
    AvgVTAT                   DECIMAL(6,2) NULL,   -- avg time for vehicle to arrive at pickup (mins)
    AvgCTAT                   DECIMAL(6,2) NULL,   -- avg time for full trip completion (mins)
    BookingValue               DECIMAL(10,2) NULL,  -- fare
    RideDistanceKm             DECIMAL(6,2) NULL,
    DriverRating                DECIMAL(3,2) NULL,
    CustomerRating               DECIMAL(3,2) NULL,
    FarePerKm                    DECIMAL(10,2) NULL, -- derived measure: BookingValue / RideDistanceKm

    -- Flags (derived, useful for quick filtering without joining DimBookingStatus)
    IsCompletedFlag                BIT NOT NULL,
    IsCancelledByCustomerFlag      BIT NOT NULL,
    IsCancelledByDriverFlag        BIT NOT NULL,
    IsIncompleteFlag                BIT NOT NULL,

    LoadDateTime                  DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO

CREATE INDEX IX_FactRideBooking_BookingID ON dw.FactRideBooking(BookingID);
CREATE INDEX IX_FactRideBooking_DateKey ON dw.FactRideBooking(DateKey);
CREATE INDEX IX_FactRideBooking_CustomerKey ON dw.FactRideBooking(CustomerKey);
CREATE INDEX IX_FactRideBooking_VehicleTypeKey ON dw.FactRideBooking(VehicleTypeKey);
GO
