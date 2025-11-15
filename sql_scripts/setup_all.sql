-- ========================================================================
-- Investment Analysis Agent - Complete Setup Script
-- ========================================================================
-- This master script runs all setup scripts in the correct order to create
-- the complete SEC filing investment analysis infrastructure.
--
-- Prerequisites:
--   1. Snow CLI installed and configured: snow connection add
--   2. User must have ACCOUNTADMIN role (for external access integration)
--   3. SNOWFLAKE_PUBLIC_DATA_PAID data share installed from Marketplace
--   4. COMPUTE_WH warehouse exists (or modify scripts to create it)
--   5. Cortex features enabled (cross-region inference if needed)
--
-- Usage:
--   snow sql -f sql_scripts/setup_all.sql
--   
--   OR from Snowflake UI:
--   Copy and paste each script section into a worksheet and execute
--
-- Created objects:
--   - Database: sec_files
--   - Schema: data
--   - Dynamic Table: SEC_METRICS_DAILY
--   - Semantic View: SEC_REVENUE_SEMANTIC_VIEW
--   - Network Rule and External Access Integration
--   - Functions: Web_scrape, Web_search
--   - Stage: OPEN_PAPERS
--   - Tables: RAW_TEXT (temp), DOCS_CHUNKS_TABLE
--   - Cortex Search Service: corp_mem
--   - Agent: SNOWFLAKE_INVESTMENT_GURO (4 core tools)
--
-- Post-setup:
--   1. Upload PDF documents to @OPEN_PAPERS stage
--   2. Run document processing SQL (in script 06)
--   3. Agent is automatically created and ready to use via Snowflake UI
-- ========================================================================

SELECT 'Starting Investment Analysis Agent setup...' AS status;
SELECT 'This will create all necessary database objects and functions' AS info;

-- ========================================================================
-- STEP 1: Database and Schema Setup
-- ========================================================================
SELECT '========================================' AS separator;
SELECT 'STEP 1: Creating database and schema...' AS current_step;

!source 01_setup_database.sql;

-- ========================================================================
-- STEP 2: Dynamic Table for SEC Metrics
-- ========================================================================
SELECT '========================================' AS separator;
SELECT 'STEP 2: Creating dynamic table for SEC metrics...' AS current_step;

!source 02_create_dynamic_table.sql;

-- ========================================================================
-- STEP 3: Semantic View for Cortex Analyst
-- ========================================================================
SELECT '========================================' AS separator;
SELECT 'STEP 3: Creating semantic view for Cortex Analyst...' AS current_step;

!source 03_create_semantic_view.sql;

-- ========================================================================
-- STEP 4: External Access Integration
-- ========================================================================
SELECT '========================================' AS separator;
SELECT 'STEP 4: Creating external access integration...' AS current_step;
SELECT 'Note: Requires ACCOUNTADMIN role' AS note;

!source 04_create_external_access.sql;

-- ========================================================================
-- STEP 5: Web Access Functions
-- ========================================================================
SELECT '========================================' AS separator;
SELECT 'STEP 5: Creating web scrape and search functions...' AS current_step;

!source 05_create_web_functions.sql;

-- ========================================================================
-- STEP 6: Document Stage and Tables
-- ========================================================================
SELECT '========================================' AS separator;
SELECT 'STEP 6: Creating document stage and processing tables...' AS current_step;

!source 06_create_document_stage.sql;

-- ========================================================================
-- STEP 7: Cortex Search Service (Optional)
-- ========================================================================
SELECT '========================================' AS separator;
SELECT 'STEP 7: Creating Cortex Search service...' AS current_step;
SELECT 'Note: Will skip if no documents uploaded yet' AS note;

-- Uncomment the following line after uploading and processing documents:
-- !source 07_create_cortex_search.sql;

-- ========================================================================
-- STEP 8: Create Snowflake Intelligence Agent
-- ========================================================================
SELECT '========================================' AS separator;
SELECT 'STEP 8: Creating Snowflake Investment Guro agent...' AS current_step;
SELECT 'Note: Agent will be created with 4 core tools' AS note;

!source ../agent_scripts/create_agent.sql;

-- ========================================================================
-- Setup Complete
-- ========================================================================
SELECT '========================================' AS separator;
SELECT '✓ Investment Analysis Agent setup complete!' AS status;
SELECT '' AS blank_line;
SELECT 'Created objects:' AS summary;
SELECT '  • Database: sec_files' AS obj1;
SELECT '  • Schema: data' AS obj2;
SELECT '  • Dynamic Table: SEC_METRICS_DAILY' AS obj3;
SELECT '  • Semantic View: SEC_REVENUE_SEMANTIC_VIEW' AS obj4;
SELECT '  • External Access Integration' AS obj5;
SELECT '  • Functions: Web_scrape, Web_search' AS obj6;
SELECT '  • Stage: OPEN_PAPERS' AS obj7;
SELECT '  • Tables: RAW_TEXT, DOCS_CHUNKS_TABLE' AS obj8;
SELECT '  • Cortex Search: corp_mem (custom docs)' AS obj9;
SELECT '  • Agent: SNOWFLAKE_INVESTMENT_GURO (4 core tools)' AS obj10;
SELECT '' AS blank_line;

SELECT 'Next steps:' AS next_steps_header;
SELECT '  1. Access the agent via Snowflake UI: AI & ML > Agents' AS step1;
SELECT '  2. Try sample questions with the Snowflake Investment Guro agent' AS step2;
SELECT '  3. Optional: Add Company Event Transcript tool via UI (see README.md)' AS step3;
SELECT '  4. Upload PDF documents to @OPEN_PAPERS stage (optional)' AS step4;
SELECT '  5. Process documents using SQL in script 06 (if PDFs uploaded)' AS step5;
SELECT '  6. Run script 07 to create Cortex Search service (if PDFs uploaded)' AS step6;
SELECT '' AS blank_line;

SELECT 'The agent is now ready to use with these 4 core tools:' AS tools_header;
SELECT '  • Query SEC Revenue Data (Cortex Analyst)' AS tool1;
SELECT '  • Search Investment Documents (Cortex Search - corp_mem)' AS tool2;
SELECT '  • Search_Web (DuckDuckGo web search)' AS tool3;
SELECT '  • Web_scraper (Extract content from web pages)' AS tool4;
SELECT '' AS blank_line;

SELECT 'Optional 5th tool (add via UI):' AS optional_header;
SELECT '  • Search Company Event Transcripts (earnings calls & presentations)' AS optional1;
SELECT '  • See README.md and docs/AGENT_SETUP.md for instructions' AS optional2;
SELECT '' AS blank_line;

SELECT 'For UI-based agent configuration (alternative), see:' AS docs;
SELECT '  docs/AGENT_SETUP.md' AS docs_file;

-- ========================================================================
-- Quick Verification
-- ========================================================================
USE DATABASE sec_files;
USE SCHEMA data;

SELECT '========================================' AS separator;
SELECT 'Quick verification:' AS verification_header;

SHOW DYNAMIC TABLES;
SHOW SEMANTIC VIEWS;
SHOW FUNCTIONS LIKE 'Web_%' IN SCHEMA snowflake_intelligence.agents;
SHOW STAGES;
SHOW TABLES LIKE '%CHUNKS%';
SHOW AGENTS IN SCHEMA snowflake_intelligence.agents;

SELECT 'Run "SHOW CORTEX SEARCH SERVICES IN SCHEMA sec_files.data;" after creating corp_mem' AS search_note;
SELECT 'Agent ready at: Snowflake UI > AI & ML > Agents > Snowflake Investment Guro' AS agent_access;
SELECT 'Agent has 4 core tools (optional 5th tool can be added via UI)' AS agent_capabilities;

