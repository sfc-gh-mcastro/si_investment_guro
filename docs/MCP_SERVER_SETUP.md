# Snowflake MCP Server Setup Guide

## Overview

This guide provides comprehensive instructions for setting up and using the Snowflake-managed Model Context Protocol (MCP) server for the SEC Investment Analysis solution. The MCP server exposes your investment analysis tools through a standards-based interface, enabling AI agents like Claude Desktop, Cursor IDE, and custom applications to securely interact with your Snowflake data and analytics.

### What is MCP?

Model Context Protocol (MCP) is an open-source standard that lets AI agents securely interact with business applications and external data systems. MCP provides:

- **Standardized Integration**: Unified interface for tool discovery and invocation
- **Comprehensive Authentication**: OAuth 2.0 based secure authentication
- **Robust Governance**: Role-based access control (RBAC) for tools
- **Enterprise-Grade**: Managed infrastructure with no separate deployment needed

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        MCP Clients                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Claude       │  │ Cursor IDE   │  │ Custom Apps  │     │
│  │ Desktop      │  │              │  │              │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
└─────────┼──────────────────┼──────────────────┼────────────┘
          │                  │                  │
          │         OAuth 2.0 Authentication    │
          └──────────────────┼──────────────────┘
                             ▼
          ┌─────────────────────────────────────────┐
          │   Snowflake MCP Server                  │
          │   SEC_INVESTMENT_MCP                    │
          │                                         │
          │  ┌────────────────────────────────┐    │
          │  │  Exposed Tools:                │    │
          │  │  • Cortex Analyst (Revenue)    │    │
          │  │  • Cortex Search (Documents)   │    │
          │  │  • Cortex Agent (Full Stack)   │    │
          │  │  • SQL Execution (Direct)      │    │
          │  └────────────────────────────────┘    │
          └─────────────────────────────────────────┘
```

## Prerequisites

Before setting up the MCP server, ensure you have completed:

1. **Infrastructure Setup** (scripts 01-07):
   - Database `sec_files` and schema `data` created
   - Dynamic table `SEC_METRICS_DAILY` with SEC data
   - Semantic view `SEC_REVENUE_SEMANTIC_VIEW` for Cortex Analyst
   - Cortex Search service `corp_mem` for document search
   - External access integration and web functions

2. **Agent Creation**:
   - Snowflake Intelligence agent `SNOWFLAKE_INVESTMENT_GURO` created

3. **Permissions**:
   - `CREATE MCP SERVER` privilege on `sec_files.data` schema
   - `ACCOUNTADMIN` role (for OAuth integration creation)
   - `USAGE` privileges on all tools being exposed

4. **Client Requirements**:
   - Redirect URI for your MCP client application
   - Client application that supports MCP protocol (revision 2025-06-18)

## Installation Steps

### Step 1: Create the MCP Server

Run the MCP server creation script:

```bash
snow sql -f sql_scripts/08_create_mcp_server.sql
```

Or execute the SQL directly in Snowflake UI. This creates:

- **MCP Server**: `sec_files.data.SEC_INVESTMENT_MCP`
- **4 Exposed Tools**:
  1. `revenue-semantic-view` (Cortex Analyst)
  2. `search-investment-docs` (Cortex Search)
  3. `investment-guro-agent` (Cortex Agent)
  4. `sql-executor` (SQL Execution)

Verify the creation:

```sql
USE DATABASE sec_files;
USE SCHEMA data;

-- Show all MCP servers
SHOW MCP SERVERS IN SCHEMA sec_files.data;

-- Describe the server configuration
DESCRIBE MCP SERVER sec_files.data.SEC_INVESTMENT_MCP;
```

### Step 2: Configure OAuth Authentication

OAuth 2.0 authentication is the recommended secure method for MCP client connections.

#### 2.1 Determine Your Redirect URI

Based on your MCP client, identify the OAuth redirect URI:

| Client | Redirect URI Format | Example |
|--------|-------------------|---------|
| Claude Desktop | `http://127.0.0.1:PORT/oauth/callback` | `http://127.0.0.1:3000/oauth/callback` |
| Cursor IDE | `http://localhost:PORT/callback` | `http://localhost:8080/callback` |
| Custom App | Your app's callback endpoint | `https://myapp.com/oauth/callback` |

**Important**: Check your client's documentation for the exact redirect URI and port number.

#### 2.2 Update OAuth Script

Edit `sql_scripts/09_create_oauth_integration.sql` and update the `OAUTH_REDIRECT_URI`:

```sql
CREATE OR REPLACE SECURITY INTEGRATION SEC_INVESTMENT_MCP_OAUTH
  TYPE = OAUTH
  OAUTH_CLIENT = CUSTOM
  ENABLED = TRUE
  OAUTH_CLIENT_TYPE = 'CONFIDENTIAL'
  -- UPDATE THIS LINE with your actual redirect URI
  OAUTH_REDIRECT_URI = 'http://127.0.0.1:3000/oauth/callback'
  COMMENT = 'OAuth 2.0 integration for SEC Investment MCP server';
```

For multiple clients, use space-separated URIs:

```sql
OAUTH_REDIRECT_URI = 'http://127.0.0.1:3000/oauth/callback http://localhost:8080/callback'
```

#### 2.3 Create OAuth Integration

Run the OAuth integration script as ACCOUNTADMIN:

```bash
snow sql -f sql_scripts/09_create_oauth_integration.sql
```

#### 2.4 Retrieve Client Credentials

The script will output your OAuth credentials. Save them securely:

```sql
SELECT SYSTEM$SHOW_OAUTH_CLIENT_SECRETS('SEC_INVESTMENT_MCP_OAUTH');
```

Output will contain:
- `OAUTH_CLIENT_ID`: Your client ID
- `OAUTH_CLIENT_SECRET`: Your client secret (keep secure!)

**Security Note**: Never commit these credentials to version control or share them in plain text.

### Step 3: Grant Permissions

Ensure users/roles have appropriate permissions:

```sql
-- Grant MCP server usage
GRANT USAGE ON MCP SERVER sec_files.data.SEC_INVESTMENT_MCP TO ROLE <your_role>;

-- Grant tool-specific permissions
GRANT SELECT ON SEMANTIC VIEW sec_files.data.SEC_REVENUE_SEMANTIC_VIEW TO ROLE <your_role>;
GRANT USAGE ON CORTEX SEARCH SERVICE sec_files.data.corp_mem TO ROLE <your_role>;
GRANT USAGE ON AGENT snowflake_intelligence.agents.SNOWFLAKE_INVESTMENT_GURO TO ROLE <your_role>;

-- Grant database access for SQL execution
GRANT USAGE ON DATABASE sec_files TO ROLE <your_role>;
GRANT USAGE ON SCHEMA sec_files.data TO ROLE <your_role>;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE <your_role>;
```

## Client Configuration

### Claude Desktop

Add to your Claude Desktop configuration file (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "snowflake-investment": {
      "url": "https://<account_identifier>.snowflakecomputing.com/api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP",
      "auth": {
        "type": "oauth2",
        "client_id": "<your_client_id>",
        "client_secret": "<your_client_secret>",
        "authorization_endpoint": "https://<account_identifier>.snowflakecomputing.com/oauth/authorize",
        "token_endpoint": "https://<account_identifier>.snowflakecomputing.com/oauth/token-request",
        "redirect_uri": "http://127.0.0.1:3000/oauth/callback"
      }
    }
  }
}
```

Replace:
- `<account_identifier>`: Your Snowflake account identifier (e.g., `abc12345.us-east-1`)
- `<your_client_id>`: Client ID from Step 2.4
- `<your_client_secret>`: Client secret from Step 2.4

### Cursor IDE

Add to Cursor's MCP settings:

```json
{
  "mcp": {
    "servers": {
      "snowflake-investment": {
        "url": "https://<account_identifier>.snowflakecomputing.com/api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP",
        "auth": {
          "type": "oauth2",
          "clientId": "<your_client_id>",
          "clientSecret": "<your_client_secret>",
          "authorizationUrl": "https://<account_identifier>.snowflakecomputing.com/oauth/authorize",
          "tokenUrl": "https://<account_identifier>.snowflakecomputing.com/oauth/token-request",
          "redirectUri": "http://localhost:8080/callback"
        }
      }
    }
  }
}
```

### Custom MCP Client

For custom implementations, use the MCP SDK with OAuth 2.0 flow:

```python
from mcp import Client

client = Client(
    url="https://<account_identifier>.snowflakecomputing.com/api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP",
    auth={
        "type": "oauth2",
        "client_id": "<your_client_id>",
        "client_secret": "<your_client_secret>",
        "authorization_endpoint": "https://<account_identifier>.snowflakecomputing.com/oauth/authorize",
        "token_endpoint": "https://<account_identifier>.snowflakecomputing.com/oauth/token-request",
        "redirect_uri": "https://your-app.com/oauth/callback"
    }
)

# Initialize connection
await client.initialize(protocol_version="2025-06-18")

# List available tools
tools = await client.list_tools()

# Call a tool
result = await client.call_tool(
    name="revenue-semantic-view",
    arguments={"message": "What was Snowflake's revenue in Q1 2024?"}
)
```

## API Usage

### MCP Server Endpoint

```
POST https://<account>.snowflakecomputing.com/api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP
```

### Initialize Connection

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2025-06-18"
  }
}
```

Response:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "proto_version": "2025-06-18",
    "capabilities": {
      "tools": {
        "listChanged": false
      }
    },
    "server_info": {
      "name": "SEC_INVESTMENT_MCP",
      "title": "Snowflake Server: SEC_INVESTMENT_MCP",
      "version": "1.0.0"
    }
  }
}
```

### List Available Tools

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/list",
  "params": {}
}
```

Response includes all 4 tools with their input/output schemas.

### Invoke Tools

#### Tool 1: Cortex Analyst (Revenue Query)

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "revenue-semantic-view",
    "arguments": {
      "message": "What was Apple's quarterly revenue in 2024?"
    }
  }
}
```

#### Tool 2: Cortex Search (Document Search)

```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "tools/call",
  "params": {
    "name": "search-investment-docs",
    "arguments": {
      "query": "financial statements Q2 2024",
      "columns": ["chunk", "relative_path", "presigned_url"],
      "limit": 5
    }
  }
}
```

#### Tool 3: Cortex Agent (Full Orchestration)

```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "tools/call",
  "params": {
    "name": "investment-guro-agent",
    "arguments": {
      "message": "Compare Microsoft and Amazon revenue trends over the last year"
    }
  }
}
```

#### Tool 4: SQL Execution

```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "method": "tools/call",
  "params": {
    "name": "sql-executor",
    "arguments": {
      "query": "SELECT company_name, SUM(value) as total_revenue FROM sec_files.data.SEC_METRICS_DAILY WHERE fiscal_year = 2024 GROUP BY company_name ORDER BY total_revenue DESC LIMIT 10"
    }
  }
}
```

## Tool Descriptions

### 1. revenue-semantic-view (Cortex Analyst)

- **Type**: `CORTEX_ANALYST_MESSAGE`
- **Purpose**: Convert natural language questions to SQL queries on SEC revenue data
- **Input**: `message` (string) - Natural language question
- **Output**: Text response with SQL results
- **Use Cases**:
  - Company revenue queries
  - Fiscal year comparisons
  - Quarterly trend analysis
  - Year-over-year growth calculations

**Example Questions**:
- "What was Snowflake's total revenue in fiscal year 2024?"
- "Compare Apple and Microsoft quarterly revenue for 2024"
- "Show me NVIDIA's revenue growth over the last 4 quarters"

### 2. search-investment-docs (Cortex Search)

- **Type**: `CORTEX_SEARCH_SERVICE_QUERY`
- **Purpose**: Semantic search over uploaded financial documents
- **Input**: 
  - `query` (string) - Search query
  - `columns` (array, optional) - Columns to return
  - `limit` (integer, optional) - Max results (default: 10)
- **Output**: Array of matching document chunks with metadata
- **Use Cases**:
  - Find specific information in financial reports
  - Locate relevant sections in annual reports
  - Search SEC filings for particular topics
  - RAG-based document analysis

**Example Queries**:
- "revenue recognition policies"
- "risk factors related to competition"
- "management discussion Q2 2024"

### 3. investment-guro-agent (Cortex Agent)

- **Type**: `CORTEX_AGENT_RUN`
- **Purpose**: Full-featured investment analysis agent with tool orchestration
- **Input**: `message` (string) - Analysis request
- **Output**: Comprehensive analysis combining multiple data sources
- **Capabilities**:
  - Orchestrates Cortex Analyst, Cortex Search, Web Search, and Web Scraping
  - Combines quantitative and qualitative analysis
  - Generates visualizations
  - Provides cited sources

**Example Requests**:
- "Provide a comprehensive analysis of Tesla's recent performance"
- "Compare the top 5 tech companies by revenue and growth"
- "What are the key risks mentioned in Apple's latest 10-K?"

### 4. sql-executor (SQL Execution)

- **Type**: `SYSTEM_EXECUTE_SQL`
- **Purpose**: Execute arbitrary SQL queries
- **Input**: `query` (string) - SQL statement
- **Output**: Query results
- **Use Cases**:
  - Custom analytical queries
  - Complex joins across tables
  - Data exploration
  - Advanced calculations

**Security Note**: Ensure appropriate database and warehouse permissions are granted. SQL execution is limited by the user's role permissions.

## Security Best Practices

### OAuth Configuration

✅ **DO**:
- Use OAuth 2.0 for authentication (not hardcoded tokens)
- Store client secrets in environment variables or secure vaults
- Use HTTPS for redirect URIs in production
- Limit `OAUTH_ALLOWED_ROLES` to minimum required roles
- Regularly rotate client secrets
- Monitor OAuth token usage and failed attempts

❌ **DON'T**:
- Commit OAuth credentials to version control
- Share client secrets in plain text or email
- Use overly permissive roles (e.g., ACCOUNTADMIN) for MCP access
- Store credentials in client-side code

### MCP Server Configuration

✅ **DO**:
- Use hyphens (`-`) in tool names and hostnames (not underscores `_`)
- Grant minimum required privileges (least-privilege principle)
- Configure tool-specific permissions independently
- Verify third-party MCP servers before integration
- Monitor MCP server usage through Snowflake query history

❌ **DON'T**:
- Use underscores in hostnames (causes connection issues)
- Grant blanket permissions to all users
- Trust unverified third-party MCP servers
- Expose sensitive data without proper access controls

### Tool Poisoning Prevention

When integrating multiple MCP servers:

1. **Verify Tool Descriptions**: Ensure tool descriptions accurately represent functionality
2. **Validate Tool Sources**: Only use MCP servers from trusted sources
3. **Review Tool Conflicts**: Check for tool name collisions across servers
4. **Test Independently**: Validate each tool's behavior before production use

## Testing & Verification

### 1. Verify MCP Server Creation

```sql
-- Check server exists
SHOW MCP SERVERS IN SCHEMA sec_files.data;

-- View server details
DESCRIBE MCP SERVER sec_files.data.SEC_INVESTMENT_MCP;
```

### 2. Test OAuth Integration

```sql
-- Verify integration exists
SHOW INTEGRATIONS LIKE 'SEC_INVESTMENT_MCP_OAUTH';

-- Check configuration
DESCRIBE INTEGRATION SEC_INVESTMENT_MCP_OAUTH;
```

### 3. Test Tool Access

```bash
# Use curl or Postman to test API endpoints

# Initialize
curl -X POST "https://<account>.snowflakecomputing.com/api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP" \
  -H "Authorization: Bearer <oauth_token>" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}'

# List tools
curl -X POST "https://<account>.snowflakecomputing.com/api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP" \
  -H "Authorization: Bearer <oauth_token>" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
```

### 4. Test Each Tool

Test each tool individually to verify functionality:

```python
# Python test script example
import requests

# Analyst tool test
analyst_request = {
    "jsonrpc": "2.0",
    "id": 3,
    "method": "tools/call",
    "params": {
        "name": "revenue-semantic-view",
        "arguments": {"message": "What companies are in the database?"}
    }
}

response = requests.post(
    mcp_endpoint,
    headers={"Authorization": f"Bearer {oauth_token}"},
    json=analyst_request
)
print(response.json())
```

## Troubleshooting

### Issue: "Invalid redirect URI"

**Cause**: Redirect URI in client doesn't match OAuth integration configuration

**Solution**:
1. Check OAuth integration: `DESCRIBE INTEGRATION SEC_INVESTMENT_MCP_OAUTH;`
2. Verify client configuration matches exactly (including protocol and port)
3. Update integration if needed: `ALTER SECURITY INTEGRATION SEC_INVESTMENT_MCP_OAUTH SET OAUTH_REDIRECT_URI = '<correct_uri>';`

### Issue: "OAuth client not found"

**Cause**: Integration name not in uppercase or doesn't exist

**Solution**:
1. Use uppercase: `SYSTEM$SHOW_OAUTH_CLIENT_SECRETS('SEC_INVESTMENT_MCP_OAUTH')`
2. Verify integration exists: `SHOW INTEGRATIONS LIKE 'SEC_INVESTMENT_MCP_OAUTH';`

### Issue: "Connection refused" or "hostname error"

**Cause**: Using underscores in hostnames or tool names

**Solution**:
- Use hyphens (`-`) instead of underscores (`_`) in all names
- Check MCP server tool names follow this convention

### Issue: "Insufficient privileges"

**Cause**: Missing permissions on MCP server or underlying tools

**Solution**:
```sql
-- Grant MCP server access
GRANT USAGE ON MCP SERVER sec_files.data.SEC_INVESTMENT_MCP TO ROLE <role>;

-- Grant tool-specific permissions
GRANT SELECT ON SEMANTIC VIEW sec_files.data.SEC_REVENUE_SEMANTIC_VIEW TO ROLE <role>;
GRANT USAGE ON CORTEX SEARCH SERVICE sec_files.data.corp_mem TO ROLE <role>;
GRANT USAGE ON AGENT snowflake_intelligence.agents.SNOWFLAKE_INVESTMENT_GURO TO ROLE <role>;
```

### Issue: "Token expired"

**Cause**: OAuth access token has expired

**Solution**:
1. Implement token refresh flow in your client
2. Or increase token validity: `ALTER SECURITY INTEGRATION SEC_INVESTMENT_MCP_OAUTH SET OAUTH_REFRESH_TOKEN_VALIDITY = 7776000;`

### Issue: "Tool call failed"

**Cause**: Various - permissions, data issues, or tool configuration

**Solution**:
1. Test the underlying tool directly in Snowflake
2. Check Snowflake query history for error details
3. Verify all prerequisites are met for that specific tool
4. Review tool-specific permissions

## Maintenance

### Rotating OAuth Credentials

Regularly rotate OAuth credentials for security:

```sql
USE ROLE ACCOUNTADMIN;

-- Force regeneration of client secret
ALTER SECURITY INTEGRATION SEC_INVESTMENT_MCP_OAUTH
  SET OAUTH_CLIENT_RSA_PUBLIC_KEY = NULL;

-- Retrieve new credentials
SELECT SYSTEM$SHOW_OAUTH_CLIENT_SECRETS('SEC_INVESTMENT_MCP_OAUTH');
```

Update all client configurations with new credentials.

### Monitoring Usage

Monitor MCP server usage through Snowflake:

```sql
-- View recent queries from MCP server
SELECT 
    query_text,
    user_name,
    role_name,
    execution_status,
    start_time,
    end_time,
    total_elapsed_time
FROM snowflake.account_usage.query_history
WHERE query_text ILIKE '%SEC_INVESTMENT_MCP%'
ORDER BY start_time DESC
LIMIT 100;

-- Monitor OAuth token usage
SELECT 
    token_id,
    user_name,
    role_name,
    created_on,
    expires_on
FROM snowflake.account_usage.oauth_access_tokens
WHERE integration_name = 'SEC_INVESTMENT_MCP_OAUTH'
ORDER BY created_on DESC;
```

### Updating Tool Configuration

To modify tool configurations:

```sql
-- Update MCP server specification
CREATE OR REPLACE MCP SERVER sec_files.data.SEC_INVESTMENT_MCP
  FROM SPECIFICATION $$
    tools:
      # Update tool specifications here
  $$;
```

## Limitations

Current Snowflake MCP server limitations:

- ❌ Resources not supported
- ❌ Prompts not supported
- ❌ Roots not supported
- ❌ Notifications not supported
- ❌ Version negotiation not supported
- ❌ Lifecycle phases not supported
- ❌ Sampling not supported
- ❌ Streaming responses not supported (only non-streaming)
- ✅ Tools fully supported (tool discovery and invocation)

## Additional Resources

- [Snowflake MCP Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp)
- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- [Getting Started Quickstart](https://www.snowflake.com/en/developers/guides/getting-started-with-snowflake-mcp-server/)
- [Snowflake OAuth Documentation](https://docs.snowflake.com/en/sql-reference/sql/create-security-integration-oauth-snowflake)
- [Main README](../README.md)
- [Agent Setup Guide](AGENT_SETUP.md)

## Support

For issues or questions:

1. Check this troubleshooting guide
2. Review Snowflake query history for error details
3. Consult Snowflake MCP documentation
4. Contact Snowflake support for platform-specific issues

---

**Last Updated**: December 2024  
**MCP Protocol Version**: 2025-06-18  
**Snowflake Version**: Compatible with current Snowflake releases

