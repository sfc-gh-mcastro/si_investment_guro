-- ========================================================================
-- Investment Analysis Agent - Semantic View for Cortex Analyst
-- ========================================================================
-- This script creates a semantic view on the SEC_METRICS_DAILY table.
-- The semantic view enables Cortex Analyst to understand the business context
-- and perform text-to-SQL query generation.
--
-- Prerequisites:
--   - Dynamic table SEC_METRICS_DAILY created (02_create_dynamic_table.sql)
--   - Cortex features enabled in account
--
-- Creates:
--   - Semantic view: SEC_REVENUE_SEMANTIC_VIEW
--
-- Note: This script creates the semantic view definition. You may need to
--       refine dimensions vs facts through the Snowflake UI:
--       - Move fiscal_year to DIMENSIONS
--       - Ensure value is in FACTS
-- ========================================================================

USE DATABASE sec_files;
USE SCHEMA data;
USE WAREHOUSE COMPUTE_WH;

-- ========================================================================
-- Create Semantic View for Cortex Analyst
-- ========================================================================
-- This creates a semantic view that enables Cortex Analyst to perform
-- text-to-SQL queries on SEC filing data.
--
-- Reference: https://docs.snowflake.com/en/user-guide/views-semantic/sql
-- ========================================================================

CREATE OR REPLACE SEMANTIC VIEW sec_files.data.SEC_REVENUE_SEMANTIC_VIEW
  TABLES (
    sec_metrics AS sec_files.data.SEC_METRICS_DAILY
      PRIMARY KEY (company_name, fiscal_year, fiscal_period)
      COMMENT = 'SEC quarterly revenue metrics for publicly traded companies'
  )
  FACTS (
    sec_metrics.value AS value
      COMMENT = 'The quarterly revenue amount in USD'
  )
  DIMENSIONS (
    sec_metrics.company_name AS company_name
      WITH SYNONYMS ('company', 'entity', 'business', 'corporation')
      COMMENT = 'The legal name of the company filing SEC reports',
    sec_metrics.variable_name AS variable_name
      COMMENT = 'The type of financial metric being reported (REVENUE | QUARTERLY)',
    sec_metrics.fiscal_year AS fiscal_year
      COMMENT = 'The fiscal year of the reported period',
    sec_metrics.fiscal_period AS fiscal_period
      WITH SYNONYMS ('quarter', 'period')
      COMMENT = 'The fiscal quarter (Q1, Q2, Q3, Q4)',
    sec_metrics.period_start_date AS period_start_date
      COMMENT = 'The start date of the reporting period',
    sec_metrics.period_end_date AS period_end_date
      COMMENT = 'The end date of the reporting period',
    sec_metrics.measure AS measure
      COMMENT = 'The measurement unit or type for the reported metric'
  )
  COMMENT = 'Semantic view for SEC revenue analysis - enables natural language queries on company financial data';

-- Grant necessary privileges for the agent to use this semantic view
GRANT REFERENCES, SELECT ON SEMANTIC VIEW sec_files.data.SEC_REVENUE_SEMANTIC_VIEW TO ROLE PUBLIC;

-- ========================================================================
-- Verification and Testing
-- ========================================================================
-- List all semantic views in the schema
SHOW SEMANTIC VIEWS IN SCHEMA sec_files.data;

-- Show dimensions defined in the semantic view
SHOW SEMANTIC DIMENSIONS IN SEC_REVENUE_SEMANTIC_VIEW;

-- Show facts defined in the semantic view
SHOW SEMANTIC FACTS IN SEC_REVENUE_SEMANTIC_VIEW;

-- Describe the semantic view structure
DESCRIBE SEMANTIC VIEW sec_files.data.SEC_REVENUE_SEMANTIC_VIEW;

-- Note: Semantic views cannot be queried directly with SELECT statements.
-- They are designed to be used by Cortex Analyst in Snowflake Intelligence agents.
-- The semantic view will translate natural language questions into SQL queries.

SELECT 'Semantic view created successfully!' AS status;
SELECT 'The semantic view is ready to be used as a tool in your Snowflake Intelligence agent' AS next_step;
SELECT 'Configure the agent via Snowflake UI following docs/AGENT_SETUP.md' AS instructions;

