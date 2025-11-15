-- ========================================================================
-- Investment Analysis Agent - Database and Schema Setup
-- ========================================================================
-- This script creates the core database infrastructure for SEC filing analysis
-- 
-- Prerequisites:
--   - User must have CREATE DATABASE privilege
--   - COMPUTE_WH warehouse must exist
--   - snowflake_intelligence database should exist (for Snowflake Intelligence)
--
-- Creates:
--   - Database: sec_files
--   - Schema: data
--   - Grants necessary permissions
-- ========================================================================

-- Enable cross-region inference for Cortex features (run as ACCOUNTADMIN)
-- Uncomment if not already enabled in your account
-- USE ROLE ACCOUNTADMIN;
-- ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

-- Create the Snowflake Intelligence infrastructure if not exists
-- This is required for Snowflake Intelligence agents
USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS snowflake_intelligence;
GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE PUBLIC;

--CREATE SCHEMA IF NOT EXISTS snowflake_intelligence.agents;
GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE PUBLIC;

-- Create the main database and schema for SEC filing data
CREATE DATABASE IF NOT EXISTS sec_files
    COMMENT = 'Database for SEC filing investment analysis data and tools';

CREATE SCHEMA IF NOT EXISTS sec_files.data
    COMMENT = 'Schema containing SEC metrics, semantic views, and supporting objects';

-- Grant usage to appropriate roles
-- Adjust these grants based on your access control requirements
GRANT USAGE ON DATABASE sec_files TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA sec_files.data TO ROLE PUBLIC;

-- Verify warehouse exists
-- The COMPUTE_WH warehouse is assumed to exist; create if needed
-- CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH 
--     WITH WAREHOUSE_SIZE = 'XSMALL'
--     AUTO_SUSPEND = 300
--     AUTO_RESUME = TRUE
--     COMMENT = 'Default warehouse for investment analysis';

-- Set context for subsequent operations
USE DATABASE sec_files;
USE SCHEMA data;
USE WAREHOUSE COMPUTE_WH;

-- ========================================================================
-- Verification
-- ========================================================================
SELECT 'Database and schema setup complete' AS status;
SHOW DATABASES LIKE 'sec_files';
SHOW SCHEMAS IN DATABASE sec_files;

