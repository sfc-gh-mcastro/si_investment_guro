-- ========================================================================
-- Investment Analysis Agent - Snowflake-Managed MCP Server
-- ========================================================================
-- This script creates a Snowflake-managed Model Context Protocol (MCP) server
-- that exposes investment analysis tools through a standards-based interface.
--
-- Prerequisites:
--   - SEC_REVENUE_SEMANTIC_VIEW created (03_create_semantic_view.sql)
--   - corp_mem Cortex Search service created (07_create_cortex_search.sql)
--   - SNOWFLAKE_INVESTMENT_GURO agent created (agent_scripts/create_agent.sql)
--   - User has CREATE MCP SERVER privilege on sec_files.data schema
--
-- Creates:
--   - MCP Server: SEC_INVESTMENT_MCP
--
-- Exposed Tools:
--   1. Cortex Analyst - Query SEC Revenue Data (text-to-SQL)
--   2. Cortex Search - Search Investment Documents (RAG)
--   3. Cortex Agent - Investment Guro Agent (full orchestration)
--   4. SQL Execution - Direct SQL query execution
--
-- Reference: https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp
-- ========================================================================

USE DATABASE sec_files;
USE SCHEMA data;
USE WAREHOUSE COMPUTE_WH;

-- ========================================================================
-- Grant Required Privileges for MCP Server Creation
-- ========================================================================
-- Ensure the role has necessary permissions
-- Adjust role as needed for your environment
USE ROLE ACCOUNTADMIN;

GRANT CREATE MCP SERVER ON SCHEMA sec_files.data TO ROLE ACCOUNTADMIN;
GRANT USAGE ON DATABASE sec_files TO ROLE ACCOUNTADMIN;
GRANT USAGE ON SCHEMA sec_files.data TO ROLE ACCOUNTADMIN;

-- Grant access to tools that will be exposed via MCP
GRANT SELECT ON SEMANTIC VIEW sec_files.data.SEC_REVENUE_SEMANTIC_VIEW TO ROLE ACCOUNTADMIN;
GRANT USAGE ON CORTEX SEARCH SERVICE sec_files.data.corp_mem TO ROLE ACCOUNTADMIN;
GRANT USAGE ON AGENT snowflake_intelligence.agents.SNOWFLAKE_INVESTMENT_GURO TO ROLE ACCOUNTADMIN;

-- ========================================================================
-- Create MCP Server Object
-- ========================================================================
-- The MCP server provides a unified interface for AI agents to discover
-- and invoke tools following the Model Context Protocol standard.
--
-- Important: Use hyphens (-) in tool names, not underscores (_)
-- MCP servers have connection issues with hostnames/names containing underscores
-- ========================================================================

CREATE OR REPLACE MCP SERVER sec_files.data.SEC_INVESTMENT_MCP
  FROM SPECIFICATION $$
    tools:
      - name: "revenue-semantic-view"
        type: "CORTEX_ANALYST_MESSAGE"
        identifier: "sec_files.data.SEC_REVENUE_SEMANTIC_VIEW"
        description: "Query SEC quarterly revenue metrics for publicly traded companies using natural language. This tool converts text questions into SQL queries against a semantic view containing company names, fiscal years, fiscal periods (quarters), and revenue values from official SEC filings. Use this for quantitative analysis of company financial performance, revenue trends, year-over-year comparisons, and fiscal period analysis."
        title: "Query SEC Revenue Data"
      
      - name: "search-investment-docs"
        type: "CORTEX_SEARCH_SERVICE_QUERY"
        identifier: "sec_files.data.corp_mem"
        description: "Search financial reports and SEC documents that have been uploaded to the system using semantic search. This tool performs RAG (Retrieval-Augmented Generation) over investment reports, annual reports, quarterly filings, and other financial documents. Use this for qualitative analysis, finding specific information in documents, and getting context beyond raw numbers. Results include presigned URLs for direct PDF access."
        title: "Search Investment Documents"
      
      - name: "investment-guro-agent"
        type: "CORTEX_AGENT_RUN"
        identifier: "snowflake_intelligence.agents.SNOWFLAKE_INVESTMENT_GURO"
        description: "Invoke the Snowflake Investment Guro agent which provides comprehensive investment analysis capabilities. This agent orchestrates multiple tools including SEC revenue data queries, document search, web search, and web scraping to deliver data-driven insights. Use this as a high-level entry point for complex investment analysis tasks that require multiple data sources and reasoning steps."
        title: "Investment Guro Agent"
      
      - name: "sql-executor"
        type: "SYSTEM_EXECUTE_SQL"
        description: "Execute SQL queries directly against the Snowflake database. This tool allows arbitrary SQL execution for advanced analysis, custom queries, and direct data access. Use this when you need to perform specific queries not covered by the semantic view, join data from multiple tables, or perform complex analytical operations. Note: Requires appropriate database and warehouse permissions."
        title: "SQL Execution Tool"
  $$;

-- ========================================================================
-- Grant Permissions on MCP Server
-- ========================================================================
-- USAGE privilege allows clients to connect and discover tools
-- Additional privileges on individual tools are required for invocation

-- Grant USAGE to roles that should be able to connect to the MCP server
GRANT USAGE ON MCP SERVER sec_files.data.SEC_INVESTMENT_MCP TO ROLE ACCOUNTADMIN;
GRANT USAGE ON MCP SERVER sec_files.data.SEC_INVESTMENT_MCP TO ROLE PUBLIC;

-- Note: Users also need USAGE/SELECT on the underlying tools:
-- - SELECT on semantic views for Cortex Analyst
-- - USAGE on search services for Cortex Search
-- - USAGE on agents for Cortex Agent
-- - Database/warehouse permissions for SQL execution

-- ========================================================================
-- Verification
-- ========================================================================
-- Display all MCP servers in the schema
SHOW MCP SERVERS IN SCHEMA sec_files.data;

-- Describe the MCP server to see its configuration
DESCRIBE MCP SERVER sec_files.data.SEC_INVESTMENT_MCP;

-- Display success message
SELECT 'MCP Server "SEC_INVESTMENT_MCP" created successfully!' AS status;
SELECT 'The server exposes 4 tools: Cortex Analyst, Cortex Search, Cortex Agent, and SQL Execution' AS tools_info;
SELECT 'Configure OAuth authentication using script 09_create_oauth_integration.sql' AS next_step;
SELECT 'See docs/MCP_SERVER_SETUP.md for client configuration and usage instructions' AS documentation;

-- ========================================================================
-- MCP Server Access Information
-- ========================================================================
-- API Endpoint Format:
--   POST /api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP
--
-- Required Authentication:
--   - OAuth 2.0 (recommended) - see 09_create_oauth_integration.sql
--   - Programmatic Access Token (PAT) with least-privileged role
--
-- MCP Protocol Operations:
--   - initialize: Establish connection and protocol version
--   - tools/list: Discover available tools
--   - tools/call: Invoke a specific tool
--
-- Supported MCP Protocol Version:
--   - 2025-06-18
--
-- Security Best Practices:
--   - Use OAuth instead of hardcoded tokens
--   - Use hyphens (-) in hostnames, not underscores (_)
--   - Grant minimum required privileges (least-privilege principle)
--   - Verify third-party MCP servers before integration
--   - Configure proper permissions for each tool independently
--
-- For detailed client configuration examples and API usage, see:
--   docs/MCP_SERVER_SETUP.md
-- ========================================================================

-- ========================================================================
-- Tool-Specific Permission Requirements
-- ========================================================================
/*
To use each tool, clients need the following permissions:

1. revenue-semantic-view (Cortex Analyst):
   - USAGE on MCP server
   - SELECT on sec_files.data.SEC_REVENUE_SEMANTIC_VIEW

2. search-investment-docs (Cortex Search):
   - USAGE on MCP server
   - USAGE on sec_files.data.corp_mem

3. investment-guro-agent (Cortex Agent):
   - USAGE on MCP server
   - USAGE on snowflake_intelligence.agents.SNOWFLAKE_INVESTMENT_GURO

4. sql-executor (SQL Execution):
   - USAGE on MCP server
   - Appropriate database, schema, and warehouse permissions
   - Specific object permissions based on query needs
*/

-- ========================================================================
-- Testing the MCP Server
-- ========================================================================
/*
After OAuth configuration, you can test the MCP server using:

1. Initialize the server:
   POST /api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP
   {
     "jsonrpc": "2.0",
     "id": 1,
     "method": "initialize",
     "params": { "protocolVersion": "2025-06-18" }
   }

2. List available tools:
   POST /api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP
   {
     "jsonrpc": "2.0",
     "id": 2,
     "method": "tools/list",
     "params": {}
   }

3. Invoke a tool (example with Cortex Analyst):
   POST /api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP
   {
     "jsonrpc": "2.0",
     "id": 3,
     "method": "tools/call",
     "params": {
       "name": "revenue-semantic-view",
       "arguments": {
         "message": "What was Snowflake's total revenue in fiscal year 2024?"
       }
     }
   }

For complete API documentation and client examples, see docs/MCP_SERVER_SETUP.md
*/

