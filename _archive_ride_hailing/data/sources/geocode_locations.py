"""
Geocodes every distinct location name in the dataset using OpenStreetMap's
Nominatim API (public, free, no auth key) and writes the real result to
data/sources/location_zone_reference.json.

This replaces the earlier hand-authored city/region guesses with genuine
external geocoding data, so this source is a real API call, not fabricated
reference data. Complies with Nominatim's usage policy: max 1 request/sec,
identifying User-Agent, results cached to this repo so the API isn't hit
again on every pipeline rebuild.

Usage: python3 data/sources/geocode_locations.py
"""
import json
import time
import urllib.request
import urllib.parse

HEADERS = {"User-Agent": "SLIIT-IT3101-DWBI-Assignment/1.0 (student coursework, non-commercial)"}
NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"

def geocode(location_name):
    params = {
        "q": f"{location_name}, Delhi NCR, India",
        "format": "json",
        "addressdetails": 1,
        "limit": 1,
    }
    url = NOMINATIM_URL + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.load(resp)
    if not data:
        return None
    addr = data[0].get("address", {})
    return {
        "lat": data[0].get("lat"),
        "lon": data[0].get("lon"),
        "city": addr.get("city") or addr.get("town") or addr.get("city_district")
                or addr.get("county") or addr.get("state_district"),
        "state": addr.get("state"),
        "raw_display_name": data[0].get("display_name"),
    }

def classify_region(city, state):
    # NCR Planning Board (Govt. of India) defines Delhi + adjoining districts of
    # Haryana/UP/Rajasthan as "Core NCR"; everything further out is "Outer NCR".
    core_ncr_areas = {"delhi", "new delhi", "gurugram", "gurgaon", "noida",
                       "ghaziabad", "faridabad", "greater noida"}
    if city and city.strip().lower() in core_ncr_areas:
        return "NCR Core"
    return "Outer NCR"

def main():
    locations = [l.strip() for l in open("/tmp/locations.txt") if l.strip()]
    results = []
    failures = []
    for i, loc in enumerate(locations, 1):
        try:
            g = geocode(loc)
        except Exception as e:
            g = None
            failures.append((loc, str(e)))
        if g and g["city"]:
            city = g["city"]
            region = classify_region(city, g["state"])
            results.append({
                "locationName": loc, "city": city, "region": region,
                "lat": g["lat"], "lon": g["lon"],
            })
        else:
            # Fallback: OSM has no clean city match for this exact place name.
            # Keep it, flagged, defaulting city to the location name itself.
            results.append({
                "locationName": loc, "city": loc, "region": "Unclassified",
                "lat": None, "lon": None,
            })
            failures.append((loc, "no geocode match"))
        print(f"[{i}/{len(locations)}] {loc} -> {results[-1]['city']} / {results[-1]['region']}")
        time.sleep(1.1)  # Nominatim usage policy: max 1 request/second

    out = {
        "source": "OpenStreetMap Nominatim geocoding API",
        "sourceUrl": "https://nominatim.openstreetmap.org/",
        "attribution": "Data (c) OpenStreetMap contributors, ODbL 1.0 - http://osm.org/copyright",
        "extractedOn": time.strftime("%Y-%m-%d"),
        "regionClassificationRule": "NCR Planning Board core-NCR district list "
                                     "(Delhi, Gurugram, Noida, Ghaziabad, Faridabad, Greater Noida "
                                     "= NCR Core; all other geocoded districts = Outer NCR)",
        "locations": results,
    }
    with open("data/sources/location_zone_reference.json", "w") as f:
        json.dump(out, f, indent=2)

    print(f"\nDone. {len(results)} locations written, {len(failures)} fallbacks/failures:")
    for loc, reason in failures:
        print(f"  - {loc}: {reason}")

if __name__ == "__main__":
    main()
