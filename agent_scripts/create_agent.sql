-- ========================================================================
-- Snowflake Investment Guro Agent Creation Script
-- ========================================================================
-- This script creates a Snowflake Intelligence agent for SEC filing investment
-- analysis with integrated tools for quantitative and qualitative analysis.
--
-- NOTE: This script creates the agent with 4 core tools. After creation, you can
--       optionally add the Company Event Transcript search tool via Snowflake UI
--       (see docs/AGENT_SETUP.md for instructions).
--
-- Prerequisites:
--   - All infrastructure scripts (01-07) completed successfully
--   - SEC_REVENUE_SEMANTIC_VIEW created
--   - corp_mem Cortex Search service created
--   - Web_search and Web_scrape functions created
--   - User has CREATE AGENT privilege on snowflake_intelligence.agents schema
--
-- Creates:
--   - Snowflake Intelligence Agent: SNOWFLAKE_INVESTMENT_GURO
--
-- Agent Tools:
--   1. Cortex Analyst - Query SEC Revenue Data (text-to-SQL on semantic view)
--   2. Cortex Search - Search Investment Documents (RAG on uploaded PDFs)
--   3. Web Search - Search_Web (find relevant URLs via DuckDuckGo)
--   4. Web Scraper - Web_scraper (extract content from web pages)
-- ========================================================================

-- Ensure we have the right role for agent creation
-- Note: User needs appropriate privileges; adjust role as needed
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-- Grant necessary privileges for agent creation if not already granted
GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE ACCOUNTADMIN;
GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE ACCOUNTADMIN;
GRANT CREATE AGENT ON SCHEMA snowflake_intelligence.agents TO ROLE ACCOUNTADMIN;

-- Grant access to required resources
GRANT USAGE ON DATABASE sec_files TO ROLE ACCOUNTADMIN;
GRANT USAGE ON SCHEMA sec_files.data TO ROLE ACCOUNTADMIN;
GRANT SELECT ON SEMANTIC VIEW sec_files.data.SEC_REVENUE_SEMANTIC_VIEW TO ROLE ACCOUNTADMIN;
GRANT USAGE ON CORTEX SEARCH SERVICE sec_files.data.corp_mem TO ROLE ACCOUNTADMIN;
GRANT USAGE ON FUNCTION snowflake_intelligence.agents.Web_search(STRING) TO ROLE ACCOUNTADMIN;
GRANT USAGE ON FUNCTION snowflake_intelligence.agents.Web_scrape(STRING) TO ROLE ACCOUNTADMIN;

-- ========================================================================
-- Create the Snowflake Investment Guro Agent
-- ========================================================================

CREATE OR REPLACE AGENT snowflake_intelligence.agents.SNOWFLAKE_INVESTMENT_GURO
WITH PROFILE='{ "display_name": "Snowflake Investment Guro" }'
    COMMENT=$$ Investment analysis agent specializing in SEC filing analysis, combining quantitative revenue data with qualitative document search and web research capabilities. $$
FROM SPECIFICATION $$
{
  "models": {
    "orchestration": ""
  },
  "instructions": {
    "response": "You are an investment analyst specializing in SEC filing analysis. 
    Provide data-driven insights from quarterly revenue metrics. 
    Use web tools to supplement with current market information. Generate visualizations when appropriate to illustrate trends and comparisons. 
    Always cite your data sources and distinguish between historical SEC data, document-based insights, and current web information.
    Always present the references to the data sources in the response.
    When citing documents from the Search Investment Documents tool, include the presigned_url as a clickable link so users can access the source PDF.",
    "orchestration": "Use Cortex Analyst for quantitative SEC revenue analysis when users ask about specific companies' financial metrics or revenue trends. 
    Use Cortex Search for qualitative analysis from uploaded financial reports and investment documents. 
    Use Web_search to find relevant financial news URLs and current market information. 
    Use Web_scrape to extract content from identified web pages for deeper analysis. 
    Combine multiple data sources for comprehensive investment analysis. 
    When comparing companies, always use the semantic view for structured data first, then supplement with document search and web research. 
    ",
    "sample_questions": [
      {
        "question": "What was Apple's quarterly revenue in Q2 2024?"
      },
      {
        "question": "Compare Microsoft and Amazon's quarterly revenue trends over the last year"
      },
      {
        "question": "Search for recent news about Tesla's earnings"
      },
      {
        "question": "What are the revenue trends for NVIDIA in the past 4 quarters?"
      },
      {
        "question": "Find information about Meta's latest SEC filings"
      },
      {
        "question": "Show me revenue growth comparison between Google and Apple"
      }
    ]
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query SEC Revenue Data",
        "description": "Allows users to query SEC quarterly revenue metrics for publicly traded companies. Use this tool for quantitative analysis of company financial performance, revenue trends, year-over-year comparisons, and fiscal period analysis. The data includes company names, fiscal years, fiscal periods (quarters), and revenue values from official SEC filings."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search Investment Documents",
        "description": "Search financial reports and SEC documents that have been uploaded to the system. Use this tool for qualitative analysis, finding specific information in investment reports, annual reports, quarterly filings, and other financial documents. This provides context and detailed analysis beyond raw numbers. Results include presigned_url for direct PDF access."
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "Search_Web",
        "description": "This Python-based function acts as a web search tool, designed to find and return a structured list of search results for a given query. It performs an HTTP request to a specialized HTML endpoint of the DuckDuckGo search engine. The function automatically filters out sponsored advertisements and extracts the title, URL, and content snippet from the top three organic search results. The output is a machine-readable JSON string, making it an ideal first-step tool for an AI agent or any automated workflow. The function is marked as VOLATILE because its results depend on external, unpredictable data. It requires external network access through the Snowflake_intelligence_ExternalAccess_Integration, and users should be mindful of permissions and adherence to search engine policies.",
        "input_schema": {
          "type": "object",
          "properties": {
            "query": {
              "description": "AI Agent Orchestration: Serves as the initial tool for an AI agent to find relevant URLs for a query. The agent can then parse the JSON output, extract the links, and use a subsequent tool like Web_scrape to retrieve the full content of those pages. Automated Research: Programmatically identifying and collecting information on specific topics or keywords, providing a list of top-ranked sources without manual Browse. Content Discovery: Finding news articles, blogs, or websites related to a topic for content curation or monitoring. Link Analysis: Gathering a set of external links to analyze for authority, recency, relevance, or other metrics.",
              "type": "string"
            }
          },
          "required": [
            "query"
          ]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "Web_scraper",
        "description": "This tool can be used if the user wants to use text content of a given web page for analysis. Tools takes a web url (http or https). Will extract text from the page and return it for further analysis.",
        "input_schema": {
          "type": "object",
          "properties": {
            "weburl": {
              "description": "agent should ask web url (that includes http:// or https:// ). It will scrape text from the given url and return as a result.",
              "type": "string"
            }
          },
          "required": [
            "weburl"
          ]
        }
      }
    }
  ],
  "tool_resources": {
    "Query SEC Revenue Data": {
      "semantic_view": "SEC_FILES.DATA.SEC_REVENUE_SEMANTIC_VIEW"
    },
    "Search Investment Documents": {
      "id_column": "RELATIVE_PATH",
      "max_results": 5,
      "name": "SEC_FILES.DATA.CORP_MEM",
      "title_column": "RELATIVE_PATH"
    },
    "Search_Web": {
      "execution_environment": {
        "query_timeout": 0,
        "type": "warehouse",
        "warehouse": "COMPUTE_WH"
      },
      "identifier": "SNOWFLAKE_INTELLIGENCE.AGENTS.WEB_SEARCH",
      "name": "WEB_SEARCH(VARCHAR)",
      "type": "function"
    },
    "Web_scraper": {
      "execution_environment": {
        "query_timeout": 0,
        "type": "warehouse",
        "warehouse": "COMPUTE_WH"
      },
      "identifier": "SNOWFLAKE_INTELLIGENCE.AGENTS.WEB_SCRAPE",
      "name": "WEB_SCRAPE(VARCHAR)",
      "type": "function"
    }
  }
}
$$;

-- ========================================================================
-- Verification
-- ========================================================================
-- Verify the agent was created successfully
SHOW AGENTS IN SCHEMA snowflake_intelligence.agents;

-- Describe the agent to see its configuration
DESCRIBE AGENT snowflake_intelligence.agents.SNOWFLAKE_INVESTMENT_GURO;

-- Display success message
SELECT 'Agent "Snowflake Investment Guro" created successfully!' AS status;
SELECT 'You can now access the agent via the Snowflake Intelligence UI' AS next_step;
SELECT 'Navigate to AI & ML > Agents to interact with your investment analysis assistant' AS instructions;

-- ========================================================================
-- Agent Access Instructions
-- ========================================================================
-- To use the agent:
-- 1. Navigate to Snowflake UI > AI & ML > Agents
-- 2. Find "Snowflake Investment Guro" in the agents list
-- 3. Click to open the agent chat interface
-- 4. Try sample questions like:
--    - "What was Apple's revenue in Q2 2024?"
--    - "Compare Microsoft and Amazon's quarterly revenue trends"
--    - "Search for recent news about Tesla's earnings"
--
-- The agent will automatically:
-- - Query the SEC semantic view for structured revenue data
-- - Search uploaded documents for qualitative insights
-- - Use web search to find current news and information
-- - Scrape relevant web pages for detailed content
-- - Combine all sources to provide comprehensive investment analysis
-- ========================================================================

