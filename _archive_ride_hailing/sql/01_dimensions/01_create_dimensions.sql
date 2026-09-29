/* ============================================================
   Dimension tables — DWBI_RideHailing data warehouse
   Star schema with DimLocation role-played as Pickup and Drop
   ============================================================ */

USE DWBI_RideHailing;
GO

IF SCHEMA_ID('dw') IS NULL
    EXEC('CREATE SCHEMA dw');
GO

-- Fact references every dimension, so it must be dropped first on re-runs
IF OBJECT_ID('dw.FactRideBooking', 'U') IS NOT NULL DROP TABLE dw.FactRideBooking;
GO

/* ---------- DimDate ---------- */
IF OBJECT_ID('dw.DimDate', 'U') IS NOT NULL DROP TABLE dw.DimDate;
CREATE TABLE dw.DimDate (
    DateKey         INT             NOT NULL PRIMARY KEY,   -- YYYYMMDD
    FullDate        DATE            NOT NULL,
    DayOfMonth      TINYINT         NOT NULL,
    DayName         VARCHAR(10)     NOT NULL,
    DayOfWeek       TINYINT         NOT NULL,               -- 1=Sunday..7=Saturday
    IsWeekend       BIT             NOT NULL,
    MonthNumber     TINYINT         NOT NULL,
    MonthName       VARCHAR(10)     NOT NULL,
    Quarter         TINYINT         NOT NULL,
    Year            SMALLINT        NOT NULL
);
GO

/* ---------- DimTime (time-of-day bucket, grain = 1 row per minute of day) ---------- */
IF OBJECT_ID('dw.DimTime', 'U') IS NOT NULL DROP TABLE dw.DimTime;
CREATE TABLE dw.DimTime (
    TimeKey         INT             NOT NULL PRIMARY KEY,   -- HHMM, e.g. 1429
    HourNumber      TINYINT         NOT NULL,
    MinuteNumber    TINYINT         NOT NULL,
    TimeOfDayBand   VARCHAR(20)     NOT NULL                -- Morning/Afternoon/Evening/Night
);
GO

/* ---------- DimCustomer ---------- */
IF OBJECT_ID('dw.DimCustomer', 'U') IS NOT NULL DROP TABLE dw.DimCustomer;
CREATE TABLE dw.DimCustomer (
    CustomerKey     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CustomerID      VARCHAR(50)     NOT NULL UNIQUE
);
GO

/* ---------- DimVehicleType ---------- */
IF OBJECT_ID('dw.DimVehicleType', 'U') IS NOT NULL DROP TABLE dw.DimVehicleType;
CREATE TABLE dw.DimVehicleType (
    VehicleTypeKey  INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    VehicleType     VARCHAR(50)     NOT NULL UNIQUE,
    VehicleCategory VARCHAR(30)     NOT NULL,               -- hierarchy: VehicleType -> Category
    SeatingCapacity TINYINT         NOT NULL,               -- sourced from Fleet Management System (Excel)
    FuelType        VARCHAR(20)     NOT NULL                -- sourced from Fleet Management System (Excel)
);
GO

/* ---------- DimLocation (role-played as Pickup / Drop via view aliasing) ---------- */
IF OBJECT_ID('dw.DimLocation', 'U') IS NOT NULL DROP TABLE dw.DimLocation;
CREATE TABLE dw.DimLocation (
    LocationKey     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    LocationName    VARCHAR(200)    NOT NULL UNIQUE,
    City            VARCHAR(30)     NOT NULL,               -- hierarchy: Location -> City -> Region
    Region          VARCHAR(20)     NOT NULL                -- sourced from Geo Mapping Service (JSON)
);
GO

/* ---------- DimPaymentMethod ---------- */
IF OBJECT_ID('dw.DimPaymentMethod', 'U') IS NOT NULL DROP TABLE dw.DimPaymentMethod;
CREATE TABLE dw.DimPaymentMethod (
    PaymentMethodKey INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    PaymentMethod     VARCHAR(50)   NOT NULL UNIQUE
);
GO

/* ---------- DimBookingStatus ---------- */
IF OBJECT_ID('dw.DimBookingStatus', 'U') IS NOT NULL DROP TABLE dw.DimBookingStatus;
CREATE TABLE dw.DimBookingStatus (
    BookingStatusKey INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    BookingStatus     VARCHAR(50)   NOT NULL UNIQUE,
    IsCompleted       BIT           NOT NULL,
    IsCancelled       BIT           NOT NULL
);
GO

/* ---------- DimCancellationReason (snowflaked off BookingStatus for cancelled/incomplete rides) ---------- */
IF OBJECT_ID('dw.DimCancellationReason', 'U') IS NOT NULL DROP TABLE dw.DimCancellationReason;
CREATE TABLE dw.DimCancellationReason (
    CancellationReasonKey INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ReasonText             VARCHAR(200) NOT NULL UNIQUE,
    ReasonSource            VARCHAR(20)  NOT NULL           -- Customer / Driver / Incomplete
);
GO
