
# Aadhaar Biometric Data SQL Analysis

## Project Overview
SQL analysis of 500,000-row Aadhaar demographic and enrolment datasets
to uncover state-wise authentication trends, age group distributions,
and enrolment-to-authentication ratios across India.

## Datasets
| File | Rows | Columns |
|------|------|---------|
| api_data_aadhar_demographic | 500,000 | date, state, district, pincode, demo_age_5_17, demo_age_17_ |
| api_data_aadhar_enrolment   | 500,000 | date, state, district, pincode, age_0_5, age_5_17, age_18_greater |

## Tools
- SQL (MySQL / PostgreSQL compatible)
- Python (pandas) for data loading and preprocessing

## Analysis Sections
1. Data Quality Checks — NULL checks, date ranges, distinct counts
2. Basic Aggregations — State and district level totals
3. Time Series — Monthly authentication trends
4. JOIN Analysis — Enrolment vs authentication comparison
5. Window Functions — RANK() by state, LAG() for MoM growth
6. Policy Insights — Auth-per-enrolment ratio, underserved states

## Key Findings
- Top 5 states by authentication: AP, Tamil Nadu, WB, UP, Maharashtra
- States with low child coverage identified using HAVING filter
- Month-over-month growth calculated using LAG() window function
- Auth-per-enrolment ratio highlights states with active vs passive users

## File Structure
aadhaar_sql_project.sql   # All 10 queries with comments
<img width="468" height="464" alt="image" src="https://github.com/user-attachments/assets/8eac6cf8-18f3-46c6-a096-4191e99e743c" />
