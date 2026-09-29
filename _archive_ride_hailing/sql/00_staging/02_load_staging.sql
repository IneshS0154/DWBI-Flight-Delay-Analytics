/* ============================================================
   Load raw CSV into staging (EXTRACT step).
   File is copied into the container at /var/opt/mssql first.
   FIRSTROW=2 skips the header. FORMAT='CSV' handles quoted fields.
   ============================================================ */
USE DWBI_RideHailing;
GO

TRUNCATE TABLE stg.RideBookings;
GO

BULK INSERT stg.RideBookings
FROM '/var/opt/mssql/ncr_ride_bookings.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,
    FIELDQUOTE      = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0a',
    TABLOCK
);
GO

SELECT COUNT(*) AS StagingRowCount FROM stg.RideBookings;
GO
