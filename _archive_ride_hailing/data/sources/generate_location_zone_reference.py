"""
Generates data/sources/location_zone_reference.json — a simulated export from a
separate Geo/Mapping Service that a real ride-hailing operator would maintain
independently of the booking system. Classification rules are a documented
modelling assumption (see Submission.md Task 2 / Task 4).
"""
import json

locations = [l.strip() for l in open("/tmp/locations.txt") if l.strip()]

OUTER_NCR = {"Meerut", "Panipat", "Sonipat", "Bahadurgarh", "Bhiwadi", "Pataudi Chowk"}
FARIDABAD_HINTS = ("Faridabad", "Gwal Pahari")
NOIDA_HINTS = ("Noida", "Greater Noida", "Botanical Garden")
GHAZIABAD = {"Ghaziabad", "Kaushambi", "Vaishali", "Indirapuram", "Raj Nagar Extension"}
GURGAON_HINTS = ("Gurgaon", "DLF")
GURGAON_NAMES = {
    "Cyber Hub", "Golf Course Road", "Sohna Road", "Manesar", "IMT Manesar",
    "Udyog Vihar", "Udyog Vihar Phase 4", "Sikanderpur", "Huda City Centre",
    "IFFCO Chowk", "Kherki Daula Toll", "Badshahpur", "Sushant Lok",
    "Vatika Chowk", "Ardee City", "Palam Vihar", "Hero Honda Chowk", "MG Road",
    "Kadarpur", "Khandsa", "Narsinghpur", "Basai Dhankot", "Ambience Mall",
    "Arjangarh",
}

def classify(name):
    if name in OUTER_NCR:
        return name, "Outer NCR"
    if any(h in name for h in FARIDABAD_HINTS):
        return "Faridabad", "NCR Core"
    if any(h in name for h in NOIDA_HINTS):
        return "Noida", "NCR Core"
    if name in GHAZIABAD:
        return "Ghaziabad", "NCR Core"
    if any(h in name for h in GURGAON_HINTS) or name in GURGAON_NAMES:
        return "Gurgaon", "NCR Core"
    return "Delhi", "NCR Core"

records = []
for loc in locations:
    city, region = classify(loc)
    records.append({"locationName": loc, "city": city, "region": region})

out = {
    "source": "GeoMappingService",
    "extractedOn": "2024-12-31",
    "locations": records,
}
with open("data/sources/location_zone_reference.json", "w") as f:
    json.dump(out, f, indent=2)

from collections import Counter
print(Counter(r["city"] for r in records))
print(Counter(r["region"] for r in records))
print(len(records), "locations written")
