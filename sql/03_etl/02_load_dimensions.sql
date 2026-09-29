/* ============================================================
   LOAD dimensions (must run before the fact table).
   ============================================================ */
USE DWBI_FlightDelay;
GO

DELETE FROM dw.FactFlightDeparture;
DELETE FROM dw.DimDate;
DELETE FROM dw.DimTime;
DELETE FROM dw.DimCarrier;
DELETE FROM dw.DimAirport;
DELETE FROM dw.DimCancellationReason;
GO

/* ---------- DimDate: full 2008 calendar (leap year, 366 days) ---------- */
SET DATEFIRST 7;
WITH d AS (
    SELECT CAST('2008-01-01' AS DATE) AS dt
    UNION ALL SELECT DATEADD(DAY, 1, dt) FROM d WHERE dt < '2008-12-31'
)
INSERT INTO dw.DimDate (DateKey, FullDate, DayOfMonth, DayName, DayOfWeek, IsWeekend,
                        MonthNumber, MonthName, Quarter, Year)
SELECT
    YEAR(dt) * 10000 + MONTH(dt) * 100 + DAY(dt),
    dt, DAY(dt), DATENAME(WEEKDAY, dt), DATEPART(WEEKDAY, dt),
    CASE WHEN DATEPART(WEEKDAY, dt) IN (1, 7) THEN 1 ELSE 0 END,
    MONTH(dt), DATENAME(MONTH, dt), DATEPART(QUARTER, dt), YEAR(dt)
FROM d
OPTION (MAXRECURSION 400);
GO

/* ---------- DimTime: every minute of day ---------- */
WITH n AS (
    SELECT 0 AS m
    UNION ALL SELECT m + 1 FROM n WHERE m < 1439
)
INSERT INTO dw.DimTime (TimeKey, HourNumber, MinuteNumber, TimeOfDayBand)
SELECT
    (m / 60) * 100 + (m % 60), m / 60, m % 60,
    CASE WHEN m / 60 BETWEEN 5  AND 11 THEN 'Morning'
         WHEN m / 60 BETWEEN 12 AND 16 THEN 'Afternoon'
         WHEN m / 60 BETWEEN 17 AND 21 THEN 'Evening'
         ELSE 'Night' END
FROM n
OPTION (MAXRECURSION 1500);
GO

/* ---------- DimCarrier: real BTS/IATA carrier code registry for the 20 airlines in this data ----------
   Source: publicly documented BTS carrier codes (historical, 2008); not fabricated. */
INSERT INTO dw.DimCarrier (CarrierCode, CarrierName)
SELECT DISTINCT f.UniqueCarrier,
    CASE f.UniqueCarrier
        WHEN '9E' THEN 'Pinnacle Airlines'
        WHEN 'AA' THEN 'American Airlines'
        WHEN 'AQ' THEN 'Aloha Airlines'
        WHEN 'AS' THEN 'Alaska Airlines'
        WHEN 'B6' THEN 'JetBlue Airways'
        WHEN 'CO' THEN 'Continental Airlines'
        WHEN 'DL' THEN 'Delta Air Lines'
        WHEN 'EV' THEN 'ExpressJet Airlines (Atlantic Southeast)'
        WHEN 'F9' THEN 'Frontier Airlines'
        WHEN 'FL' THEN 'AirTran Airways'
        WHEN 'HA' THEN 'Hawaiian Airlines'
        WHEN 'MQ' THEN 'American Eagle Airlines'
        WHEN 'NW' THEN 'Northwest Airlines'
        WHEN 'OH' THEN 'Comair'
        WHEN 'OO' THEN 'SkyWest Airlines'
        WHEN 'UA' THEN 'United Airlines'
        WHEN 'US' THEN 'US Airways'
        WHEN 'WN' THEN 'Southwest Airlines'
        WHEN 'XE' THEN 'ExpressJet Airlines'
        WHEN 'YV' THEN 'Mesa Airlines'
        ELSE f.UniqueCarrier + ' (code not in reference list)'
    END
FROM stg.Flights_Clean f;
GO

/* ---------- DimAirport: OpenFlights data (Task 2 source 2), filtered to airports actually used ---------- */
WITH used_codes AS (
    SELECT Origin AS IATA FROM stg.Flights_Clean
    UNION
    SELECT Dest FROM stg.Flights_Clean
)
INSERT INTO dw.DimAirport (IATA, ICAO, AirportName, City, Country, Latitude, Longitude, AltitudeFt)
SELECT DISTINCT u.IATA,
    NULLIF(a.ICAO, '\N'),
    a.Name, a.City, a.Country,
    CAST(a.Lat AS DECIMAL(9,6)), CAST(a.Lon AS DECIMAL(9,6)), CAST(a.Alt AS INT)
FROM used_codes u
JOIN stg.Airports a ON a.IATA = u.IATA;
GO

/* ---------- DimCancellationReason: BTS standard codes (real, publicly documented convention) ---------- */
INSERT INTO dw.DimCancellationReason (CancellationCode, Description)
VALUES
    ('N', 'Not Applicable (flight not cancelled)'),
    ('A', 'Carrier'),
    ('B', 'Weather'),
    ('C', 'National Air System'),
    ('D', 'Security');
GO

SELECT 'DimDate' t, COUNT(*) n FROM dw.DimDate UNION ALL
SELECT 'DimTime', COUNT(*) FROM dw.DimTime UNION ALL
SELECT 'DimCarrier', COUNT(*) FROM dw.DimCarrier UNION ALL
SELECT 'DimAirport', COUNT(*) FROM dw.DimAirport UNION ALL
SELECT 'DimCancellationReason', COUNT(*) FROM dw.DimCancellationReason;
GO
