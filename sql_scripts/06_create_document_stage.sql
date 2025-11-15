-- ========================================================================
-- Investment Analysis Agent - Document Stage and Tables
-- ========================================================================
-- This script creates the infrastructure for storing and processing
-- unstructured documents (PDFs, etc.) for the Cortex Search service.
--
-- Prerequisites:
--   - Database and schema created (01_setup_database.sql)
--   - User has CREATE STAGE and CREATE TABLE privileges
--
-- Creates:
--   - Stage: OPEN_PAPERS (for PDF uploads)
--   - Temporary table: RAW_TEXT (for parsed PDF content)
--   - Table: DOCS_CHUNKS_TABLE (for chunked text ready for vector search)
--
-- Usage:
--   1. Run this script to create the stage and tables
--   2. Upload PDF files to the stage via Snowflake UI or PUT command
--   3. Run parsing SQL to populate RAW_TEXT from stage files
--   4. Run chunking SQL to populate DOCS_CHUNKS_TABLE
--   5. Create Cortex Search service (07_create_cortex_search.sql)
-- ========================================================================

USE DATABASE sec_files;
USE SCHEMA data;
USE WAREHOUSE COMPUTE_WH;

-- ========================================================================
-- Create Stage for Document Upload
-- ========================================================================
-- This stage will hold PDF files and other unstructured documents
-- Enable directory tables to easily track uploaded files
CREATE OR REPLACE STAGE OPEN_PAPERS
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for uploading PDF and document files for corporate memory / RAG search';

-- ========================================================================
-- Create Table for Raw Parsed Text
-- ========================================================================
-- Temporary table to hold the initial parsed content from PDFs
CREATE OR REPLACE TEMPORARY TABLE RAW_TEXT (
    RELATIVE_PATH VARCHAR(16777216),
    SIZE NUMBER(38,0),
    FILE_URL VARCHAR(16777216),
    scoped_file_url VARCHAR(16777216),
    presigned_url VARCHAR(16777216),
    EXTRACTED_LAYOUT VARCHAR(16777216)
)
COMMENT = 'Temporary table holding raw extracted text from PDF documents';

-- ========================================================================
-- Create Table for Document Chunks
-- ========================================================================
-- This table stores the chunked text that will be indexed by Cortex Search
CREATE OR REPLACE TABLE DOCS_CHUNKS_TABLE (
    RELATIVE_PATH VARCHAR(16777216),    -- Relative path to the PDF file
    SIZE NUMBER(38,0),                   -- Size of the PDF in bytes
    FILE_URL VARCHAR(16777216),          -- URL for the PDF
    presigned_url VARCHAR(16777216),     -- Presigned URL for secure access
    CHUNK VARCHAR(16777216),             -- Chunked piece of text
    CHUNK_INDEX INTEGER,                 -- Index for ordering chunks
    CATEGORY VARCHAR(16777216)           -- Optional category for filtering
)
COMMENT = 'Table containing chunked document text for Cortex Search indexing';

-- ========================================================================
-- Upload PDFs from Local Reports Folder
-- ========================================================================
-- Upload all PDF files from the reports folder to the stage
-- Note: This uses relative path from project root
PUT file:///Users/mcastro/Documents/github/sfc-gh-mcastro/si_investment_guro/reports/*.pdf @OPEN_PAPERS AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- Refresh the stage directory to see uploaded files
ALTER STAGE OPEN_PAPERS REFRESH;

-- Verify uploaded files
LIST @OPEN_PAPERS;

-- ========================================================================
-- Process PDFs: Parse and Chunk for Search
-- ========================================================================
-- Step 1: Parse PDFs and extract text
TRUNCATE TABLE RAW_TEXT;

INSERT INTO RAW_TEXT (relative_path, size, file_url, scoped_file_url, presigned_url, EXTRACTED_LAYOUT)
SELECT
    RELATIVE_PATH,
    SIZE,
    FILE_URL,
    BUILD_SCOPED_FILE_URL(@OPEN_PAPERS, relative_path) as scoped_file_url,
    GET_PRESIGNED_URL(@OPEN_PAPERS, relative_path) as presigned_url,
    TO_VARCHAR(
        SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
            '@OPEN_PAPERS',
            RELATIVE_PATH,
            {'mode': 'LAYOUT'}
        ):content
    ) AS EXTRACTED_LAYOUT
FROM
    DIRECTORY('@OPEN_PAPERS');

-- Step 2: Chunk the extracted text for better search results
TRUNCATE TABLE DOCS_CHUNKS_TABLE;

INSERT INTO DOCS_CHUNKS_TABLE (relative_path, size, file_url, presigned_url, chunk, chunk_index)
SELECT 
    relative_path,
    size,
    file_url,
    presigned_url,
    c.value::TEXT as chunk,
    c.INDEX::INTEGER as chunk_index
FROM
    RAW_TEXT,
    LATERAL FLATTEN(
        input => SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER(
            EXTRACTED_LAYOUT,
            'markdown',
            1512,      -- Max chunk size
            200        -- Overlap between chunks
        )
    ) c;

-- Step 3: Verify the chunked data
SELECT COUNT(*) as total_chunks, COUNT(DISTINCT relative_path) as total_documents
FROM DOCS_CHUNKS_TABLE;

SELECT * FROM DOCS_CHUNKS_TABLE LIMIT 10;

-- Summary of processed documents
SELECT 
    'Successfully processed ' || COUNT(DISTINCT relative_path) || ' PDF documents into ' || COUNT(*) || ' searchable chunks' AS processing_summary
FROM DOCS_CHUNKS_TABLE;

-- ========================================================================
-- Verification
-- ========================================================================
SHOW STAGES IN SCHEMA sec_files.data;
SHOW TABLES LIKE '%CHUNKS%' IN SCHEMA sec_files.data;

-- List any files currently in the stage (empty initially)
-- Files will be uploaded when you run the processing section above
-- LIST @OPEN_PAPERS;

SELECT 'Document stage and tables created successfully' AS status;
SELECT 'PDFs from reports/ folder will be uploaded and processed automatically' AS info;
SELECT 'Run the PDF processing section above to upload and index the documents' AS next_step;

