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
  COMMENT = 'Semantic view for SEC revenue analysis - enables natural language queries on company financial data'
  with extension (CA='{"verified_queries":[{"name":"Snowflake revenue by fiscal year all available years","question":"Snowflake revenue by fiscal year all available years","sql":"SELECT\\n  fiscal_year,\\n  SUM(value) AS total_revenue,\\n  MIN(period_start_date) AS start_date,\\n  MAX(period_end_date) AS end_date,\\n  COUNT(fiscal_period) AS num_quarters\\nFROM\\n  sec_metrics\\nWHERE\\n  company_name ILIKE ''%Snowflake%''\\n  AND variable_name ILIKE ''%REVENUE%''\\n  AND period_end_date <= CURRENT_DATE\\nGROUP BY\\n  fiscal_year\\nORDER BY\\n  fiscal_year DESC NULLS LAST","use_as_onboarding_question":false,"verified_by":"Marcel Castro","verified_at":1763237906},{"name":"what companies are available in the database with revenue data","question":"what companies are available in the database with revenue data","sql":"SELECT\\n  DISTINCT company_name,\\n  MIN(period_start_date) AS earliest_period_start,\\n  MAX(period_end_date) AS latest_period_end,\\n  COUNT(*) AS total_quarters\\nFROM\\n  sec_metrics\\nWHERE\\n  variable_name ILIKE ''%REVENUE%''\\n  AND period_end_date <= CURRENT_DATE\\nGROUP BY\\n  company_name\\nORDER BY\\n  company_name","use_as_onboarding_question":false,"verified_by":"Marcel Castro","verified_at":1763238425},{"name":"What is Snowflake''s total revenue across all reporting periods?","question":"What is Snowflake''s total revenue across all reporting periods?","sql":"WITH __sec_metrics AS (\\n  SELECT\\n    sec_metrics_daily.company_name AS company_name,\\n    sec_metrics_daily.period_end_date AS period_end_date,\\n    sec_metrics_daily.period_start_date AS period_start_date,\\n    sec_metrics_daily.variable_name AS variable_name,\\n    sec_metrics_daily.value AS value\\n  FROM\\n    __sec_metrics AS sec_metrics_daily\\n)\\nSELECT\\n  __sec_metrics.company_name AS company_name,\\n  MIN(__sec_metrics.period_start_date) AS start_date,\\n  MAX(__sec_metrics.period_end_date) AS end_date,\\n  SUM(__sec_metrics.value) AS total_revenue\\nFROM\\n  __sec_metrics AS __sec_metrics\\nWHERE\\n  UPPER(__sec_metrics.company_name) LIKE ''%SNOWFLAKE%''\\n  AND __sec_metrics.variable_name = ''REVENUE | QUARTERLY''\\nGROUP BY\\n  __sec_metrics.company_name\\nORDER BY\\n  total_revenue DESC NULLS LAST","use_as_onboarding_question":false,"verified_by":"Marcel Castro","verified_at":1763238445},{"name":"Snowflake revenue data all available years","question":"Snowflake revenue data all available years","sql":"SELECT\\n  company_name,\\n  fiscal_year,\\n  fiscal_period,\\n  value AS quarterly_revenue,\\n  period_start_date,\\n  period_end_date,\\n  MIN(period_start_date) OVER () AS data_start_date,\\n  MAX(period_end_date) OVER () AS data_end_date\\nFROM\\n  sec_metrics\\nWHERE\\n  company_name ILIKE ''%Snowflake%''\\n  AND variable_name ILIKE ''%REVENUE%''\\n  AND period_end_date <= CURRENT_DATE\\nORDER BY\\n  fiscal_year DESC,\\n  fiscal_period DESC NULLS LAST","use_as_onboarding_question":false,"verified_by":"Marcel Castro","verified_at":1763238487}]}');
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

-- ========================================================================
-- Example Query Pattern (for reference - not executed)
-- ========================================================================
-- This query demonstrates a common pattern for analyzing quarterly revenue
-- that Cortex Analyst can learn from through the semantic view structure.
--
-- Example: Get Snowflake's quarterly revenue summary
/*
WITH __sec_metrics AS (
  SELECT
    company_name,
    fiscal_period,
    fiscal_year,
    period_end_date,
    period_start_date,
    variable_name,
    value
  FROM sec_files.data.sec_metrics_daily
)
SELECT
  fiscal_year,
  fiscal_period,
  SUM(value) AS revenue,
  MIN(period_end_date) AS min_period_end,
  MAX(period_end_date) AS max_period_end,
  COUNT(period_end_date) AS period_count,
  MIN(period_start_date) AS data_start_date,
  MAX(period_start_date) AS data_end_date
FROM __sec_metrics
WHERE
  company_name ILIKE '%Snowflake%'
  AND variable_name ILIKE '%REVENUE%'
  AND period_end_date <= CURRENT_DATE
GROUP BY
  fiscal_year,
  fiscal_period
ORDER BY
  fiscal_year DESC,
  fiscal_period DESC NULLS LAST;
*/

