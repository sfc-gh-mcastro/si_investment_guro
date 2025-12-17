# Security Notice - OAuth Credentials Exposure

## Issue

OAuth credentials (`CLIENT_ID` and `CLIENT_SECRET`) were accidentally committed to the repository in the following files:
- `test/test_oauth.py` 
- `test/test_oauth_2.py`

These files have been removed, but the credentials remain in git history.

## Required Action

⚠️ **You must rotate the OAuth credentials immediately** by recreating the OAuth integration.

### Steps to Rotate OAuth Credentials

```sql
USE ROLE ACCOUNTADMIN;

-- 1. Drop the old integration
DROP INTEGRATION IF EXISTS SEC_INVESTMENT_MCP_OAUTH;

-- 2. Create new integration with fresh credentials
CREATE OR REPLACE SECURITY INTEGRATION SEC_INVESTMENT_MCP_OAUTH
  TYPE = OAUTH
  OAUTH_CLIENT = CUSTOM
  ENABLED = TRUE
  OAUTH_CLIENT_TYPE = 'CONFIDENTIAL'
  OAUTH_REDIRECT_URI = 'http://localhost:3000/callback http://localhost:8080/callback http://127.0.0.1:3000/oauth/callback'
  OAUTH_ALLOW_NON_TLS_REDIRECT_URI = TRUE
  OAUTH_ISSUE_REFRESH_TOKENS = TRUE
  COMMENT = 'OAuth 2.0 integration for SEC Investment MCP server';

-- 3. Get new credentials (store securely!)
SELECT SYSTEM$SHOW_OAUTH_CLIENT_SECRETS('SEC_INVESTMENT_MCP_OAUTH');

-- 4. Grant permissions
GRANT USAGE ON INTEGRATION SEC_INVESTMENT_MCP_OAUTH TO ROLE PUBLIC;
GRANT USAGE ON INTEGRATION SEC_INVESTMENT_MCP_OAUTH TO ROLE ACCOUNTADMIN;
```

### Why This Matters

- Anyone with access to the git repository history can see the old credentials
- Old credentials could potentially be used to authenticate to your MCP server
- Rotating credentials ensures the exposed credentials are invalidated

### Prevention

The `.gitignore` has been updated to prevent this in the future:
```gitignore
# OAuth test files (contain hardcoded credentials)
test/test_oauth*.py
test/*oauth*.py
```

### Recommended Alternative

Use **PAT (Programmatic Access Token)** authentication instead of OAuth for development:
- No complex OAuth flow
- Works with MFA
- Easier to manage
- See `docs/PAT_AUTHENTICATION.md` for details

Or use the existing `test/test_mcp_with_pat.py` which uses environment variables instead of hardcoded credentials.

## Resolution Date

- **Issue Identified**: December 17, 2024
- **Files Removed**: December 17, 2024  
- **Credentials Rotated**: [PENDING - Action required]

## Security Best Practices

✅ **DO:**
- Use environment variables for credentials
- Use `.env` files (gitignored) for local development
- Store secrets in secrets managers (AWS Secrets Manager, Azure Key Vault, etc.)
- Regularly rotate credentials
- Review git commits before pushing

❌ **DON'T:**
- Hardcode credentials in source files
- Commit `.env` files to git
- Share credentials via email, Slack, or messaging
- Reuse credentials across environments

---

**This file can be deleted after OAuth credentials have been rotated.**

