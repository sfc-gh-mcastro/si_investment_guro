-- ========================================================================
-- Investment Analysis Agent - Cortex Search Services
-- ========================================================================
-- This script creates and configures Cortex Search services for investment analysis:
--   1. corp_mem: Custom search over uploaded documents (PDFs)
--   2. Company Event Transcripts: Snowflake's public data search service
--
-- Prerequisites:
--   - DOCS_CHUNKS_TABLE populated with chunked text (06_create_document_stage.sql)
--   - At least some documents uploaded and processed
--   - Cortex Search enabled in your account
--   - SNOWFLAKE_PUBLIC_DATA_CORTEX_KNOWLEDGE_EXTENSIONS data share installed
--
-- Creates:
--   - Cortex Search Service: corp_mem (corporate memory RAG search)
--   - Grants access to: COMPANY_EVENT_TRANSCRIPT_CORTEX_SEARCH_SERVICE
--
-- Note: corp_mem creation will fail if DOCS_CHUNKS_TABLE is empty.
--       Upload and process documents first using the SQL in script 06.
-- ========================================================================

USE DATABASE sec_files;
USE SCHEMA data;
USE WAREHOUSE COMPUTE_WH;

-- ========================================================================
-- Create Cortex Search Service
-- ========================================================================
-- This search service enables vector-based semantic search over documents
-- TARGET_LAG determines how fresh the search index is (refreshes every 50 minutes)
CREATE OR REPLACE CORTEX SEARCH SERVICE corp_mem
    ON chunk                          -- Column containing the text to search
    ATTRIBUTES category               -- Additional metadata for filtering
    WAREHOUSE = COMPUTE_WH
    TARGET_LAG = '50 minute'
    COMMENT = 'Corporate memory search service for RAG-based document retrieval in investment analysis'
AS (
    SELECT 
        chunk,
        chunk_index,
        relative_path,
        file_url,
        presigned_url,
        category
    FROM 
        sec_files.data.DOCS_CHUNKS_TABLE
);

-- Grant necessary privileges for using the search service
GRANT USAGE ON CORTEX SEARCH SERVICE corp_mem TO ROLE PUBLIC;

-- ========================================================================
-- Configure Access to Company Event Transcript Search Service
-- ========================================================================
-- This is a pre-built Cortex Search service from Snowflake's public data
-- containing company earnings calls, investor presentations, and transcripts
-- 
-- Prerequisite: Install the data share from Snowflake Marketplace:
-- https://app.snowflake.com/marketplace/listing/GZSTZ491VXY
-- "Cortex Knowledge Extensions by Snowflake"

-- Grant access to the company event transcript search service
GRANT USAGE ON DATABASE SNOWFLAKE_PUBLIC_DATA_CORTEX_KNOWLEDGE_EXTENSIONS TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA SNOWFLAKE_PUBLIC_DATA_CORTEX_KNOWLEDGE_EXTENSIONS.AI TO ROLE PUBLIC;
GRANT USAGE ON CORTEX SEARCH SERVICE SNOWFLAKE_PUBLIC_DATA_CORTEX_KNOWLEDGE_EXTENSIONS.AI.COMPANY_EVENT_TRANSCRIPT_CORTEX_SEARCH_SERVICE TO ROLE PUBLIC;

-- Verify access to company event transcript search service
SHOW CORTEX SEARCH SERVICES IN SCHEMA SNOWFLAKE_PUBLIC_DATA_CORTEX_KNOWLEDGE_EXTENSIONS.AI;

-- ========================================================================
-- Verification and Testing
-- ========================================================================
-- Check that the search service was created
SHOW CORTEX SEARCH SERVICES IN SCHEMA sec_files.data;

-- Get search service details
DESCRIBE CORTEX SEARCH SERVICE corp_mem;

-- Test the search service with a sample query
-- Note: This will only work if documents have been uploaded and processed
SELECT 'Testing Cortex Search service...' AS test_step;

/*
-- Example search query for corp_mem (uncomment to test):
SELECT 
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'corp_mem',
        '{
            "query": "financial statements",
            "columns": ["chunk", "relative_path"],
            "limit": 5
        }'
    ) AS search_results;
*/

/*
-- Example search query for company event transcripts (uncomment to test):
SELECT 
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'SNOWFLAKE_PUBLIC_DATA_CORTEX_KNOWLEDGE_EXTENSIONS.AI.COMPANY_EVENT_TRANSCRIPT_CORTEX_SEARCH_SERVICE',
        '{
            "query": "Apple quarterly earnings Q2 2024",
            "columns": ["chunk", "relative_path"],
            "limit": 5
        }'
    ) AS transcript_results;
*/

-- ========================================================================
-- Usage Instructions
-- ========================================================================
SELECT 'Cortex Search services configured successfully!' AS status;
SELECT '  • corp_mem: Custom document search' AS service1;
SELECT '  • COMPANY_EVENT_TRANSCRIPT: Earnings calls and investor presentations' AS service2;
SELECT 'Both services can now be used as tools in your Snowflake Intelligence agent' AS next_step;
SELECT 'Use SNOWFLAKE.CORTEX.SEARCH_PREVIEW() to test queries' AS usage_note;

-- ========================================================================
-- Search Service Information
-- ========================================================================
-- 1. corp_mem service:
--    - Indexes uploaded documents from @OPEN_PAPERS stage
--    - Searches on "chunk" column
--    - Filter by "category" attribute if populated
--    - Example: Financial reports, investment documents, internal PDFs
-- 
-- 2. COMPANY_EVENT_TRANSCRIPT service:
--    - Pre-built by Snowflake from public data
--    - Contains earnings calls, investor presentations, conference transcripts
--    - Covers major publicly traded companies
--    - Regularly updated with new transcripts
-- 
-- Example usage from SQL:
--   -- Search custom documents
--   SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
--       'corp_mem',
--       '{"query": "revenue analysis", "columns": ["chunk", "relative_path"], "limit": 3}'
--   );
--
--   -- Search company transcripts
--   SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
--       'SNOWFLAKE_PUBLIC_DATA_CORTEX_KNOWLEDGE_EXTENSIONS.AI.COMPANY_EVENT_TRANSCRIPT_CORTEX_SEARCH_SERVICE',
--       '{"query": "Tesla earnings guidance", "columns": ["chunk"], "limit": 3}'
--   );
--
-- When added to the agent, both services will automatically search based on
-- user questions and incorporate findings into comprehensive investment analysis.
-- ========================================================================

