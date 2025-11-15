# SEC Filing Investment Analysis Agent

A comprehensive Snowflake Intelligence solution for investment analysis using SEC filing data, powered by Cortex Analyst, Cortex Search, and web scraping capabilities.

Al credits to [Leif Engdell](mailto:leif.engdell@snowflake.com) which created the workshop instructions.

Latest update: 20251115

## Overview

This project provides a production-ready deployment of a Snowflake Intelligence agent that can:
- **Analyze SEC filing metrics** using natural language queries (Cortex Analyst with semantic views)
- **Search corporate documents** for context and policy information (Cortex Search)
- **Access web content** for real-time market intelligence (web scraping and search functions)
- **Answer investment questions** across structured and unstructured data sources

## Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│              Snowflake Investment Guro Agent (4 Tools)             │
│       (Automatically created via agent_scripts/create_agent.sql)   │
└──────┬────────────────┬─────────────────┬──────────────────────────┘
       │                │                 │               
       ▼                ▼                 ▼                
┌──────────────┐ ┌────────────┐ ┌──────────────────────┐
│   Cortex     │ │  Cortex    │ │   Web Functions      │
│   Analyst    │ │  Search    │ │  (scrape/search)     │
│ (Text2SQL)   │ │ (corp_mem) │ │                      │
└──────┬───────┘ └─────┬──────┘ └──────────┬───────────┘
       │               │                    │
       ▼               ▼                    ▼
┌──────────────┐ ┌────────────┐     ┌──────────────┐
│ Semantic View│ │  Document  │     │  External    │
│SEC_REVENUE_..│ │   Stage    │     │   Access     │
│              │ │@OPEN_PAPERS│     │ Integration  │
└──────┬───────┘ └─────┬──────┘     └──────────────┘
       │               │               
       ▼               ▼               
┌──────────────┐ ┌────────────┐      Optional 5th Tool (add via UI):
│Dynamic Table │ │    PDF     │      ┌──────────────────────────────┐
│SEC_METRICS_..│ │ Documents  │      │Company Event Transcripts     │
└──────┬───────┘ └────────────┘      │Earnings Calls & Presentations│
       │                              │(Cortex Knowledge Extensions) │
       ▼                              └──────────────────────────────┘
┌──────────────────────────────────┐
│  SNOWFLAKE_PUBLIC_DATA_PAID      │
│   SEC_METRICS_TIMESERIES         │
└──────────────────────────────────┘
```

## Prerequisites

### 1. Snowflake Account Requirements
- **Edition**: Business Critical or Enterprise (recommended)
- **Features**: Cortex Analyst, Cortex Search, Snowflake Intelligence enabled
- **Role**: ACCOUNTADMIN (for external access integration) or equivalent privileges
- **Warehouse**: `COMPUTE_WH` (or modify scripts to create/use different warehouse)

### 2. Data Marketplace Access

**Required**:
- **[Snowflake Public Data (Paid)](https://app.snowflake.com/marketplace/listing/GZTSZ290BUXPL/snowflake-public-data-products-snowflake-public-data-paid)**
  - Click "Get Data" and grant access to PUBLIC role
  - Provides `SNOWFLAKE_PUBLIC_DATA_PAID.PUBLIC_DATA.SEC_METRICS_TIMESERIES`
  - Source for quarterly revenue metrics

**Optional** (for 5th tool):
- **[Cortex Knowledge Extensions by Snowflake](https://app.snowflake.com/marketplace/listing/GZSTZ491VXY)**
  - Only needed if you want to add earnings call transcript search
  - See "Optional: Add Company Event Transcript Search" section below

### 3. Cross-Region Inference (Optional)
If your region doesn't have all Cortex models available, enable cross-region inference:

```sql
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
```

See: [Cortex Cross-Region Inference Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cross-region-inference)

### 4. Snow CLI Installation
Install and configure the Snowflake CLI:

```bash
# Install Snow CLI (see: https://docs.snowflake.com/en/developer-guide/snowflake-cli)
pip install snowflake-cli-labs

# Configure connection (already done: mcastro)
snow connection add

# Test connection
snow connection test -c mcastro
```

### 5. Security Approval
- **External Network Access**: Scripts create network rules for ports 80 and 443
- **Coordinate with security team** before deploying to production environments
- Web scraping and search functions can access external websites

## Quick Start

### Option 1: Automated Setup (Recommended)

Run the complete setup using Snow CLI:

```bash
# Navigate to project directory
cd /Users/mcastro/Documents/github/sfc-gh-mcastro/si_investment_guro

# Run complete setup using Snow CLI (creates infrastructure + agent)
snow sql -c mcastro -f sql_scripts/setup_all.sql
```

This will create the agent `SNOWFLAKE_INVESTMENT_GURO` with 4 core tools ready to use in **AI & ML > Agents**.

**Optional: Add Company Event Transcript Search (5th Tool)**

To add earnings call transcript search capabilities via Snowflake UI:

1. Install [Cortex Knowledge Extensions](https://app.snowflake.com/marketplace/listing/GZSTZ491VXY) from Marketplace
2. Navigate to **AI & ML** → **Agents** → **Snowflake Investment Guro** → **Edit**
3. Add a new **Cortex Search** tool:
   - Service: `SNOWFLAKE_PUBLIC_DATA_CORTEX_KNOWLEDGE_EXTENSIONS.AI.COMPANY_EVENT_TRANSCRIPT_CORTEX_SEARCH_SERVICE`
   - Name: "Search Company Event Transcripts"
   - Description: "Search earnings calls and investor presentations"
4. Save the agent

See [`docs/AGENT_SETUP.md`](docs/AGENT_SETUP.md) for detailed instructions.

### Option 2: Manual Step-by-Step Setup

Execute scripts individually in order:

```bash
# 1. Database and schema
snow sql -c mcastro -f sql_scripts/01_setup_database.sql

# 2. Dynamic table (SEC metrics)
snow sql -c mcastro -f sql_scripts/02_create_dynamic_table.sql

# 3. Semantic view (Cortex Analyst)
snow sql -c mcastro -f sql_scripts/03_create_semantic_view.sql

# 4. External access integration (requires ACCOUNTADMIN)
snow sql -c mcastro -f sql_scripts/04_create_external_access.sql

# 5. Web functions (scrape and search)
snow sql -c mcastro -f sql_scripts/05_create_web_functions.sql

# 6. Document stage and tables
snow sql -c mcastro -f sql_scripts/06_create_document_stage.sql

# 7. Cortex Search (after uploading documents - optional)
# snow sql -c mcastro -f sql_scripts/07_create_cortex_search.sql

# 8. Create Snowflake Intelligence Agent
snow sql -c mcastro -f agent_scripts/create_agent.sql
```


### Option 3: Execute via Snowflake UI

1. Open Snowflake UI and navigate to **Worksheets**
2. Create a new SQL worksheet
3. Copy contents of `sql_scripts/setup_all.sql`
4. Execute the script
5. Review results and verify object creation

## Post-Setup Configuration

### 1. Verify Semantic View (Optional)

The semantic view `SEC_REVENUE_SEMANTIC_VIEW` is created automatically by script 03. You can verify it in the Snowflake UI:

1. Navigate to: **Database Explorer** → `sec_files` → `data` → **Semantic Views**
2. Click on `SEC_REVENUE_SEMANTIC_VIEW` to view its configuration
3. Verify that dimensions and facts are properly defined:
   - **Dimensions**: `company_name`, `cik`, `fiscal_year`, `fiscal_period`, and other descriptive fields
   - **Facts**: `value` (the revenue amount)

The semantic view includes helpful descriptions and synonyms for better Cortex Analyst understanding.

### 2. Upload Documents (Optional)

To enable document search capabilities:

```sql
-- Via Snowflake UI:
-- 1. Navigate to: Database Explorer → sec_files → data → Stages → OPEN_PAPERS
-- 2. Click "+Files" and upload PDF documents

-- Via Snow CLI:
PUT file:///path/to/your/documents/*.pdf @sec_files.data.OPEN_PAPERS AUTO_COMPRESS=FALSE;
```

### 3. Process Documents (Optional - if PDFs uploaded)

After uploading PDFs, run the processing SQL (commented in `06_create_document_stage.sql`):

```sql
USE DATABASE sec_files;
USE SCHEMA data;
USE WAREHOUSE COMPUTE_WH;

-- Parse PDFs
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
FROM DIRECTORY('@OPEN_PAPERS');

-- Chunk for search
INSERT INTO DOCS_CHUNKS_TABLE (relative_path, size, file_url, presigned_url, chunk, chunk_index)
SELECT 
    relative_path, size, file_url, presigned_url,
    c.value::TEXT as chunk,
    c.INDEX::INTEGER as chunk_index
FROM RAW_TEXT,
LATERAL FLATTEN(
    input => SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER(
        EXTRACTED_LAYOUT, 'markdown', 1512, 200
    )
) c;
```

### 4. Create Cortex Search Service (Optional - if PDFs processed)

After processing documents:

```bash
snow sql -c mcastro -f sql_scripts/07_create_cortex_search.sql
```

### 5. Access Your Agent

The Snowflake Investment Guro agent is **automatically created** during setup. To use it:

1. Navigate to Snowflake UI → **AI & ML** → **Agents**
2. Find **"Snowflake Investment Guro"** in the agents list
3. Click to open and start asking questions

The agent comes pre-configured with **4 core tools**:
- ✅ **Cortex Analyst** - Query SEC Revenue Data (semantic view)
- ✅ **Cortex Search** - Search uploaded financial reports (corp_mem)
- ✅ **Web Search** - Find relevant web content (DuckDuckGo)
- ✅ **Web Scraper** - Extract content from web pages

**Optional 5th Tool** (add via UI):
- 🔧 **Search Company Event Transcripts** - Earnings calls & investor presentations

**Alternative**: For manual UI-based agent configuration, see [`docs/AGENT_SETUP.md`](docs/AGENT_SETUP.md)

## Verification

### Check Created Objects

```sql
USE DATABASE sec_files;
USE SCHEMA data;

-- Database and schema
SHOW DATABASES LIKE 'sec_files';
SHOW SCHEMAS IN DATABASE sec_files;

-- Dynamic table
SHOW DYNAMIC TABLES;
SELECT COUNT(*) FROM SEC_METRICS_DAILY;

-- Semantic view
SHOW SEMANTIC VIEWS;

-- External access
SHOW INTEGRATIONS LIKE '%ExternalAccess%';
SHOW NETWORK RULES;

-- Functions
SHOW FUNCTIONS LIKE 'Web_%' IN SCHEMA snowflake_intelligence.agents;

-- Stage and tables
SHOW STAGES;
SHOW TABLES LIKE '%CHUNKS%';

-- Cortex Search (if documents uploaded)
SHOW CORTEX SEARCH SERVICES;

-- Agent
SHOW AGENTS IN SCHEMA snowflake_intelligence.agents;
```

### Test Components

```sql
-- Test dynamic table data
SELECT company_name, fiscal_year, fiscal_period, value
FROM SEC_METRICS_DAILY
WHERE company_name ILIKE '%Apple%'
ORDER BY fiscal_year DESC, fiscal_period DESC
LIMIT 5;

-- Test web search function
SELECT Web_search('Snowflake quarterly earnings');

-- Test web scrape function
SELECT Web_scrape('https://www.snowflake.com/en/blog/');

-- Test semantic view
SELECT * FROM SEC_REVENUE_SEMANTIC_VIEW LIMIT 10;

-- Test Cortex Search (if documents uploaded)
SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'corp_mem',
    '{"query": "financial statements", "columns": ["chunk"], "limit": 3}'
);
```

## Project Structure

```
si_investment_guro/
├── README.md                              # This file
├── snowflake.yml                          # Snow CLI configuration
├── sql_scripts/                           # Infrastructure deployment scripts
│   ├── 01_setup_database.sql             # Database and schema
│   ├── 02_create_dynamic_table.sql       # SEC metrics dynamic table
│   ├── 03_create_semantic_view.sql       # Semantic view for Cortex Analyst
│   ├── 04_create_external_access.sql     # Network rules and integration
│   ├── 05_create_web_functions.sql       # Web scrape and search functions
│   ├── 06_create_document_stage.sql      # Document stage and tables
│   ├── 07_create_cortex_search.sql       # Cortex Search service
│   └── setup_all.sql                     # Master setup script (runs all + agent)
├── agent_scripts/                         # Agent deployment scripts
│   └── create_agent.sql                  # Snowflake Investment Guro agent creation
├── docs/
│   └── AGENT_SETUP.md                    # Agent configuration guide (manual/UI method)
├── Snowflake Intelligence Workshop.md     # Source workshop instructions
└── Snowflake_Intelligence_Workshop.pdf    # Workshop PDF
```

## Created Objects

| Object Type | Name | Location | Purpose |
|------------|------|----------|---------|
| Database | `sec_files` | - | Main database for SEC data |
| Schema | `data` | `sec_files` | Contains all tables and views |
| Dynamic Table | `SEC_METRICS_DAILY` | `sec_files.data` | Filtered SEC quarterly revenue data |
| Semantic View | `SEC_REVENUE_SEMANTIC_VIEW` | `sec_files.data` | Enables Cortex Analyst text-to-SQL |
| Network Rule | `Snowflake_intelligence_WebAccessRule` | `snowflake_intelligence.agents` | Allows ports 80/443 access |
| External Integration | `Snowflake_intelligence_ExternalAccess_Integration` | Account level | Enables web access for functions |
| Function | `Web_scrape(STRING)` | `snowflake_intelligence.agents` | Extracts text from web pages |
| Function | `Web_search(STRING)` | `snowflake_intelligence.agents` | Searches web via DuckDuckGo |
| Stage | `OPEN_PAPERS` | `sec_files.data` | Storage for PDF documents |
| Table | `RAW_TEXT` | `sec_files.data` | Temporary parsed PDF content |
| Table | `DOCS_CHUNKS_TABLE` | `sec_files.data` | Chunked text for search |
| Search Service | `corp_mem` | `sec_files.data` | Vector search over uploaded documents |
| Agent | `SNOWFLAKE_INVESTMENT_GURO` | `snowflake_intelligence.agents` | AI investment analysis agent (4 core tools) |

## Sample Agent Queries

The **Snowflake Investment Guro** agent is ready to use immediately after setup. Access it via **AI & ML > Agents** and try these queries:

### SEC Filing Analysis
```
"Show me the quarterly revenue trends for Apple over the last 3 years"

"Which companies had the highest revenue growth in Q4 2024?"

"Compare Microsoft and Amazon's quarterly revenues for 2024"

"What was Tesla's revenue in Q2 2024?"
```

### Document Search (if enabled)
```
"What does our financial policy say about expense reporting?"

"Find information about quarterly earnings requirements"

"Search our documents for revenue recognition policies"
```

### Web Intelligence
```
"Search the web for recent Snowflake earnings announcements"

"What's on the Snowflake blog about AI?"

"Scrape the latest from https://www.sec.gov/news/pressreleases"
```

### Combined Analysis
```
"Find Apple's Q3 2024 revenue from the SEC data, then search the web 
for their earnings announcement and summarize key highlights"

"What are the quarterly revenue trends for tech companies in our data, 
and what are analysts saying online about the sector?"

"Compare NVIDIA's revenue growth with recent news about AI chip demand"
```

### With Optional 5th Tool (Earnings Transcripts)
If you add the Company Event Transcript tool:
```
"Compare NVIDIA's quarterly revenue growth with what their CEO said about 
AI demand in recent earnings calls"

"Show Tesla's revenue trends and summarize management's commentary on 
profitability from their latest investor presentation"
```

## Troubleshooting

### Issue: Dynamic table has no data
**Solution**: Verify SNOWFLAKE_PUBLIC_DATA_PAID data share is installed and accessible.

```sql
SELECT COUNT(*) FROM SNOWFLAKE_PUBLIC_DATA_PAID.PUBLIC_DATA.SEC_METRICS_TIMESERIES;
```

### Issue: External access integration fails
**Solution**: Ensure you're using ACCOUNTADMIN role or have been granted necessary privileges.

### Issue: Web functions timeout or fail
**Solution**: Check network connectivity and firewall rules. Ensure ports 80/443 are accessible.

### Issue: Cortex Search service creation fails
**Solution**: Ensure DOCS_CHUNKS_TABLE has data. Upload and process documents first.

### Issue: Agent doesn't see semantic view
**Solution**: Verify semantic view is configured with proper dimensions/facts via UI.

## Security Considerations

1. **External Network Access**: Web functions can access any HTTP/HTTPS endpoint
2. **Data Shares**: SEC data comes from Snowflake Marketplace (trusted source)
3. **Role Privileges**: Use principle of least privilege; create custom roles if needed
4. **Document Content**: Only upload non-sensitive documents to OPEN_PAPERS stage
5. **Web Scraping**: Respect robots.txt and terms of service of websites

## Deployment to Production

For production deployments:

1. **Create dedicated roles** with minimal required privileges
2. **Use separate warehouses** for different workloads
3. **Enable monitoring** and alerts for function usage
4. **Review network rules** and restrict to specific domains if possible
5. **Implement access controls** on sensitive data
6. **Set up CI/CD pipeline** for automated deployments
7. **Document compliance** requirements and data lineage

## Resources

- [Snowflake Intelligence Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-intelligence)
- [Cortex Analyst Guide](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
- [Cortex Search Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search)
- [Snow CLI Documentation](https://docs.snowflake.com/en/developer-guide/snowflake-cli)
- [Semantic View Best Practices](https://docs.snowflake.com/en/user-guide/semantic-layer/best-practices)

## Support

For questions or issues:
- Review the workshop materials: `Snowflake Intelligence Workshop.md`
- Check Snowflake documentation links above
- Contact your Snowflake account team
- Open an issue in this repository

## License

This project is provided as-is for demonstration and educational purposes.

## Acknowledgments

Based on the Snowflake Intelligence Workshop for investment analysis using SEC filing data.
