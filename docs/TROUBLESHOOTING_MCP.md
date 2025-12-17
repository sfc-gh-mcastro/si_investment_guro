# MCP Server Troubleshooting Guide

This document provides solutions to common issues when working with the Snowflake-managed MCP server.

---

## Error: "Semantic model failed validation - table does not exist or is not authorized"

### Symptom

When calling the `revenue-semantic-view` tool via MCP, you get:

```
Error occurred while calling Cortex Analyst: Semantic model failed validation with error: 
The following tables in the semantic model do not exist or are not authorized: [SEC_FILES.DATA.SEC_METRICS_DAILY]
```

### Root Cause

The semantic view `SEC_REVENUE_SEMANTIC_VIEW` references the dynamic table `SEC_METRICS_DAILY`, but the role being used to access the MCP server doesn't have SELECT permissions on that underlying table.

**Important**: Semantic views require SELECT permissions on ALL underlying tables, not just on the semantic view itself.

### Solution

Grant SELECT permissions on the underlying table to the role being used:

```sql
USE ROLE ACCOUNTADMIN;

-- If using your personal PAT (with PUBLIC or ACCOUNTADMIN role)
GRANT SELECT ON TABLE sec_files.data.SEC_METRICS_DAILY TO ROLE PUBLIC;
GRANT SELECT ON TABLE sec_files.data.SEC_METRICS_DAILY TO ROLE ACCOUNTADMIN;

-- If using MCP_ACCESS_ROLE (from script 10_setup_pat_user.sql)
GRANT SELECT ON TABLE sec_files.data.SEC_METRICS_DAILY TO ROLE MCP_ACCESS_ROLE;

-- Verify the grants were applied
SHOW GRANTS ON TABLE sec_files.data.SEC_METRICS_DAILY;
```

### Prevention

The setup scripts (`03_create_semantic_view.sql` and `10_setup_pat_user.sql`) now include these grants automatically. If you ran the scripts before this fix:

1. **Option A**: Re-run the semantic view script:
   ```bash
   snow sql -c mcastro -f sql_scripts/03_create_semantic_view.sql
   ```

2. **Option B**: Apply the grants manually (see Solution above)

---

## Error: "Invalid access token"

### Symptom

```
HTTP Error 401
Invalid access token
```

### Root Cause

- PAT token is expired
- PAT token was revoked
- PAT token is incorrect or has extra whitespace

### Solution

1. **Check if token is valid**:
   ```sql
   USE ROLE ACCOUNTADMIN;
   SHOW TOKENS FOR USER <your_username>;
   ```

2. **Create a new PAT**:
   - Snowflake UI → Profile → Security → Programmatic Access Tokens → + Token
   - Copy the token immediately (shown only once)
   - Update your environment variable: `export SNOWFLAKE_PAT="new_token_here"`

3. **Verify no extra whitespace**:
   ```bash
   echo "$SNOWFLAKE_PAT" | wc -c  # Should match expected token length
   ```

---

## Error: "Insufficient privileges"

### Symptom

```
Insufficient privileges to operate on MCP server
```

### Root Cause

The role associated with your PAT doesn't have the necessary permissions to:
- Access the MCP server
- Use the underlying tools (Cortex Analyst, Cortex Search, Agent, SQL execution)

### Solution

Verify and grant the required permissions:

```sql
USE ROLE ACCOUNTADMIN;

-- Check current grants
SHOW GRANTS TO ROLE <your_role>;

-- Grant MCP server access
GRANT USAGE ON DATABASE sec_files TO ROLE <your_role>;
GRANT USAGE ON SCHEMA sec_files.data TO ROLE <your_role>;
GRANT USAGE ON MCP SERVER sec_files.data.SEC_INVESTMENT_MCP TO ROLE <your_role>;

-- Grant tool access
GRANT SELECT ON SEMANTIC VIEW sec_files.data.SEC_REVENUE_SEMANTIC_VIEW TO ROLE <your_role>;
GRANT SELECT ON TABLE sec_files.data.SEC_METRICS_DAILY TO ROLE <your_role>;
GRANT USAGE ON CORTEX SEARCH SERVICE sec_files.data.corp_mem TO ROLE <your_role>;
GRANT USAGE ON AGENT snowflake_intelligence.agents.SNOWFLAKE_INVESTMENT_GURO TO ROLE <your_role>;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE <your_role>;
```

**Best Practice**: Use the `MCP_ACCESS_ROLE` created by `sql_scripts/10_setup_pat_user.sql` which has all necessary permissions configured.

---

## Error: "MCP server not found"

### Symptom

```
404 Not Found
MCP server 'SEC_INVESTMENT_MCP' does not exist
```

### Root Cause

The MCP server hasn't been created yet, or you don't have permissions to access it.

### Solution

1. **Check if server exists**:
   ```sql
   USE DATABASE sec_files;
   USE SCHEMA data;
   SHOW MCP SERVERS;
   ```

2. **Create the server** (if missing):
   ```bash
   snow sql -c mcastro -f sql_scripts/08_create_mcp_server.sql
   ```

3. **Grant access** (if you have insufficient privileges):
   ```sql
   USE ROLE ACCOUNTADMIN;
   GRANT USAGE ON MCP SERVER sec_files.data.SEC_INVESTMENT_MCP TO ROLE <your_role>;
   ```

---

## Error: "Cortex Search Service not found"

### Symptom

When calling the `search-investment-docs` tool:

```
Cortex Search Service 'corp_mem' does not exist or is not authorized
```

### Root Cause

The Cortex Search service hasn't been created, or you don't have permissions.

### Solution

1. **Check if service exists**:
   ```sql
   USE DATABASE sec_files;
   USE SCHEMA data;
   SHOW CORTEX SEARCH SERVICES;
   ```

2. **Create the service** (if missing):
   ```bash
   # Upload documents first
   snow sql -c mcastro -f sql_scripts/06_create_document_stage.sql
   
   # Create search service
   snow sql -c mcastro -f sql_scripts/07_create_cortex_search.sql
   ```

3. **Grant access** (if you have insufficient privileges):
   ```sql
   USE ROLE ACCOUNTADMIN;
   GRANT USAGE ON CORTEX SEARCH SERVICE sec_files.data.corp_mem TO ROLE <your_role>;
   ```

---

## Error: "Cortex Agent not found"

### Symptom

When calling the `investment-guro-agent` tool:

```
Agent 'SNOWFLAKE_INVESTMENT_GURO' does not exist or is not authorized
```

### Root Cause

The Snowflake Intelligence agent hasn't been created, or you don't have permissions.

### Solution

1. **Check if agent exists**:
   ```sql
   USE DATABASE snowflake_intelligence;
   USE SCHEMA agents;
   SHOW AGENTS;
   ```

2. **Create the agent** (if missing):
   ```bash
   snow sql -c mcastro -f agent_scripts/create_agent.sql
   ```

3. **Grant access** (if you have insufficient privileges):
   ```sql
   USE ROLE ACCOUNTADMIN;
   GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE <your_role>;
   GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE <your_role>;
   GRANT USAGE ON AGENT snowflake_intelligence.agents.SNOWFLAKE_INVESTMENT_GURO TO ROLE <your_role>;
   ```

---

## Performance Issues

### Symptom

MCP calls are slow or timing out.

### Solutions

1. **Check warehouse state**:
   ```sql
   SHOW WAREHOUSES LIKE 'COMPUTE_WH';
   ```
   
   Make sure the warehouse is running. Start it if suspended:
   ```sql
   ALTER WAREHOUSE COMPUTE_WH RESUME;
   ```

2. **Increase timeout in test script**:
   In `test/test_mcp_with_pat.py`, increase the timeout:
   ```python
   timeout=120  # Increase from 60 to 120 seconds
   ```

3. **Check dynamic table freshness**:
   ```sql
   SELECT SYSTEM$GET_DYNAMIC_TABLE_STALENESS('sec_files.data.SEC_METRICS_DAILY');
   ```
   
   Refresh if stale:
   ```sql
   ALTER DYNAMIC TABLE sec_files.data.SEC_METRICS_DAILY REFRESH;
   ```

---

## Debugging Tips

### 1. Check Current Role and Permissions

```sql
-- See what role you're using
SELECT CURRENT_ROLE();

-- See what permissions that role has
SHOW GRANTS TO ROLE <role_name>;
```

### 2. Test Each Tool Independently

Before using via MCP, test each tool directly:

**Cortex Analyst (Semantic View)**:
```sql
-- This won't work directly (semantic views can't be queried)
-- But you can check it exists and you have permissions
SHOW SEMANTIC VIEWS IN SCHEMA sec_files.data;
DESCRIBE SEMANTIC VIEW sec_files.data.SEC_REVENUE_SEMANTIC_VIEW;
```

**Cortex Search**:
```sql
-- Test search service directly
SELECT SNOWFLAKE.CORTEX.SEARCH(
  'sec_files.data.corp_mem',
  'revenue'
) AS search_results;
```

**Cortex Agent**:
```sql
-- Check agent exists and permissions
SHOW AGENTS IN SCHEMA snowflake_intelligence.agents;
```

**SQL Execution**:
```sql
-- Test basic query
SELECT COUNT(*) FROM sec_files.data.SEC_METRICS_DAILY;
```

### 3. Enable Verbose Logging

In `test/test_mcp_with_pat.py`, add debug output:

```python
import logging
logging.basicConfig(level=logging.DEBUG)

# Before each request, print
print(f"Request: {json.dumps(payload, indent=2)}")
print(f"Endpoint: {MCP_ENDPOINT}")
```

### 4. Check Account Usage Views

Monitor MCP usage and errors:

```sql
USE ROLE ACCOUNTADMIN;

-- Recent MCP-related queries
SELECT 
    query_id,
    query_text,
    user_name,
    role_name,
    error_code,
    error_message,
    start_time
FROM snowflake.account_usage.query_history
WHERE query_text ILIKE '%MCP%'
    AND start_time >= DATEADD(hour, -1, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 20;
```

---

## Getting Help

If you're still encountering issues after trying these solutions:

1. **Check Snowflake documentation**:
   - [MCP Server Docs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp)
   - [PAT Authentication](https://docs.snowflake.com/en/user-guide/authentication-tokens)

2. **Review project documentation**:
   - [`docs/MCP_SERVER_SETUP.md`](MCP_SERVER_SETUP.md) - Detailed setup guide
   - [`docs/PAT_AUTHENTICATION.md`](PAT_AUTHENTICATION.md) - PAT guide
   - [`README.md`](../README.md) - Project overview

3. **Check query history** for specific error messages:
   ```sql
   SELECT error_message, query_text 
   FROM snowflake.account_usage.query_history 
   WHERE user_name = CURRENT_USER()
     AND error_message IS NOT NULL
     AND start_time >= DATEADD(day, -1, CURRENT_TIMESTAMP())
   ORDER BY start_time DESC;
   ```

4. **Contact Snowflake Support** with:
   - Query ID (from error or query history)
   - Full error message
   - Steps to reproduce

---

## Quick Fixes Summary

| Error | Quick Fix |
|-------|-----------|
| "table not authorized" | `GRANT SELECT ON TABLE sec_files.data.SEC_METRICS_DAILY TO ROLE <role>;` |
| "Invalid access token" | Create new PAT in Snowflake UI |
| "Insufficient privileges" | Run `sql_scripts/10_setup_pat_user.sql` or grant permissions manually |
| "MCP server not found" | Run `sql_scripts/08_create_mcp_server.sql` |
| "Slow performance" | Resume warehouse: `ALTER WAREHOUSE COMPUTE_WH RESUME;` |
| "Agent not found" | Run `agent_scripts/create_agent.sql` |

---

**Last Updated**: December 17, 2024

