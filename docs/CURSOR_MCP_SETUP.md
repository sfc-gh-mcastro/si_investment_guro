# Using Snowflake MCP Server in Cursor IDE

This guide shows you how to configure Cursor IDE to access your Snowflake MCP server using PAT authentication.

---

## Prerequisites

1. **PAT Token Created**: You must have a Snowflake PAT token
   - Create in Snowflake UI: Profile → Security → Programmatic Access Tokens → + Token
   - Copy the token immediately (shown only once)

2. **MCP Server Created**: The `SEC_INVESTMENT_MCP` server must exist
   ```bash
   snow sql -c mcastro -f sql_scripts/08_create_mcp_server.sql
   ```

3. **Permissions Granted**: Your role needs access to the MCP server and tools
   ```bash
   snow sql -c mcastro -f sql_scripts/03_create_semantic_view.sql
   ```

---

## Step 1: Create MCP Configuration File

Cursor reads MCP server configurations from `~/.cursor/mcp.json` (or project-specific location).

### Option A: Global Configuration (Recommended)

Create or edit `~/.cursor/mcp.json`:

```bash
# Create the directory if it doesn't exist
mkdir -p ~/.cursor

# Create the MCP configuration file
cat > ~/.cursor/mcp.json << 'EOF'
{
  "mcpServers": {
    "snowflake-investment-guro": {
      "url": "https://dcb76012.snowflakecomputing.com/api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP",
      "headers": {
        "Authorization": "Bearer YOUR_PAT_TOKEN_HERE",
        "Content-Type": "application/json"
      }
    }
  }
}
EOF
```

**⚠️ Important**: Replace `YOUR_PAT_TOKEN_HERE` with your actual PAT token.

**⚠️ Security Note**: This stores your PAT in plain text. See "Step 2" for a more secure approach.

### Option B: Project-Specific Configuration

Create `.cursor/mcp.json` in your project root:

```bash
# In your project directory
mkdir -p .cursor
cat > .cursor/mcp.json << 'EOF'
{
  "mcpServers": {
    "snowflake-investment-guro": {
      "url": "https://dcb76012.snowflakecomputing.com/api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP",
      "headers": {
        "Authorization": "Bearer YOUR_PAT_TOKEN_HERE",
        "Content-Type": "application/json"
      }
    }
  }
}
EOF

# Add to .gitignore to prevent committing credentials
echo ".cursor/mcp.json" >> .gitignore
```

---

## Step 2: Secure PAT Storage (Recommended)

Instead of hardcoding the PAT, use environment variables or a wrapper script.

### Method 1: Environment Variable Reference

Some MCP implementations support environment variable substitution:

```json
{
  "mcpServers": {
    "snowflake-investment-guro": {
      "url": "https://dcb76012.snowflakecomputing.com/api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP",
      "headers": {
        "Authorization": "Bearer ${SNOWFLAKE_PAT}",
        "Content-Type": "application/json"
      }
    }
  }
}
```

Then set the environment variable:
```bash
# Add to ~/.zshrc or ~/.bashrc
export SNOWFLAKE_PAT="your_pat_token_here"

# Reload shell configuration
source ~/.zshrc
```

### Method 2: MCP Proxy Script

Create a wrapper script that handles authentication:

```bash
# Create script: ~/.cursor/snowflake-mcp-proxy.sh
cat > ~/.cursor/snowflake-mcp-proxy.sh << 'EOF'
#!/bin/bash
# Snowflake MCP Proxy - Handles PAT authentication

# Read PAT from environment or secure storage
if [ -z "$SNOWFLAKE_PAT" ]; then
    echo "Error: SNOWFLAKE_PAT environment variable not set" >&2
    exit 1
fi

# Forward requests to Snowflake MCP server with authentication
curl -X POST \
  "https://dcb76012.snowflakecomputing.com/api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP" \
  -H "Authorization: Bearer $SNOWFLAKE_PAT" \
  -H "Content-Type: application/json" \
  -d @-
EOF

chmod +x ~/.cursor/snowflake-mcp-proxy.sh
```

Then configure Cursor to use the proxy:
```json
{
  "mcpServers": {
    "snowflake-investment-guro": {
      "command": "~/.cursor/snowflake-mcp-proxy.sh"
    }
  }
}
```

---

## Step 3: Customize for Your Snowflake Account

Update the configuration with your specific account details:

```json
{
  "mcpServers": {
    "snowflake-investment-guro": {
      "url": "https://YOUR_ACCOUNT.snowflakecomputing.com/api/v2/databases/YOUR_DATABASE/schemas/YOUR_SCHEMA/mcp-servers/YOUR_MCP_SERVER",
      "headers": {
        "Authorization": "Bearer YOUR_PAT_TOKEN",
        "Content-Type": "application/json"
      }
    }
  }
}
```

**Replace**:
- `YOUR_ACCOUNT` → Your Snowflake account identifier (e.g., `dcb76012`)
- `YOUR_DATABASE` → Database name (default: `sec_files`)
- `YOUR_SCHEMA` → Schema name (default: `data`)
- `YOUR_MCP_SERVER` → MCP server name (default: `SEC_INVESTMENT_MCP`)
- `YOUR_PAT_TOKEN` → Your actual PAT token

---

## Step 4: Restart Cursor IDE

After creating the configuration file:

1. **Close Cursor completely** (Cmd+Q on Mac, or close all windows)
2. **Reopen Cursor**
3. The MCP server should now be available

---

## Step 5: Test the MCP Server in Cursor

### Test 1: Check MCP Server Connection

In Cursor's AI chat:

```
@snowflake-investment-guro list available tools
```

You should see 4 tools:
1. `revenue-semantic-view` - Query SEC Revenue Data
2. `search-investment-docs` - Search Investment Documents
3. `investment-guro-agent` - Investment Guro Agent
4. `sql-executor` - SQL Execution Tool

### Test 2: Query SEC Revenue Data

```
@snowflake-investment-guro use the revenue-semantic-view tool to find what companies are available in the database
```

### Test 3: Search Documents

```
@snowflake-investment-guro search investment documents for "revenue growth"
```

### Test 4: Execute SQL Query

```
@snowflake-investment-guro execute SQL: SELECT COUNT(*) FROM sec_files.data.SEC_METRICS_DAILY
```

### Test 5: Use the Full Agent

```
@snowflake-investment-guro use the investment-guro-agent to analyze Snowflake's revenue trends
```

---

## Troubleshooting

### Error: "MCP server not found"

**Cause**: Configuration file not loaded or incorrect path.

**Solutions**:
1. Verify file location: `ls -la ~/.cursor/mcp.json`
2. Check file syntax: `cat ~/.cursor/mcp.json | jq .`
3. Restart Cursor completely

### Error: "Authentication failed"

**Cause**: Invalid or expired PAT token.

**Solutions**:
1. Verify token is correct (no extra spaces)
2. Check token hasn't expired:
   ```sql
   SHOW TOKENS FOR USER <your_username>;
   ```
3. Create new PAT if needed (Snowflake UI → Profile → Security → + Token)

### Error: "Insufficient privileges"

**Cause**: Role doesn't have required permissions.

**Solutions**:
```sql
USE ROLE ACCOUNTADMIN;

-- Grant permissions
GRANT SELECT ON TABLE sec_files.data.SEC_METRICS_DAILY TO ROLE PUBLIC;
GRANT USAGE ON MCP SERVER sec_files.data.SEC_INVESTMENT_MCP TO ROLE PUBLIC;
```

### MCP Server Not Appearing in Cursor

**Possible causes**:
1. Configuration file has JSON syntax errors
2. File is in wrong location
3. Cursor needs restart

**Debug steps**:
```bash
# Validate JSON syntax
cat ~/.cursor/mcp.json | jq .

# Check file permissions
ls -la ~/.cursor/mcp.json

# Check Cursor logs (if available)
tail -f ~/Library/Logs/Cursor/main.log  # Mac
```

---

## Alternative: Using MCP via Command Line (For Testing)

If Cursor IDE integration isn't working, you can test the MCP server directly:

```bash
# Set your PAT
export SNOWFLAKE_PAT="your_token_here"

# Test with the Python script
python test/test_mcp_with_pat.py

# Or use curl directly
curl -X POST \
  "https://dcb76012.snowflakecomputing.com/api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP" \
  -H "Authorization: Bearer $SNOWFLAKE_PAT" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list",
    "params": {}
  }'
```

---

## Security Best Practices

### ✅ DO:
- Use environment variables for PAT tokens
- Store PAT in system keychain (macOS Keychain, Windows Credential Manager)
- Rotate PAT tokens every 30-90 days
- Use `.gitignore` for project-specific MCP configs
- Use separate PATs for different environments

### ❌ DON'T:
- Commit MCP config files with tokens to Git
- Share PAT tokens via email or messaging
- Use same PAT across multiple machines
- Store PAT in plain text files
- Use ACCOUNTADMIN role for PAT (too privileged)

---

## Advanced Configuration

### Multiple MCP Servers

You can configure multiple MCP servers in Cursor:

```json
{
  "mcpServers": {
    "snowflake-investment-guro": {
      "url": "https://dcb76012.snowflakecomputing.com/api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP",
      "headers": {
        "Authorization": "Bearer ${SNOWFLAKE_PAT}",
        "Content-Type": "application/json"
      }
    },
    "snowflake-production": {
      "url": "https://prod-account.snowflakecomputing.com/api/v2/databases/prod_db/schemas/data/mcp-servers/PROD_MCP",
      "headers": {
        "Authorization": "Bearer ${SNOWFLAKE_PAT_PROD}",
        "Content-Type": "application/json"
      }
    }
  }
}
```

### Custom Timeouts

```json
{
  "mcpServers": {
    "snowflake-investment-guro": {
      "url": "https://dcb76012.snowflakecomputing.com/api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP",
      "headers": {
        "Authorization": "Bearer ${SNOWFLAKE_PAT}",
        "Content-Type": "application/json"
      },
      "timeout": 120000
    }
  }
}
```

---

## Next Steps

Once the MCP server is working in Cursor:

1. **Explore the tools**: Try different queries with each tool
2. **Build applications**: Use the MCP server in your code
3. **Monitor usage**: Check query history in Snowflake
4. **Optimize**: Adjust timeouts and configurations as needed

---

## Resources

- [Cursor MCP Documentation](https://docs.cursor.com/mcp) (if available)
- [Model Context Protocol Spec](https://modelcontextprotocol.io/)
- [Snowflake MCP Docs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp)
- [PAT Authentication Guide](PAT_AUTHENTICATION.md)
- [MCP Troubleshooting Guide](TROUBLESHOOTING_MCP.md)

---

**Last Updated**: December 17, 2024


