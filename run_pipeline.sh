#!/bin/bash
# Re-runs the full pipeline from scratch: schema -> extract -> transform -> load -> validate
set -e
cd "$(dirname "$0")"
SQL="sqlcmd -S localhost,1433 -U sa -P ${MSSQL_SA_PASSWORD:-DwbiProject2024!} -C -b"

docker cp data/raw/flight_delays_2008_sample.csv dwbi-sqlserver:/var/opt/mssql/flight_delays_2008_sample.csv
docker cp data/sources/airports.dat dwbi-sqlserver:/var/opt/mssql/airports.dat
docker cp data/sources/airport_daily_weather_2008.json dwbi-sqlserver:/var/opt/mssql/airport_daily_weather_2008.json

for f in sql/00_staging/01_create_staging.sql \
         sql/01_dimensions/01_create_dimensions.sql \
         sql/02_facts/01_create_fact.sql \
         sql/00_staging/02_load_staging.sql \
         sql/03_etl/01_transform_clean.sql \
         sql/03_etl/02_load_dimensions.sql \
         sql/03_etl/03_load_fact.sql \
         sql/03_etl/04_validate.sql \
         sql/04_datamart/01_create_datamart.sql \
         sql/04_datamart/02_load_datamart.sql; do
  echo "=== $f"; $SQL -W -i "$f"
done
