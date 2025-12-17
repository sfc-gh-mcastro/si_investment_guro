# PAT Authentication for Snowflake MCP Server

## Overview

This guide explains how to use Programmatic Access Tokens (PAT) for authenticating with the Snowflake MCP server. PAT provides a simpler alternative to OAuth authentication, especially useful for:

- **Development and testing**
- **Automated scripts and CI/CD**
- **Clients without OAuth support** (e.g., Cursor IDE)
- **Accounts with MFA/WebAuthn** where OAuth flow is complex

## What is a PAT?

A Programmatic Access Token (PAT) is a long-lived credential that allows programmatic access to Snowflake resources. Unlike OAuth tokens:

- **Self-contained authentication** - No OAuth flow required
- **Long-lived** - Tokens don't expire automatically
- **Role-based** - Token assumes a specific Snowflake role
- **Revocable** - Can be manually revoked at any time

## PAT vs OAuth Comparison

| Feature | PAT | OAuth |
|---------|-----|-------|
| **Setup Complexity** | Simple | Complex (requires integration) |
| **MFA Compatibility** | ✅ Works seamlessly | ⚠️ Requires WebAuthn handling |
| **Expiration** | Manual revocation only | Automatic expiration |
| **Token Refresh** | ❌ No refresh | ✅ Refresh tokens available |
| **Security Model** | Bearer token | Authorization code flow |
| **Best For** | Development, testing, automation | Production, user-facing apps |
| **Client Support** | Works with all HTTP clients | Requires OAuth-capable client |

## When to Use PAT

**✅ Use PAT for:**
- Development and local testing
- Automated scripts and CI/CD pipelines
- Service-to-service authentication
- MCP clients without OAuth support
- Quick prototyping and POCs
- Accounts with MFA enabled

**❌ Avoid PAT for:**
- Production user-facing applications
- Scenarios requiring fine-grained access control
- Short-lived access requirements
- Applications where OAuth is supported

## Creating a PAT in Snowflake

### Step 1: Navigate to Security Settings

1. Log into Snowflake UI
2. Click on your **user profile** (top right corner)
3. Select **My Profile**
4. Navigate to the **Security** tab

### Step 2: Generate Token

1. Scroll to **Programmatic Access Tokens** section
2. Click **+ Token**
3. Configure the token:
   - **Name**: Give it a descriptive name (e.g., "MCP Server Testing")
   - **Lifetime**: Choose appropriate duration (30, 60, 90 days, or custom)
   - **Role**: Select the role for the token to assume (e.g., `ACCOUNTADMIN`, `PUBLIC`)
4. Click **Generate Token**

### Step 3: Save Token Securely

⚠️ **IMPORTANT**: The token will only be displayed once!

1. **Copy the token immediately**
2. **Store it securely** (password manager, environment variable, secrets vault)
3. **Never commit it to version control**
4. Click **Done** to confirm

### Step 4: Verify Token

Test your token with a simple SQL query:

```bash
# Using curl
curl -X POST "https://<account>.snowflakecomputing.com/api/v2/statements" \
  -H "Authorization: Bearer <your_pat_token>" \
  -H "Content-Type: application/json" \
  -d '{"statement":"SELECT CURRENT_USER(), CURRENT_ROLE()","timeout":60}'
```

## Using PAT with MCP Server

### Method 1: Environment Variable (Recommended)

Store your PAT in an environment variable:

```bash
# Add to ~/.zshrc or ~/.bashrc
export SNOWFLAKE_PAT="your_pat_token_here"

# Or for current session only
export SNOWFLAKE_PAT="your_pat_token_here"
```

Then use in your code:

```python
import os
import requests

PAT_TOKEN = os.getenv('SNOWFLAKE_PAT')
MCP_ENDPOINT = "https://<account>.snowflakecomputing.com/api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP"

response = requests.post(
    MCP_ENDPOINT,
    headers={
        'Authorization': f'Bearer {PAT_TOKEN}',
        'Content-Type': 'application/json'
    },
    json={
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {'protocolVersion': '2025-06-18'}
    }
)

print(response.json())
```

### Method 2: .env File

Create a `.env` file (make sure it's in `.gitignore`):

```bash
# .env
SNOWFLAKE_ACCOUNT=dcb76012
SNOWFLAKE_PAT=your_pat_token_here
```

Load with python-dotenv:

```python
from dotenv import load_dotenv
import os
import requests

load_dotenv()

PAT_TOKEN = os.getenv('SNOWFLAKE_PAT')
ACCOUNT = os.getenv('SNOWFLAKE_ACCOUNT')
MCP_ENDPOINT = f"https://{ACCOUNT}.snowflakecomputing.com/api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP"

# Use PAT for authentication
headers = {
    'Authorization': f'Bearer {PAT_TOKEN}',
    'Content-Type': 'application/json'
}
```

### Method 3: Secrets Manager (Production)

For production environments, use a secrets manager:

```python
import boto3  # AWS Secrets Manager example
import json
import requests

def get_pat_from_secrets_manager(secret_name):
    client = boto3.client('secretsmanager', region_name='us-east-1')
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response['SecretString'])['SNOWFLAKE_PAT']

PAT_TOKEN = get_pat_from_secrets_manager('snowflake/mcp/pat')

# Use PAT for MCP authentication
headers = {'Authorization': f'Bearer {PAT_TOKEN}'}
```

## Complete MCP Testing Example

Here's a complete example testing all MCP server tools with PAT:

```python
#!/usr/bin/env python3
"""
Test Snowflake MCP Server with PAT Authentication
"""
import os
import requests
import json

# Configuration
ACCOUNT_URL = os.getenv('SNOWFLAKE_ACCOUNT_URL', 'https://dcb76012.snowflakecomputing.com')
PAT_TOKEN = os.getenv('SNOWFLAKE_PAT')
MCP_ENDPOINT = f"{ACCOUNT_URL}/api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP"

if not PAT_TOKEN:
    print("❌ Error: SNOWFLAKE_PAT environment variable not set")
    exit(1)

def make_mcp_request(method, params=None):
    """Make an MCP request with PAT authentication"""
    response = requests.post(
        MCP_ENDPOINT,
        headers={
            'Authorization': f'Bearer {PAT_TOKEN}',
            'Content-Type': 'application/json'
        },
        json={
            'jsonrpc': '2.0',
            'id': 1,
            'method': method,
            'params': params or {}
        }
    )
    return response.json()

# Test 1: Initialize MCP server
print("Test 1: Initialize MCP Server")
result = make_mcp_request('initialize', {'protocolVersion': '2025-06-18'})
print(json.dumps(result, indent=2))

# Test 2: List tools
print("\nTest 2: List Available Tools")
result = make_mcp_request('tools/list')
print(json.dumps(result, indent=2))

# Test 3: Call Cortex Analyst
print("\nTest 3: Call Cortex Analyst Tool")
result = make_mcp_request('tools/call', {
    'name': 'revenue-semantic-view',
    'arguments': {
        'message': 'What companies are available in the database?'
    }
})
print(json.dumps(result, indent=2))

# Test 4: Call Cortex Search
print("\nTest 4: Call Cortex Search Tool")
result = make_mcp_request('tools/call', {
    'name': 'search-investment-docs',
    'arguments': {
        'query': 'revenue analysis',
        'limit': 3
    }
})
print(json.dumps(result, indent=2))

print("\n✅ All tests completed!")
```

## Security Best Practices

### Token Storage

✅ **DO:**
- Store PATs in environment variables or secrets managers
- Use `.env` files for local development (and add to `.gitignore`)
- Encrypt PATs at rest in production systems
- Use different PATs for different environments (dev/staging/prod)

❌ **DON'T:**
- Commit PATs to version control (Git, SVN, etc.)
- Share PATs via email, Slack, or messaging apps
- Store PATs in plain text files
- Use the same PAT across multiple applications
- Log PATs in application logs

### Token Lifecycle

1. **Create with minimal permissions**
   - Use least-privilege principle
   - Grant only necessary role access
   - Consider using dedicated service roles

2. **Rotate regularly**
   - Set calendar reminders for rotation
   - Rotate every 30-90 days
   - Rotate immediately if compromised

3. **Revoke when not needed**
   - Remove unused tokens
   - Revoke on team member departure
   - Audit active tokens monthly

4. **Monitor usage**
   - Track token usage in Snowflake query history
   - Set up alerts for suspicious activity
   - Review access logs regularly

### Role Selection

Choose the appropriate role for your PAT:

| Role | Use Case | Risk Level |
|------|----------|------------|
| `PUBLIC` | Read-only operations | Low |
| Custom Role | Specific tool access | Medium |
| `SYSADMIN` | Administrative tasks | High |
| `ACCOUNTADMIN` | Full admin access | ⚠️ Very High |

**Recommendation**: Create a dedicated role for MCP access:

```sql
USE ROLE ACCOUNTADMIN;

-- Create dedicated MCP role
CREATE ROLE MCP_ACCESS_ROLE;

-- Grant minimal required permissions
GRANT USAGE ON DATABASE sec_files TO ROLE MCP_ACCESS_ROLE;
GRANT USAGE ON SCHEMA sec_files.data TO ROLE MCP_ACCESS_ROLE;
GRANT USAGE ON MCP SERVER sec_files.data.SEC_INVESTMENT_MCP TO ROLE MCP_ACCESS_ROLE;
GRANT SELECT ON SEMANTIC VIEW sec_files.data.SEC_REVENUE_SEMANTIC_VIEW TO ROLE MCP_ACCESS_ROLE;
GRANT USAGE ON CORTEX SEARCH SERVICE sec_files.data.corp_mem TO ROLE MCP_ACCESS_ROLE;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE MCP_ACCESS_ROLE;

-- Grant role to user
GRANT ROLE MCP_ACCESS_ROLE TO USER <your_user>;

-- Use this role when creating the PAT
```

## Managing PATs

### Listing Active PATs

```sql
-- View all active tokens for your account
USE ROLE ACCOUNTADMIN;
SHOW TOKENS;

-- View tokens for specific user
SHOW TOKENS FOR USER <username>;
```

### Revoking PATs

Via Snowflake UI:
1. Navigate to **My Profile** → **Security**
2. Find the token in **Programmatic Access Tokens**
3. Click **Revoke**
4. Confirm revocation

Via SQL:
```sql
-- Revoke specific token
ALTER USER <username> REVOKE TOKEN '<token_id>';

-- Or via the token management interface in UI
```

### Monitoring PAT Usage

Track PAT usage in query history:

```sql
USE ROLE ACCOUNTADMIN;

-- View queries executed by PAT
SELECT 
    query_id,
    query_text,
    user_name,
    role_name,
    start_time,
    end_time,
    execution_status
FROM snowflake.account_usage.query_history
WHERE user_name = '<user_with_pat>'
    AND start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY start_time DESC;

-- Check for suspicious activity
SELECT 
    user_name,
    COUNT(*) as query_count,
    COUNT(DISTINCT role_name) as roles_used
FROM snowflake.account_usage.query_history
WHERE start_time >= DATEADD(day, -1, CURRENT_TIMESTAMP())
GROUP BY user_name
ORDER BY query_count DESC;
```

## Troubleshooting

### Error: "Invalid access token"

**Causes:**
- Token has been revoked
- Token expired (exceeded lifetime)
- Incorrect token copied

**Solutions:**
1. Verify token is correct (check for extra spaces)
2. Check token status in Snowflake UI
3. Generate new token if needed

### Error: "Insufficient privileges"

**Causes:**
- PAT's role lacks necessary permissions
- MCP server access not granted

**Solutions:**
```sql
-- Check current grants
SHOW GRANTS TO ROLE <your_role>;

-- Grant MCP server access
GRANT USAGE ON MCP SERVER sec_files.data.SEC_INVESTMENT_MCP TO ROLE <your_role>;

-- Grant underlying tool access
GRANT SELECT ON SEMANTIC VIEW sec_files.data.SEC_REVENUE_SEMANTIC_VIEW TO ROLE <your_role>;
GRANT USAGE ON CORTEX SEARCH SERVICE sec_files.data.corp_mem TO ROLE <your_role>;
```

### Error: "Network policy violation"

**Causes:**
- IP address not whitelisted in network policy

**Solutions:**
```sql
-- Check network policies
USE ROLE ACCOUNTADMIN;
SHOW NETWORK POLICIES;

-- Add your IP to allowed list (if you have permissions)
ALTER NETWORK POLICY <policy_name>
  SET ALLOWED_IP_LIST = ('<existing_ips>', '<your_ip>');
```

### Token Not Working Immediately

PATs can take a few seconds to become active after creation. Wait 10-30 seconds and try again.

## Example: Cursor IDE Configuration

Since Cursor IDE may not support OAuth, use PAT authentication:

1. **Create PAT** in Snowflake UI with appropriate role
2. **Store securely** in environment variable
3. **Configure Cursor** to use PAT (when MCP support is available)

Example configuration concept:

```json
{
  "mcp": {
    "servers": {
      "snowflake-investment": {
        "url": "https://<account>.snowflakecomputing.com/api/v2/databases/sec_files/schemas/data/mcp-servers/SEC_INVESTMENT_MCP",
        "auth": {
          "type": "bearer",
          "token": "${env:SNOWFLAKE_PAT}"
        }
      }
    }
  }
}
```

## Migration from OAuth to PAT

If you've already set up OAuth but want to switch to PAT:

1. **Keep OAuth integration** (for future use or other clients)
2. **Create PAT** following steps above
3. **Update test scripts** to use PAT instead of OAuth
4. **Document the change** for your team

Both authentication methods can coexist. The MCP server accepts either:
- `Authorization: Bearer <oauth_token>` (OAuth)
- `Authorization: Bearer <pat_token>` (PAT)

## Additional Resources

- [Snowflake PAT Documentation](https://docs.snowflake.com/en/user-guide/authentication-tokens)
- [MCP Server Setup Guide](MCP_SERVER_SETUP.md)
- [Security Best Practices](https://docs.snowflake.com/en/user-guide/security)
- [Test Script](../test/test_mcp_with_pat.py)

## Summary

PAT authentication provides a simpler alternative to OAuth for:
- ✅ Development and testing
- ✅ Automated workflows
- ✅ MCP clients without OAuth support
- ✅ Accounts with MFA enabled

**Remember:**
- Store PATs securely
- Rotate regularly
- Use least-privilege roles
- Monitor usage
- Revoke when not needed

For production user-facing applications, consider OAuth when clients have full support. For development, testing, and automation, PAT is often the better choice.

---

**Last Updated**: December 2024  
**Applies To**: Snowflake MCP Server v1.0

