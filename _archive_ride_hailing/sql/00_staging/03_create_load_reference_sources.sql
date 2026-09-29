/* ============================================================
   Staging for the two reference sources (Task 2):
     - Vehicle Fleet Master   : native format = Excel (.xlsx), loaded from
                                the CSV export prepared alongside it, since
                                SQL Server has no native Excel reader on Linux.
     - Location Zone Reference: native format = JSON, loaded directly via
                                OPENJSON — no conversion needed.
   Both files are copied into the container by run_pipeline.sh before this
   script runs.
   ============================================================ */
USE DWBI_RideHailing;
GO

IF OBJECT_ID('stg.VehicleFleetMaster', 'U') IS NOT NULL DROP TABLE stg.VehicleFleetMaster;
CREATE TABLE stg.VehicleFleetMaster (
    VehicleType     VARCHAR(50),
    VehicleCategory VARCHAR(30),
    SeatingCapacity VARCHAR(10),
    FuelType        VARCHAR(20)
);
GO

TRUNCATE TABLE stg.VehicleFleetMaster;
BULK INSERT stg.VehicleFleetMaster
FROM '/var/opt/mssql/vehicle_fleet_master.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);
GO

IF OBJECT_ID('stg.LocationZoneReference', 'U') IS NOT NULL DROP TABLE stg.LocationZoneReference;
CREATE TABLE stg.LocationZoneReference (
    LocationName VARCHAR(200),
    City         VARCHAR(30),
    Region       VARCHAR(20)
);
GO

TRUNCATE TABLE stg.LocationZoneReference;

INSERT INTO stg.LocationZoneReference (LocationName, City, Region)
SELECT j.locationName, j.city, j.region
FROM OPENROWSET(BULK '/var/opt/mssql/location_zone_reference.json', SINGLE_CLOB) AS raw
CROSS APPLY OPENJSON(BulkColumn, '$.locations')
    WITH (
        locationName VARCHAR(200) '$.locationName',
        city         VARCHAR(30)  '$.city',
        region       VARCHAR(20)  '$.region'
    ) AS j;
GO

SELECT 'VehicleFleetMaster' AS t, COUNT(*) AS n FROM stg.VehicleFleetMaster
UNION ALL SELECT 'LocationZoneReference', COUNT(*) FROM stg.LocationZoneReference;
GO
