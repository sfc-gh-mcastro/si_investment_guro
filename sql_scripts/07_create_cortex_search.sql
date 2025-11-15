-- ========================================================================
-- Investment Analysis Agent - Cortex Search Service
-- ========================================================================
-- This script creates a Cortex Search service for vector search over
-- the chunked document content.
--
-- Prerequisites:
--   - DOCS_CHUNKS_TABLE populated with chunked text (06_create_document_stage.sql)
--   - At least some documents uploaded and processed
--   - Cortex Search enabled in your account
--
-- Creates:
--   - Cortex Search Service: corp_mem (corporate memory RAG search)
--
-- Note: This script will fail if DOCS_CHUNKS_TABLE is empty.
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
-- Example search query (uncomment to test):
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

-- ========================================================================
-- Usage Instructions
-- ========================================================================
SELECT 'Cortex Search service created successfully' AS status;
SELECT 'The corp_mem service can now be added as a tool to your Snowflake Intelligence agent' AS next_step;
SELECT 'Use SNOWFLAKE.CORTEX.SEARCH_PREVIEW() to test queries' AS usage_note;

-- ========================================================================
-- Search Service Information
-- ========================================================================
-- The corp_mem service indexes the "chunk" column for semantic search
-- You can filter results by "category" attribute if populated
-- 
-- Example usage from SQL:
--   SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
--       'corp_mem',
--       '{"query": "revenue analysis", "columns": ["chunk", "relative_path"], "limit": 3}'
--   );
--
-- When added to the agent, it will automatically search relevant documents
-- based on user questions and incorporate findings into responses.
--
-- OPTIONAL: Company Event Transcript Search
-- ========================================
-- You can optionally add earnings call transcripts via Snowflake UI:
-- 1. Install "Cortex Knowledge Extensions" from Snowflake Marketplace
-- 2. After agent creation, edit the agent in AI & ML > Agents
-- 3. Add Cortex Search tool pointing to:
--    SNOWFLAKE_PUBLIC_DATA_CORTEX_KNOWLEDGE_EXTENSIONS.AI.COMPANY_EVENT_TRANSCRIPT_CORTEX_SEARCH_SERVICE
-- 4. See docs/AGENT_SETUP.md for detailed instructions
-- ========================================================================

