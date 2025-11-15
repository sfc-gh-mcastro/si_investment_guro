# Snowflake Intelligence Agent Setup Guide

> **📌 IMPORTANT NOTE**: As of the latest version, the **Snowflake Investment Guro** agent is **automatically created** when you run the setup scripts. The agent is deployed via `agent_scripts/create_agent.sql` and is ready to use immediately in **AI & ML > Agents**.
> 
> **This guide is provided for reference only** - for manual/UI-based agent creation if needed, or to understand how the agent tools are configured.
>
> To use the pre-configured agent:
> 1. Run the setup: `snow sql -c mcastro -f sql_scripts/setup_all.sql`
> 2. Access the agent: Snowflake UI → **AI & ML** → **Agents** → **"Snowflake Investment Guro"**
> 3. Start asking investment analysis questions!

---

## Manual Agent Configuration (Optional)

This guide provides step-by-step instructions for **manually** creating and configuring a SEC Filing Investment Analysis agent via the Snowflake UI.

## Prerequisites

Before creating the agent, ensure you have completed all SQL setup scripts:
- ✅ Database and schema created
- ✅ Dynamic table `SEC_METRICS_DAILY` populated with data
- ✅ Semantic view `SEC_REVENUE_SEMANTIC_VIEW` created
- ✅ External access integration and web functions deployed
- ✅ (Optional) Document stage created and Cortex Search service `corp_mem` available

## Overview

The agent will be configured with multiple tools to provide comprehensive investment analysis:

1. **Cortex Analyst** - Text-to-SQL queries on SEC revenue data
2. **Cortex Search** - Document search (if PDFs uploaded)
3. **Web Search** - Find relevant web content
4. **Web Scrape** - Extract text from web pages

---

## Step 1: Navigate to Snowflake Intelligence

1. Open your Snowflake account in a web browser
2. In the left navigation menu, click on **AI & ML**
3. Select **Snowflake Intelligence** from the submenu

![Navigate to AI & ML > Snowflake Intelligence]

---

## Step 2: Create New Agent

1. Click the **+ Create Agent** button (top right)
2. In the creation dialog:
   - **Name**: `Investment Analysis Agent`
   - **Database**: `sec_files`
   - **Schema**: `data`
   - **Warehouse**: `COMPUTE_WH`
   - **Description**: (Optional) "SEC filing investment analysis with web intelligence capabilities"
3. Click **Create**

The agent is now created with a basic configuration. Next, you'll add tools.

---

## Step 3: Edit Agent Configuration

After creation, you'll need to add tools to your agent:

1. Click on your newly created agent
2. Click the **Edit** button (top right)
3. You'll see tabs: **General**, **Tools**, **Advanced**

---

## Step 4: Add Cortex Analyst Tool (Semantic View)

This tool enables natural language queries on SEC filing data.

### 4.1 Navigate to Tools Tab
1. Click on the **Tools** tab
2. Click **+ Add Tool**
3. Select **Cortex Analyst**

### 4.2 Configure Cortex Analyst
1. **Tool Name**: `Query SEC Revenue Data`
2. **Semantic View**: 
   - Click the dropdown
   - Navigate to: `sec_files` → `data` → `SEC_REVENUE_SEMANTIC_VIEW`
   - Select the semantic view
3. **Description**: Use Cortex to generate a description, or paste:

```
This tool provides access to SEC filing data for investment analysis. It contains quarterly revenue metrics from publicly traded companies. Use this tool to query revenue trends, compare companies, analyze growth patterns, and answer questions about company financial performance over time. The data includes company names (company_name), fiscal years, fiscal periods (Q1-Q4), and revenue values.
```

4. **When to use this tool**: (Recommended)

```
Use this tool when the user asks about:
- Company revenues, sales, or financial performance
- Quarterly or annual revenue trends
- Comparing revenue between companies
- Revenue growth rates or changes over time
- Financial metrics from SEC filings
- Historical financial data for public companies
```

5. Click **Save** or **Add Tool**

---

## Step 5: Add Cortex Search Tool (Optional - if documents uploaded)

This tool enables semantic search over uploaded documents.

### 5.1 Add Cortex Search
1. In the **Tools** tab, click **+ Add Tool**
2. Select **Cortex Search**

### 5.2 Configure Cortex Search
1. **Tool Name**: `Search Corporate Documents`
2. **Search Service**:
   - Click the dropdown
   - Navigate to: `sec_files` → `data` → `corp_mem`
   - Select the search service
3. **Description**:

```
This tool searches corporate documents, reports, and internal documentation for relevant information. It can find policy details, guidelines, procedures, and reference materials from uploaded PDF documents. Use this to provide context from corporate memory and documentation.
```

4. **When to use this tool**:

```
Use this tool when the user asks about:
- Company policies or procedures
- Document-based information or reference materials
- Guidelines, regulations, or compliance requirements
- Detailed explanations found in corporate documents
- Background information that may be in uploaded files
```

5. Click **Save** or **Add Tool**

---

## Step 6: Add Web Search Function Tool

This tool enables searching the web for current information.

### 6.1 Add Custom Function Tool
1. In the **Tools** tab, click **+ Add Tool**
2. Select **Function** (Custom Tool)

### 6.2 Configure Web Search Function
1. **Tool Type**: Function
2. **Function Location**:
   - Database: `snowflake_intelligence`
   - Schema: `agents`
   - Function: `Web_search`
3. **Tool Name**: `Search the Web`
4. **Description**:

```
This Python-based function acts as a web search tool, designed to find and return a structured list of search results for a given query. It performs an HTTP request to a specialized HTML endpoint of the DuckDuckGo search engine. The function automatically filters out sponsored advertisements and extracts the title, URL, and content snippet from the top three organic search results. The output is a machine-readable JSON string, making it an ideal first-step tool for an AI agent or any automated workflow.

The function is marked as VOLATILE because its results depend on external, unpredictable data. It requires external network access through the Snowflake_intelligence_ExternalAccess_Integration, and users should be mindful of permissions and adherence to search engine policies.
```

5. **Parameters Configuration**:
   - **Parameter Name**: `query`
   - **Data Type**: `STRING`
   - **Description**:

```
AI Agent Orchestration: Serves as the initial tool for an AI agent to find relevant URLs for a query. The agent can then parse the JSON output, extract the links, and use a subsequent tool like Web_scrape to retrieve the full content of those pages.
Automated Research: Programmatically identifying and collecting information on specific topics or keywords, providing a list of top-ranked sources without manual Browse.
Content Discovery: Finding news articles, blogs, or websites related to a topic for content curation or monitoring.
Link Analysis: Gathering a set of external links to analyze for authority, recency, relevance, or other metrics.
```

6. **When to use this tool**:

```
Use this tool when the user asks:
- For current information not in the database
- About recent news, announcements, or events
- To find web resources or articles on a topic
- For external validation or sources
- About topics requiring real-time information
```

7. Click **Save** or **Add Tool**

---

## Step 7: Add Web Scrape Function Tool

This tool extracts text content from web pages.

### 7.1 Add Custom Function Tool
1. In the **Tools** tab, click **+ Add Tool**
2. Select **Function** (Custom Tool)

### 7.2 Configure Web Scrape Function
1. **Tool Type**: Function
2. **Function Location**:
   - Database: `snowflake_intelligence`
   - Schema: `agents`
   - Function: `Web_scrape`
3. **Tool Name**: `Scrape Web Page`
4. **Description**:

```
This tool can be used if the user wants to use text content of a given web page for analysis. Tool takes a web url (http or https). Will extract text from the page and return it for further analysis.
```

5. **Parameters Configuration**:
   - **Parameter Name**: `weburl`
   - **Data Type**: `STRING`
   - **Description**:

```
Agent should ask web url (that includes http:// or https://). It will scrape text from the given url and return as a result.
```

6. **When to use this tool**:

```
Use this tool when:
- The user provides a specific URL to analyze
- After Web_search finds relevant URLs that need full content
- The user wants to extract information from a specific webpage
- Detailed content from a web article or blog post is needed
- The user asks to "read", "scrape", or "get content from" a URL
```

7. Click **Save** or **Add Tool**

---

## Step 8: Configure Agent Instructions (Optional)

Provide system-level instructions to guide the agent's behavior:

1. Go to the **Advanced** tab
2. In the **Instructions** field, add:

```
You are an investment analysis assistant specializing in SEC filing data and financial research. 

When analyzing company financial data:
- Always specify the time period being analyzed
- Provide context around trends (year-over-year growth, etc.)
- Compare metrics when relevant
- Cite data sources in your responses

When using web tools:
- Use Web_search first to find relevant URLs
- Then use Web_scrape to get detailed content from specific URLs
- Combine web intelligence with database insights when applicable

When a user asks about a company:
- Start with SEC filing data from the semantic view
- Supplement with document search if relevant policies exist
- Consider web search for recent news or announcements

Be concise but thorough. Provide numbers, trends, and actionable insights.
```

3. Click **Save**

---

## Step 9: Save and Test Agent

1. Click **Save** in the top right to save all configurations
2. Click **Test** or return to the agent's main page
3. Try sample queries (see below)

---

## Testing Your Agent

### Sample Test Queries

Try these queries to verify all tools are working:

#### Test Cortex Analyst (SEC Data)
```
"What was Apple's quarterly revenue in Q3 2024?"

"Show me the top 5 companies by revenue in the latest quarter"

"Compare Microsoft and Amazon's revenue trends over the last year"

"Which tech companies had revenue growth in Q2 2024?"
```

#### Test Document Search (if enabled)
```
"What does our financial policy say about expense reporting?"

"Search our documents for information about quarterly earnings"

"Find any documentation about revenue recognition"
```

#### Test Web Search
```
"Search the web for recent Snowflake earnings announcements"

"What are analysts saying about tech sector growth?"

"Find recent news about SEC filing changes"
```

#### Test Web Scrape
```
"Scrape the content from https://www.snowflake.com/en/blog/ and summarize the latest posts"

"Read this article: https://www.sec.gov/news/press-release/2024-1 and tell me what it says"
```

#### Test Combined Capabilities
```
"Find Tesla's Q4 2024 revenue from SEC data, then search the web for their 
earnings announcement and tell me if there are any notable highlights"

"What are the quarterly revenue trends for major tech companies in our data? 
Then search online to see what analysts are predicting for next quarter"

"Get Apple's recent revenue data, search for their latest earnings call, 
and scrape their investor relations page to give me a comprehensive update"
```

---

## Troubleshooting

### Agent doesn't see semantic view
**Solution**: 
- Verify semantic view exists: `SHOW SEMANTIC VIEWS IN sec_files.data;`
- Check that dimensions and facts are properly configured via UI
- Ensure agent has proper permissions on the database/schema

### Web functions not available in dropdown
**Solution**:
- Verify functions exist: `SHOW FUNCTIONS LIKE 'Web_%' IN snowflake_intelligence.agents;`
- Check that external access integration is enabled
- Ensure you have USAGE privileges on the functions

### Cortex Search not available
**Solution**:
- Verify search service exists: `SHOW CORTEX SEARCH SERVICES IN sec_files.data;`
- Ensure documents have been uploaded and processed
- Check that DOCS_CHUNKS_TABLE has data

### Agent responses are generic/unhelpful
**Solution**:
- Add more specific instructions in the Advanced tab
- Refine tool descriptions to guide when each tool should be used
- Add more detail to semantic view column descriptions
- Test queries one tool at a time to isolate issues

---

## Best Practices

### 1. Tool Descriptions
- Be specific about what each tool does
- Clearly describe when to use each tool
- Include example use cases

### 2. Agent Instructions
- Provide clear guidelines for analysis
- Specify formatting preferences
- Set expectations for citations and sources

### 3. Query Patterns
- Start with simple queries to test each tool
- Build up to complex multi-tool queries
- Test edge cases and error conditions

### 4. Monitoring
- Review agent conversation history regularly
- Note which queries work well and which don't
- Refine tool descriptions based on actual usage

### 5. Security
- Be cautious with web scraping - respect robots.txt
- Don't expose sensitive information in agent responses
- Monitor external web access usage

---

## Advanced Configuration

### Multiple Agents
Consider creating specialized agents for different use cases:
- **Financial Analyst Agent**: Focus on SEC data and financial metrics
- **Research Agent**: Emphasize web search and document retrieval
- **Compliance Agent**: Focus on policy documents and regulatory information

### Fine-tuning Semantic View
Improve query accuracy by:
- Adding synonyms for business terms
- Providing detailed column descriptions
- Creating calculated fields for common metrics
- Adding sample questions in the semantic view metadata

### Custom Functions
Extend capabilities by creating additional functions:
- Financial calculations (ratios, growth rates)
- Data validation and quality checks
- Integration with other external APIs
- Custom formatting for specific output types

---

## Next Steps

After setting up your agent:

1. **Share with team**: Grant access to users who need investment analysis
2. **Create documentation**: Document common queries and expected outputs
3. **Establish workflows**: Define standard operating procedures for analysis
4. **Monitor usage**: Track which features are most valuable
5. **Iterate**: Continuously improve tool descriptions and instructions based on feedback

---

## Resources

- [Snowflake Intelligence Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-intelligence)
- [Creating Agents Guide](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-intelligence#create-agent)
- [Cortex Analyst Best Practices](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst#best-practices)
- [Agent Tool Configuration](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-intelligence#add-tools)

---

## Support

If you encounter issues during agent setup:
1. Review the main [README.md](../README.md) for prerequisites
2. Check SQL verification queries to ensure all objects exist
3. Verify permissions on database, schema, and functions
4. Contact your Snowflake account team for assistance

---

**Congratulations!** Your Investment Analysis Agent is now configured and ready to use. Start asking questions about SEC filing data, search corporate documents, and leverage web intelligence for comprehensive investment analysis.

