"""
Fetches real daily historical weather (2008) for every airport used in the
flight delay sample, from Open-Meteo's free Historical Weather API (ERA5
reanalysis data, no API key required). One call per airport covers the
airport's full date range in a single request, rather than one call per
(airport, date) pair.

Usage: python3 data/sources/fetch_weather.py
Output: data/sources/airport_daily_weather_2008.json
"""
import json
import time
import ssl
import certifi
import urllib.request
import urllib.parse
import pandas as pd

ARCHIVE_URL = "https://archive-api.open-meteo.com/v1/archive"
SSL_CTX = ssl.create_default_context(cafile=certifi.where())

def fetch_weather(lat, lon, start_date, end_date):
    params = {
        "latitude": lat, "longitude": lon,
        "start_date": start_date, "end_date": end_date,
        "daily": "temperature_2m_max,temperature_2m_min,precipitation_sum,"
                 "snowfall_sum,windspeed_10m_max",
        "timezone": "UTC",
    }
    url = ARCHIVE_URL + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": "SLIIT-IT3101-DWBI-Assignment/1.0"})
    with urllib.request.urlopen(req, timeout=30, context=SSL_CTX) as resp:
        return json.load(resp)

def main():
    flights = pd.read_csv("data/raw/flight_delays_2008_sample.csv")
    flights['date'] = pd.to_datetime(dict(year=flights.Year, month=flights.Month, day=flights.DayofMonth))

    airports = pd.read_csv("data/sources/airports.dat", header=None,
        names=["AirportID","Name","City","Country","IATA","ICAO","Lat","Lon","Alt",
               "TZOffset","DST","TZ","Type","Source"])

    used_codes = sorted(set(flights['Origin']) | set(flights['Dest']))
    airports_used = airports[airports['IATA'].isin(used_codes)].drop_duplicates(subset='IATA')
    print(f"{len(airports_used)} distinct airports to fetch weather for")

    date_min = flights['date'].min().strftime("%Y-%m-%d")
    date_max = flights['date'].max().strftime("%Y-%m-%d")
    print(f"Date range: {date_min} to {date_max}")

    all_records = []
    failures = []
    for i, row in enumerate(airports_used.itertuples(), 1):
        try:
            data = fetch_weather(row.Lat, row.Lon, date_min, date_max)
            daily = data.get("daily", {})
            dates = daily.get("time", [])
            for j, d in enumerate(dates):
                all_records.append({
                    "iata": row.IATA,
                    "date": d,
                    "tempMaxC": daily["temperature_2m_max"][j],
                    "tempMinC": daily["temperature_2m_min"][j],
                    "precipitationMm": daily["precipitation_sum"][j],
                    "snowfallCm": daily["snowfall_sum"][j],
                    "windSpeedMaxKmh": daily["windspeed_10m_max"][j],
                })
            print(f"[{i}/{len(airports_used)}] {row.IATA} ({row.City}) -> {len(dates)} days")
        except Exception as e:
            failures.append((row.IATA, str(e)))
            print(f"[{i}/{len(airports_used)}] {row.IATA} FAILED: {e}")
        time.sleep(0.3)  # polite pacing, well under the 10,000/day free limit

    out = {
        "source": "Open-Meteo Historical Weather API (ERA5 reanalysis)",
        "sourceUrl": "https://open-meteo.com/en/docs/historical-weather-api",
        "extractedOn": time.strftime("%Y-%m-%d"),
        "dateRangeFetched": [date_min, date_max],
        "records": all_records,
    }
    with open("data/sources/airport_daily_weather_2008.json", "w") as f:
        json.dump(out, f)

    print(f"\nDone. {len(all_records)} airport-day weather records written.")
    print(f"Failures: {len(failures)}")
    for iata, reason in failures:
        print(f"  - {iata}: {reason}")

if __name__ == "__main__":
    main()
