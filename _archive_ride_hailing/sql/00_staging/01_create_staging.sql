/* ============================================================
   Staging table: mirrors the raw Kaggle CSV column-for-column.
   No cleansing/typing here on purpose — this is the "as received"
   landing zone. Transformations happen in sql/03_etl.
   ============================================================ */

IF DB_ID('DWBI_RideHailing') IS NULL
BEGIN
    CREATE DATABASE DWBI_RideHailing;
END
GO

USE DWBI_RideHailing;
GO

IF SCHEMA_ID('stg') IS NULL
    EXEC('CREATE SCHEMA stg');
GO

IF OBJECT_ID('stg.RideBookings', 'U') IS NOT NULL
    DROP TABLE stg.RideBookings;
GO

CREATE TABLE stg.RideBookings (
    RideDate                       VARCHAR(20),
    RideTime                       VARCHAR(20),
    BookingID                      VARCHAR(50),
    BookingStatus                  VARCHAR(50),
    CustomerID                     VARCHAR(50),
    VehicleType                    VARCHAR(50),
    PickupLocation                 VARCHAR(200),
    DropLocation                   VARCHAR(200),
    AvgVTAT                        VARCHAR(20),
    AvgCTAT                        VARCHAR(20),
    CancelledRidesByCustomer       VARCHAR(10),
    ReasonForCancellingByCustomer  VARCHAR(200),
    CancelledRidesByDriver         VARCHAR(10),
    DriverCancellationReason       VARCHAR(200),
    IncompleteRides                VARCHAR(10),
    IncompleteRidesReason          VARCHAR(200),
    BookingValue                   VARCHAR(20),
    RideDistance                   VARCHAR(20),
    DriverRatings                  VARCHAR(20),
    CustomerRating                 VARCHAR(20),
    PaymentMethod                  VARCHAR(50)
);
GO
