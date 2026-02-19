use Adhar_biometric_enrollment ;
-- AADHAAR BIOMETRIC DATA SQL ANALYSIS PROJECT
-- Author: Jitika Gupta
-- Dataset: Aadhaar Demographic & Enrolment Records (500K rows each)
-- Tools: SQL (compatible with PostgreSQL / MySQL / SQL Server)

-- SECTION 1: DATA EXPLORATION & QUALITY CHECKS

-- 1.1 Preview first 10 rows of each table
RENAME TABLE `api_data_aadhar_demographic_0_500000` TO `adhaar_demographic`;
RENAME TABLE `api_data_aadhar_enrolment_0_500000` TO `adhaar_enrolment`;

SELECT * FROM adhaar_demographic LIMIT 10;
SELECT * FROM adhaar_enrolment   LIMIT 10;

-- 1.2 Count total records
SELECT COUNT(*) AS total_demographic_records FROM adhaar_demographic;
SELECT COUNT(*) AS total_enrolment_records   FROM adhaar_enrolment;

-- 1.3 Check date range in both tables
SELECT 
    MIN(date) AS earliest_date,
    MAX(date) AS latest_date
FROM adhaar_demographic;

SELECT 
    MIN(date) AS earliest_date,
    MAX(date) AS latest_date
FROM adhaar_enrolment;

-- 1.4 Check for NULL values
SELECT 
    SUM(CASE WHEN date IS NULL THEN 1 ELSE 0 END)          AS null_dates,
    SUM(CASE WHEN state IS NULL THEN 1 ELSE 0 END)         AS null_states,
    SUM(CASE WHEN district IS NULL THEN 1 ELSE 0 END)      AS null_districts,
    SUM(CASE WHEN demo_age_5_17 IS NULL THEN 1 ELSE 0 END) AS null_demo_5_17,
    SUM(CASE WHEN demo_age_17_ IS NULL THEN 1 ELSE 0 END)  AS null_demo_17
FROM adhaar_demographic;

-- 1.5 Count distinct states and districts
SELECT COUNT(DISTINCT state)    AS unique_states    FROM adhaar_demographic;
SELECT COUNT(DISTINCT district) AS unique_districts FROM adhaar_demographic;


-- 2.1 Total authentication counts by state (demographic)
SELECT 
    state,
    SUM(demo_age_5_17)                         AS total_auth_age_5_17,
    SUM(demo_age_17_)                          AS total_auth_age_17_plus,
    SUM(demo_age_5_17 + demo_age_17_)          AS total_authentications
FROM adhaar_demographic
GROUP BY state
ORDER BY total_authentications DESC;

-- 2.2 Total enrolments by state across all age groups
SELECT 
    state,
    SUM(age_0_5)           AS enrol_0_5,
    SUM(age_5_17)          AS enrol_5_17,
    SUM(age_18_greater)    AS enrol_18_plus,
    SUM(age_0_5 + age_5_17 + age_18_greater) AS total_enrolments
FROM adhaar_enrolment
GROUP BY state
ORDER BY total_enrolments DESC;

-- 2.3 Top 10 districts by total authentication volume
SELECT 
    state,
    district,
    SUM(demo_age_5_17 + demo_age_17_) AS total_authentications
FROM adhaar_demographic
GROUP BY state, district
ORDER BY total_authentications DESC
LIMIT 10;

-- 2.4 Monthly authentication trend (overall)
SELECT 
    DATE_FORMAT(date, '%Y-%m') AS month,        -- MySQL syntax
    -- TO_CHAR(date, 'YYYY-MM') AS month,        -- PostgreSQL syntax
    SUM(demo_age_5_17 + demo_age_17_) AS total_authentications
FROM adhaar_demographic
GROUP BY DATE_FORMAT(date, '%Y-%m')
ORDER BY month;

-- 3.1 State-wise average daily authentications
--     (Shows which states are consistently high performers)
SELECT 
    state,
    COUNT(DISTINCT date)                                  AS active_days,
    SUM(demo_age_5_17 + demo_age_17_)                    AS total_authentications,
    ROUND(
        SUM(demo_age_5_17 + demo_age_17_) * 1.0 
        / COUNT(DISTINCT date), 2
    )                                                     AS avg_daily_authentications
FROM adhaar_demographic
GROUP BY state
ORDER BY avg_daily_authentications DESC
LIMIT 15;

-- 3.2 Age group share in enrolments per state
--     (Identifies states with high child vs adult enrolment ratios)
SELECT 
    state,
    SUM(age_0_5)                                         AS enrol_0_5,
    SUM(age_5_17)                                        AS enrol_5_17,
    SUM(age_18_greater)                                  AS enrol_18_plus,
    ROUND(SUM(age_0_5) * 100.0 
        / NULLIF(SUM(age_0_5 + age_5_17 + age_18_greater), 0), 2) AS pct_0_5,
    ROUND(SUM(age_18_greater) * 100.0 
        / NULLIF(SUM(age_0_5 + age_5_17 + age_18_greater), 0), 2) AS pct_adult
FROM adhaar_enrolment
GROUP BY state
ORDER BY pct_adult DESC;

-- 3.3 JOIN: Compare enrolment vs authentication by state and month
--     (Key business question: are states that enrol more also authenticating more?)
SELECT 
    e.state,
    DATE_FORMAT(e.date, '%Y-%m')                              AS month,
    SUM(e.age_0_5 + e.age_5_17 + e.age_18_greater)           AS total_enrolments,
    SUM(d.demo_age_5_17 + d.demo_age_17_)                     AS total_authentications
FROM adhaar_enrolment e
JOIN adhaar_demographic d
    ON  e.state    = d.state
    AND e.district = d.district
    AND e.date     = d.date
GROUP BY e.state, DATE_FORMAT(e.date, '%Y-%m')
ORDER BY e.state, month;

-- 3.4 RANK states by total authentications using window function
SELECT 
    state,
    SUM(demo_age_5_17 + demo_age_17_)                     AS total_authentications,
    RANK() OVER (
        ORDER BY SUM(demo_age_5_17 + demo_age_17_) DESC
    )                                                      AS auth_rank
FROM adhaar_demographic
GROUP BY state;

-- 3.5 Bottom 10 states by enrolment (underserved regions)
SELECT 
    state,
    SUM(age_0_5 + age_5_17 + age_18_greater) AS total_enrolments
FROM adhaar_enrolment
GROUP BY state
ORDER BY total_enrolments ASC
LIMIT 10;

-- 3.6 District-level performance within each state using RANK()
--     (Find the top district in each state)
SELECT *
FROM (
    SELECT 
        state,
        district,
        SUM(demo_age_5_17 + demo_age_17_)        AS total_authentications,
        RANK() OVER (
            PARTITION BY state 
            ORDER BY SUM(demo_age_5_17 + demo_age_17_) DESC
        )                                         AS rank_within_state
    FROM adhaar_demographic
    GROUP BY state, district
) ranked
WHERE rank_within_state = 1
ORDER BY total_authentications DESC;

-- 3.7 Month-over-month authentication growth using LAG()
--     (Identifies which months saw a spike or drop in usage)
WITH monthly_totals AS (
    SELECT 
        DATE_FORMAT(date, '%Y-%m')                AS month,
        SUM(demo_age_5_17 + demo_age_17_)         AS total_authentications
    FROM adhaar_demographic
    GROUP BY DATE_FORMAT(date, '%Y-%m')
)
SELECT 
    month,
    total_authentications,
    LAG(total_authentications) OVER (ORDER BY month)  AS prev_month_authentications,
    ROUND(
        (total_authentications - LAG(total_authentications) OVER (ORDER BY month)) * 100.0
        / NULLIF(LAG(total_authentications) OVER (ORDER BY month), 0), 2
    )                                                  AS mom_growth_pct
FROM monthly_totals
ORDER BY month;

-- 3.8 States where adult enrolment (18+) exceeds 80% of total enrolments
SELECT 
    state,
    SUM(age_18_greater)                                         AS adult_enrolments,
    SUM(age_0_5 + age_5_17 + age_18_greater)                   AS total_enrolments,
    ROUND(SUM(age_18_greater) * 100.0 
        / NULLIF(SUM(age_0_5 + age_5_17 + age_18_greater), 0), 2) AS adult_pct
FROM adhaar_enrolment
GROUP BY state
HAVING ROUND(SUM(age_18_greater) * 100.0 
    / NULLIF(SUM(age_0_5 + age_5_17 + age_18_greater), 0), 2) > 80
ORDER BY adult_pct DESC;

-- 3.9 Pincode-level hotspots: Top 20 pincodes by authentication volume
SELECT 
    pincode,
    state,
    SUM(demo_age_5_17 + demo_age_17_) AS total_authentications
FROM adhaar_demographic
GROUP BY pincode, state
ORDER BY total_authentications DESC
LIMIT 20;

-- 3.10 Combined enrolment + authentication summary per state (final insight table)


WITH enrol_summary AS (
    SELECT state, SUM(age_0_5 + age_5_17 + age_18_greater) AS total_enrolments
    FROM adhaar_enrolment
    GROUP BY state
),
auth_summary AS (
    SELECT state, SUM(demo_age_5_17 + demo_age_17_) AS total_authentications
    FROM adhaar_demographic
    GROUP BY state
)

-- LEFT JOIN: all enrolment states + matching auth states
SELECT 
    COALESCE(e.state, a.state)  AS state,
    e.total_enrolments,
    a.total_authentications,
    ROUND(a.total_authentications * 1.0 
        / NULLIF(e.total_enrolments, 0), 4) AS auth_per_enrolment_ratio
FROM enrol_summary e
LEFT JOIN auth_summary a ON e.state = a.state

UNION

-- RIGHT JOIN: catches auth states not in enrolment table
SELECT 
    COALESCE(e.state, a.state)  AS state,
    e.total_enrolments,
    a.total_authentications,
    ROUND(a.total_authentications * 1.0 
        / NULLIF(e.total_enrolments, 0), 4) AS auth_per_enrolment_ratio
FROM enrol_summary e
RIGHT JOIN auth_summary a ON e.state = a.state

ORDER BY auth_per_enrolment_ratio DESC;