# Task 1: Dataset Selection and Business Scenario Identification

## Business Domain

**Transportation — Ride-Hailing / Mobility-as-a-Service (MaaS)**

Ride-hailing platforms (Uber, Ola, PickMe, Grab) operate a real-time marketplace that matches
passengers requesting trips with nearby available drivers, and record every step of that
transaction electronically. This makes the domain a natural fit for OLTP-to-OLAP analysis: every
booking is a discrete, timestamped, richly-attributed business event.

## Purpose of the System

The source system is the **booking/dispatch OLTP system** of a ride-hailing operator. Its job is
to capture, in real time, every ride request made through the app — who requested it, what type
of vehicle was assigned, where the pickup and drop-off were, how long the driver took to arrive,
whether the ride completed, and how much the customer was charged. This operational system is
optimised for fast transaction recording (one row per booking event), not for analysis — which is
exactly the gap a data warehouse is built to close.

## Business Problem Addressed

A ride-hailing operator generates thousands of bookings a day but, at the raw OLTP level, has no
easy way to answer strategic questions such as:

- Which regions or time bands suffer the highest cancellation and "no driver found" rates?
- Which vehicle categories are most profitable per kilometre, and which underperform?
- How does driver/customer satisfaction (ratings) vary by location, vehicle type or time of day?
- Are certain payment methods associated with higher cancellation or incomplete-ride rates?
- What are the demand peaks the operator should staff/incentivise drivers around?

These are classic **dimensional analysis questions** — they require slicing a large volume of
transactional records by multiple business dimensions simultaneously, which an OLTP system is not
designed to do efficiently. This is the business problem the data warehouse and BI solution in
this assignment addresses: turning raw booking transactions into fast, multi-dimensional
operational insight for management decision-making.

## Dataset Source

- **Dataset:** [Uber Ride Analytics Dashboard](https://www.kaggle.com/datasets/yashdevladdha/uber-ride-analytics-dashboard)
- **Platform:** Kaggle
- **File used:** `ncr_ride_bookings.csv`
- **Geographic scope:** National Capital Region (NCR), India — Delhi, Gurgaon, Noida, Ghaziabad,
  Faridabad and surrounding towns (176 distinct pickup/drop locations)
- **Time period:** 1 January 2024 – 30 December 2024 (a full operating year)

> **Note on scenario framing:** the raw data originates from an Uber-style operator in the Delhi
> NCR area. For this assignment the same dataset is used to model a generic ride-hailing
> operator's booking system — the dimensional design, ETL and BI techniques demonstrated are
> identical regardless of which real-world operator (Uber, PickMe, Ola, Grab) the data represents.

## Dataset Format

- **Raw format:** CSV (comma-separated values), UTF-8, 1 header row + 150,000 data rows
- **File size:** ~17 MB (uncompressed)

## Number of Records

**150,000 booking records**, each representing one ride request submitted through the app during
2024.

## Attributes Description

| # | Column (source) | Description |
|---|---|---|
| 1 | Date | Calendar date the booking was made (YYYY-MM-DD) |
| 2 | Time | Time of day the booking was made (HH:MM:SS) |
| 3 | Booking ID | Source system's booking reference (not unique — see Task 2/5 data-quality notes) |
| 4 | Booking Status | Completed / Cancelled by Customer / Cancelled by Driver / No Driver Found / Incomplete |
| 5 | Customer ID | Anonymised identifier of the requesting customer |
| 6 | Vehicle Type | Auto, Bike, eBike, Go Mini, Go Sedan, Premier Sedan, Uber XL |
| 7 | Pickup Location | Named pickup point (176 distinct values across NCR) |
| 8 | Drop Location | Named drop-off point (same 176-value location set) |
| 9 | Avg VTAT | Average Vehicle Turn-Around Time — minutes for the driver to reach the pickup point |
| 10 | Avg CTAT | Average Customer Turn-Around Time — minutes for the full trip to complete |
| 11 | Cancelled Rides by Customer | Flag: ride was cancelled by the customer |
| 12 | Reason for cancelling by Customer | Free-text/categorical reason (only populated when col. 11 is set) |
| 13 | Cancelled Rides by Driver | Flag: ride was cancelled by the driver |
| 14 | Driver Cancellation Reason | Categorical reason (only populated when col. 13 is set) |
| 15 | Incomplete Rides | Flag: ride started but did not finish |
| 16 | Incomplete Rides Reason | Categorical reason (only populated when col. 15 is set) |
| 17 | Booking Value | Fare charged for the ride, in local currency units |
| 18 | Ride Distance | Trip distance in kilometres |
| 19 | Driver Ratings | Rating (1–5) given to the driver for this trip |
| 20 | Customer Rating | Rating (1–5) given to the customer for this trip |
| 21 | Payment Method | UPI, Cash, Credit Card, Debit Card, Uber Wallet |

**Data quality characteristics identified during profiling** (see Task 5 for how each is handled):

- Nulls are **structural, not random**: `Booking Value`, `Ride Distance`, ratings and `Payment
  Method` are only populated for rides that actually completed or reached a chargeable state;
  the three "reason" columns are mutually exclusive and only populated for their matching
  cancellation/incompletion type.
- `Booking ID` is not a unique key — 1,233 IDs are reused across genuinely different bookings
  (different date, customer, vehicle). A surrogate key is used in the warehouse instead.
- All values arrive as text in the raw CSV (including numeric/date fields), and missing values
  are encoded as the literal string `"null"` rather than a true empty field.

## Why This Dataset Is Suitable for a DW/BI Solution

| Requirement | How this dataset satisfies it |
|---|---|
| Represents an OLTP system | Each row is a single, timestamped booking transaction — the natural grain of an operational booking system |
| Sufficient records for analytical processing | 150,000 rows spanning a full calendar year, enough for meaningful trend, seasonal and comparative analysis |
| Multiple attributes suitable for dimensional analysis | 21 source attributes naturally map to 8 dimensions (date, time, customer, vehicle type, pickup location, drop location, payment method, booking status/cancellation reason) |
| Supports fact and dimension table creation | Clear measures (fare, distance, VTAT/CTAT, ratings) at a well-defined grain (one row per booking), with categorical attributes that factor cleanly into conformed dimensions |
| Represents a realistic business scenario | Ride-hailing is a genuine, well-understood operational business with real decisions (driver allocation, pricing, service quality, regional strategy) that BI dashboards can meaningfully support |

This combination — high volume, rich dimensionality, a full year of time coverage, and
realistic, explainable data-quality issues — makes the dataset well suited to demonstrating the
complete DW/BI lifecycle required by this assignment: dimensional modelling, ETL with genuine
transformation logic, OLAP-style analysis, and BI dashboarding with actionable insights.
