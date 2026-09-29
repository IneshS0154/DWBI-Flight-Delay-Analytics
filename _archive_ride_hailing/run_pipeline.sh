#!/bin/bash
# Re-runs the full pipeline from scratch: schema -> extract -> transform -> load -> validate
set -e
cd "$(dirname "$0")"
SQL="sqlcmd -S localhost,1433 -U sa -P ${MSSQL_SA_PASSWORD:-DwbiProject2024!} -C -b"
docker cp data/raw/ncr_ride_bookings.csv dwbi-sqlserver:/var/opt/mssql/ncr_ride_bookings.csv
docker cp data/sources/vehicle_fleet_master.csv dwbi-sqlserver:/var/opt/mssql/vehicle_fleet_master.csv
docker cp data/sources/location_zone_reference.json dwbi-sqlserver:/var/opt/mssql/location_zone_reference.json
for f in sql/00_staging/01_create_staging.sql \
         sql/01_dimensions/01_create_dimensions.sql \
         sql/02_facts/01_create_fact.sql \
         sql/00_staging/02_load_staging.sql \
         sql/00_staging/03_create_load_reference_sources.sql \
         sql/03_etl/01_transform_clean.sql \
         sql/03_etl/02_load_dimensions.sql \
         sql/03_etl/03_load_fact.sql \
         sql/03_etl/04_validate.sql; do
  echo "=== $f"; $SQL -W -i "$f"
done
