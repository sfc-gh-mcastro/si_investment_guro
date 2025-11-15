-- ========================================================================
-- Investment Analysis Agent - Dynamic Table for SEC Metrics
-- ========================================================================
-- This script creates a dynamic table that filters and refreshes SEC filing data
-- from the Snowflake Public Data marketplace.
--
-- Prerequisites:
--   - Database and schema created (01_setup_database.sql)
--   - SNOWFLAKE_PUBLIC_DATA_PAID data share installed from Marketplace
--   - User has ACCESS to the SNOWFLAKE_PUBLIC_DATA_PAID.PUBLIC_DATA share
--   - COMPUTE_WH warehouse available
--
-- Creates:
--   - Dynamic table: SEC_METRICS_DAILY (quarterly revenue data)
--   - Automatically refreshes every 1 day
-- ========================================================================

USE DATABASE sec_files;
USE SCHEMA data;
USE WAREHOUSE COMPUTE_WH;

-- Create dynamic table for SEC quarterly revenue metrics
-- This filters the large SEC timeseries data to only quarterly revenue
-- TARGET_LAG = '1 day' means data will be at most 1 day behind source
CREATE OR REPLACE DYNAMIC TABLE sec_files.data.SEC_METRICS_DAILY
    TARGET_LAG = '1 day'
    WAREHOUSE = COMPUTE_WH
    COMMENT = 'Filtered SEC metrics focusing on quarterly revenue data for investment analysis'
AS
SELECT 
    *
FROM 
    SNOWFLAKE_PUBLIC_DATA_PAID.PUBLIC_DATA.SEC_METRICS_TIMESERIES
WHERE 
    fiscal_period != 'FY'  -- Exclude full fiscal year, keep quarters (Q1, Q2, Q3, Q4)
    AND variable_name = 'REVENUE | QUARTERLY';  -- Focus on quarterly revenue only

-- ========================================================================
-- Verification
-- ========================================================================
-- Check that dynamic table was created
SHOW DYNAMIC TABLES IN SCHEMA sec_files.data;

-- Preview the data (should show quarterly revenue metrics)
SELECT 
    'Dynamic table created with ' || COUNT(*) || ' records' AS status
FROM 
    sec_files.data.SEC_METRICS_DAILY;

-- Sample query to verify data structure
SELECT 
    company_name,
    cik,
    fiscal_year,
    fiscal_period,
    variable_name,
    value,
    period_end_date
FROM 
    sec_files.data.SEC_METRICS_DAILY
LIMIT 10;

SELECT 'Dynamic table setup complete' AS status;

