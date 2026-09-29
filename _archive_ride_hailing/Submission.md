# IT3101 — Design and Implementation of a Data Warehouse and Business Intelligence Solution

**Business scenario:** Ride-hailing operator booking/dispatch system (Delhi NCR, 2024)
**Dataset:** [Uber Ride Analytics Dashboard](https://www.kaggle.com/datasets/yashdevladdha/uber-ride-analytics-dashboard) (Kaggle), `ncr_ride_bookings.csv`, 150,000 records
**Stack:** Microsoft SQL Server (Azure SQL Edge, Docker) · T-SQL ETL · Tableau

> This document is the master report. Each task section below states, verbatim from the
> assignment brief, what must be documented — then provides that content. Sections not yet
> completed are marked **`[TODO]`**.

---

## Task 1: Dataset Selection and Business Scenario Identification (10 Marks)

### Dataset Overview
*(brief requires: Business domain · Purpose of the system · Business problem addressed ·
Dataset source · Dataset format · Number of records · Attributes description)*

**Business domain:** Transportation — Ride-Hailing / Mobility-as-a-Service (MaaS).

**Purpose of the system:** The source is the booking/dispatch OLTP system of a ride-hailing
operator. It captures every ride request in real time — who requested it, which vehicle was
assigned, pickup/drop points, driver arrival time, completion status, and fare charged.

**Business problem addressed:** The operator cannot easily answer strategic questions from raw
transactional data alone — e.g. which regions/time bands have the highest cancellation rates,
which vehicle types are most profitable per km, how satisfaction varies by location/time, or
whether payment method correlates with cancellations. These require multi-dimensional slicing,
which an OLTP system is not designed for — the reason a data warehouse and BI layer are needed.

**Dataset source:** Kaggle, [Uber Ride Analytics Dashboard](https://www.kaggle.com/datasets/yashdevladdha/uber-ride-analytics-dashboard),
file `ncr_ride_bookings.csv`. Geographic scope: Delhi NCR, India. Time period: full year 2024
(2024-01-01 to 2024-12-30).

**Dataset format:** CSV, UTF-8, 1 header row + 150,000 data rows, ~17 MB uncompressed.

**Number of records:** 150,000 booking records.

**Attributes description:**

| # | Column (source) | Description |
|---|---|---|
| 1 | Date | Calendar date the booking was made (YYYY-MM-DD) |
| 2 | Time | Time of day the booking was made (HH:MM:SS) |
| 3 | Booking ID | Source system's booking reference (not unique — see Task 5 data-quality notes) |
| 4 | Booking Status | Completed / Cancelled by Customer / Cancelled by Driver / No Driver Found / Incomplete |
| 5 | Customer ID | Anonymised identifier of the requesting customer |
| 6 | Vehicle Type | Auto, Bike, eBike, Go Mini, Go Sedan, Premier Sedan, Uber XL |
| 7 | Pickup Location | Named pickup point (176 distinct values across NCR) |
| 8 | Drop Location | Named drop-off point (same 176-value location set) |
| 9 | Avg VTAT | Average Vehicle Turn-Around Time — minutes for the driver to reach pickup |
| 10 | Avg CTAT | Average Customer Turn-Around Time — minutes for the full trip to complete |
| 11 | Cancelled Rides by Customer | Flag: ride was cancelled by the customer |
| 12 | Reason for cancelling by Customer | Categorical reason (populated only when col. 11 is set) |
| 13 | Cancelled Rides by Driver | Flag: ride was cancelled by the driver |
| 14 | Driver Cancellation Reason | Categorical reason (populated only when col. 13 is set) |
| 15 | Incomplete Rides | Flag: ride started but did not finish |
| 16 | Incomplete Rides Reason | Categorical reason (populated only when col. 15 is set) |
| 17 | Booking Value | Fare charged for the ride |
| 18 | Ride Distance | Trip distance in kilometres |
| 19 | Driver Ratings | Rating (1–5) given to the driver for this trip |
| 20 | Customer Rating | Rating (1–5) given to the customer for this trip |
| 21 | Payment Method | UPI, Cash, Credit Card, Debit Card, Uber Wallet |

**Data quality characteristics identified during profiling:**
- Nulls are structural, not random: `Booking Value`, `Ride Distance`, ratings and `Payment Method`
  are only populated for rides that reached a chargeable state; the three reason columns are
  mutually exclusive.
- `Booking ID` is not unique — 1,233 IDs are reused across genuinely different bookings.
- All values arrive as text in the raw CSV, with missing values encoded as the literal string
  `"null"`.

### Why the dataset is suitable for a DW/BI solution

| Requirement | How this dataset satisfies it |
|---|---|
| Represents an OLTP system | Each row is a single, timestamped booking transaction |
| Sufficient records for analytical processing | 150,000 rows across a full calendar year |
| Multiple attributes suitable for dimensional analysis | 21 attributes map naturally to 8 dimensions |
| Supports fact and dimension table creation | Clear measures at a well-defined grain (one row per booking) |
| Represents a realistic business scenario | Ride-hailing has real, well-understood operational decisions BI can support |

---

## Task 2: Data Source Identification and Preparation (10 Marks)

Three source systems feed this data warehouse, chosen to reflect how a real ride-hailing operator
actually holds its data: the core booking transactions live in the dispatch platform's export,
while vehicle and location reference data are maintained by separate systems (a fleet management
system and a geo/mapping service respectively) — which is exactly why they arrive in different
formats and have to be integrated rather than simply concatenated.

### Documentation should include:

#### 1. Description of each data source

| Source | Represents | File |
|---|---|---|
| Ride Booking Transactions | The operator's booking/dispatch OLTP system — every ride request made through the app | `data/raw/ncr_ride_bookings.csv` |
| Vehicle Fleet Master | A separate Fleet Management System that tracks each vehicle category's physical specification | `data/sources/vehicle_fleet_master.xlsx` |
| Location Zone Reference | A separate Geo/Mapping Service that classifies every named pickup/drop point into a city and region | `data/sources/location_zone_reference.json` |

#### 2. Source format

| Source | Format | Notes |
|---|---|---|
| Ride Booking Transactions | CSV | 1 header row + 150,000 data rows, UTF-8, ~17 MB |
| Vehicle Fleet Master | Excel (`.xlsx`) | 1 worksheet, 7 data rows. SQL Server (Linux container) has no native Excel driver, so a same-content CSV export (`vehicle_fleet_master.csv`) is used for the actual load — see Data preparation steps |
| Location Zone Reference | JSON | Single document, `{ "source", "extractedOn", "locations": [...] }`, 176 array elements — loaded directly with T-SQL `OPENJSON`, no conversion needed |

#### 3. Available attributes

| Source | Attributes |
|---|---|
| Ride Booking Transactions | Date, Time, Booking ID, Booking Status, Customer ID, Vehicle Type, Pickup Location, Drop Location, Avg VTAT, Avg CTAT, cancellation flags + reasons (×3), Booking Value, Ride Distance, Driver/Customer Ratings, Payment Method (21 attributes — full list in Task 1) |
| Vehicle Fleet Master | VehicleType, VehicleCategory, SeatingCapacity, FuelType |
| Location Zone Reference | locationName, city, region (nested under a `locations` array, alongside document-level `source` and `extractedOn` metadata) |

#### 4. Relationship between sources

- **Ride Booking Transactions.VehicleType → Vehicle Fleet Master.VehicleType** (exact string match).
  Every one of the 7 distinct vehicle types in the transaction data has exactly one matching row
  in the fleet master — a clean 1:1 lookup relationship.
- **Ride Booking Transactions.PickupLocation / DropLocation → Location Zone Reference.locationName**
  (exact string match). All 176 distinct location names used across both pickup and drop columns
  are present in the zone reference — again a clean 1:1 lookup, applied twice (once per role:
  pickup and drop) since `DimLocation` is role-played in the fact table.
- Both reference sources are **conformed lookups**, not additional transactional grain — they
  enrich the booking fact's dimensions (`DimVehicleType`, `DimLocation`) rather than introducing a
  new business process or fact table.

#### 5. Data preparation steps

| Source | Preparation steps |
|---|---|
| Ride Booking Transactions | Copied into the SQL Server container filesystem; loaded as-is into `stg.RideBookings` via `BULK INSERT` with no cleansing (raw landing zone); all cleansing happens in the Transform stage (Task 5) |
| Vehicle Fleet Master | Authored the master data (7 vehicle types × category/capacity/fuel type); saved natively as `.xlsx`; exported to CSV (`vehicle_fleet_master.csv`) since the load tool (T-SQL `BULK INSERT`) cannot read `.xlsx` directly — this format conversion is itself a documented data-preparation step; loaded into `stg.VehicleFleetMaster` |
| Location Zone Reference | Derived the city/region classification for all 176 locations found in the booking data; saved as a single JSON document; loaded directly into `stg.LocationZoneReference` using T-SQL `OPENROWSET(BULK ..., SINGLE_CLOB)` + `OPENJSON` — no format conversion needed since SQL Server can parse JSON natively |

All three loads are orchestrated by `run_pipeline.sh` via
`sql/00_staging/01_create_staging.sql` (main source) and
`sql/00_staging/03_create_load_reference_sources.sql` (the two reference sources).

### Integrating data from different operational systems into a unified analytical environment

Each of the three sources is a snapshot from a **different operational system** (dispatch
platform, fleet management system, geo-mapping service) with its own format, refresh cadence and
owner. They are unified into one analytical environment through the standard staging-to-warehouse
pattern used throughout this project:

1. **Land each source in its native shape.** Every source gets its own staging table
   (`stg.RideBookings`, `stg.VehicleFleetMaster`, `stg.LocationZoneReference`), so format
   differences (CSV vs Excel-via-CSV vs JSON) are resolved once, at load time, rather than
   propagating downstream.
2. **Resolve to conformed business keys.** `VehicleType` and location name are the shared business
   keys across sources. Because all three sources use the same textual values for these keys
   (verified in the ETL validation — zero orphaned joins), a simple equi-join is enough to merge
   them; no fuzzy matching or manual key mapping was required.
3. **Merge into shared, conformed dimensions.** Rather than keeping three separate tables, the
   Transform/Load stage (Task 5) joins the booking data against both reference sources when
   populating `DimVehicleType` and `DimLocation`. The result is that a single `VehicleTypeKey` or
   `LocationKey` in the fact table now carries attributes sourced from *all* the operational
   systems that describe it — e.g. `DimVehicleType` combines booking-system usage with
   fleet-system specifications, and `DimLocation` combines booking-system location names with
   geo-service city/region classification.
4. **One query surface, many source systems.** Once loaded, an analyst or BI tool querying the
   `dw` schema never needs to know that vehicle specs came from Excel and location zones came from
   JSON — the star schema presents one consistent, integrated view regardless of source format or
   originating system.

---

## Task 3: Data Warehouse Architecture Design (10 Marks)

### Students must provide:
- [ ] Architecture diagram
- [ ] Explanation of each component

**`[TODO]`** — architecture diagram not yet drawn. Layers to depict, based on work done so far:

- **Data Source Layer:** raw `ncr_ride_bookings.csv` (+ additional sources from Task 2)
- **Data Integration Layer:** `stg.RideBookings` (raw landing) → `stg.RideBookings_Clean`
  (typed/cleansed) via the T-SQL scripts in `sql/03_etl/`
- **Storage Layer:** staging schema (`stg`) → enterprise data warehouse schema (`dw`, star
  schema) → data mart (Task 6, not yet built)
- **Presentation Layer:** Tableau dashboards (Task 7, not yet built)

---

## Task 4: Dimensional Data Warehouse Design and Implementation (20 Marks)

### Fact Table
*(brief requires: Business process · Grain · Measures · Foreign keys)*

**Business process:** Ride booking (a customer requests a ride through the app).
**Grain:** One row per booking (`FactRideBooking`, surrogate key `RideBookingKey`).
**Measures:** `AvgVTAT`, `AvgCTAT`, `BookingValue` (fare), `RideDistanceKm`, `DriverRating`,
`CustomerRating`, `FarePerKm` (derived), plus 4 status flags.
**Foreign keys:** `DateKey`, `TimeKey`, `CustomerKey`, `VehicleTypeKey`, `PickupLocationKey`,
`DropLocationKey`, `PaymentMethodKey`, `BookingStatusKey`, `CancellationReasonKey`.

### Dimension Tables

| Dimension | Role | Hierarchy |
|---|---|---|
| `DimDate` | Full 2024 calendar (366 rows, not just dates present in data) | Date → Month → Quarter → Year |
| `DimTime` | Every minute of day (1,440 rows) | Minute → Hour → Time-of-day band |
| `DimCustomer` | 148,788 distinct customers | — |
| `DimVehicleType` | 7 vehicle types, enriched with SeatingCapacity/FuelType from the Vehicle Fleet Master source (Task 2) | Vehicle Type → Category (Two-Wheeler / Three-Wheeler / Economy Car / Premium Car) |
| `DimLocation` | 176 locations, role-played as Pickup and Drop, enriched with City/Region from the Location Zone Reference source (Task 2) | Location → City → Region (NCR Core / Outer NCR) |
| `DimPaymentMethod` | 6 methods (incl. "Not Applicable") | — |
| `DimBookingStatus` | 5 statuses | — |
| `DimCancellationReason` | 13 reasons (snowflaked off status; incl. "Not Applicable") | Reason → Source (Customer/Driver/Incomplete) |

Schema type: **Star schema**, with `DimCancellationReason` as a light snowflake extension.

### Documentation should include:
- [x] Schema diagram — **`[TODO]`** visual ERD still needed (tables/keys are finalised, see DDL below)
- [x] Table descriptions — see tables above and DDL in `sql/01_dimensions/` and `sql/02_facts/`
- [x] Design assumptions:
  - `BookingID` is treated as a degenerate dimension attribute, not a primary/unique key, because
    1,233 values are reused across genuinely different bookings in the source data.
  - Every dimension includes a "Not Applicable" member so fact foreign keys are never NULL
    (e.g. bookings with no cancellation get the "Not Applicable" cancellation reason).
  - `DimDate` and `DimTime` are pre-populated for the full calendar/clock range rather than only
    values observed in the data, so the warehouse supports future incremental loads without a
    dimension rebuild.
  - `City`/`Region` (on `DimLocation`) and `VehicleCategory`/`SeatingCapacity`/`FuelType` (on
    `DimVehicleType`) are not present in the booking transactions — they are sourced from the two
    reference sources described in Task 2 (Location Zone Reference JSON and Vehicle Fleet Master
    Excel) and joined in during dimension load.

---

## Task 5: ETL Process Development (20 Marks)

### Extract
*(document: Extraction method · Source connection · Data extraction process)*

- **Extraction method:** Bulk file load (`BULK INSERT`) of the raw CSV into a SQL Server staging
  table (`stg.RideBookings`), all columns typed as `VARCHAR` (no cleansing at this stage).
- **Source connection:** File-based; the CSV is copied into the SQL Server container's filesystem
  (`docker cp`) and loaded via `sql/00_staging/02_load_staging.sql`.
- **Data extraction process:** `FORMAT='CSV'`, `FIRSTROW=2` (skip header), quoted-field handling
  via `FIELDQUOTE='"'`. Result: 150,000 rows landed with zero transformation.

### Transform

Performed in `sql/03_etl/01_transform_clean.sql`, producing `stg.RideBookings_Clean`:

| Issue found | Transformation applied |
|---|---|
| IDs wrapped in literal quote characters | Strip quotes via `REPLACE`/`TRIM` |
| Missing values stored as the string `'null'` | `NULLIF(..., 'null')` → real SQL `NULL` |
| Every column landed as text | `TRY_CAST` to `DATE`, `TIME`, `DECIMAL` as appropriate |
| Three separate reason columns | Collapsed into one `ReasonText` + `ReasonSource` pair |
| No fare-efficiency metric in source | Derived attribute: `FarePerKm = BookingValue / RideDistanceKm` |
| No time-of-day bucket in source | Derived `TimeKey` (HHMM) for join to `DimTime` |
| Duplicate `BookingID` values | **Not deduplicated** — confirmed these are distinct real bookings (different date/customer/vehicle), not duplicate records; a surrogate key handles this in the fact table |

### Load

Executed in `sql/03_etl/02_load_dimensions.sql` then `sql/03_etl/03_load_fact.sql`:
1. Dimensions loaded first (`DimDate`, `DimTime` generated programmatically; the rest via
   `SELECT DISTINCT` from the clean staging table).
2. `FactRideBooking` loaded via inner joins from `stg.RideBookings_Clean` to every dimension,
   resolving each business value to its surrogate key.
3. Loading sequence is enforced by foreign-key dependency order (dimensions → fact).

### Students should document:
- [x] ETL workflow — `run_pipeline.sh` executes the full sequence: create schema → extract →
  transform → load dimensions → load fact → validate.
- [x] Transformation logic — see Transform table above; full logic in
  `sql/03_etl/01_transform_clean.sql`.
- [x] Loading sequence — dimensions before fact (see Load above).
- [x] Validation results — 9 automated checks in `sql/03_etl/04_validate.sql`, **all passing**:

  | # | Check | Result |
  |---|---|---|
  | 1 | Row count: raw staging = clean staging | PASS |
  | 2 | Row count: clean staging = fact table | PASS |
  | 3 | No orphan foreign keys (all 9 dimension joins resolve) | PASS |
  | 4 | No literal 'null' strings or quote characters remain | PASS |
  | 5 | No failed type conversions (dates/times parsed) | PASS |
  | 6 | Total fare reconciles: staging vs fact | PASS |
  | 7 | Ratings within 1–5 range | PASS |
  | 8 | Fares and distances are positive when present | PASS |
  | 9 | Exactly one status flag set per booking | PASS |

---

## Task 6: Data Mart Development (10 Marks)

### Students must explain:
- [ ] Purpose of the data mart
- [ ] Target users
- [ ] Analytical benefits

**`[TODO]`** — not yet built. Candidate: an **Operations Data Mart** filtered/aggregated for
dispatch/operations managers, focused on cancellation and driver-arrival performance.

---

## Task 7: OLAP Analysis and Business Intelligence Dashboard Development (15 Marks)

Tool: **Tableau** (Power BI Desktop is Windows-only; not usable on the Mac used for development).

### Report Page 1: Executive Summary
- [ ] KPIs
- [ ] Summary cards
- [ ] Overall performance indicators

### Report Page 2: Trend Analysis
- [ ] Time-based analysis
- [ ] Line charts
- [ ] Comparison charts

### Report Page 3: Interactive Analysis
- [ ] Filters, Slicers, Drill-down, Roll-up

**`[TODO]`** — not yet built.

---

## Task 8: Business Insights and Recommendations (5 Marks)

**`[TODO]`** — minimum five insights required, each linked to a dashboard finding and a business
recommendation. To be completed after Task 7 dashboards exist.

---

## Usage of AI

**`[TODO]`** — brief requires acknowledging AI tool use. Draft note to adapt:

> AI (Claude) was used as a supporting tool throughout this project for: brainstorming the
> business scenario, drafting SQL DDL/ETL scripts (subsequently reviewed and validated by the
> student), explaining dimensional modelling trade-offs, and structuring this report. All design
> decisions (schema grain, dimension choices, city/category groupings) were reviewed and
> understood by the student before inclusion. AI-generated SQL was executed and validated against
> the actual dataset (see Task 5 validation results) rather than accepted on faith.
