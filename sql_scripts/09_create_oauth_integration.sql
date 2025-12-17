-- ========================================================================
-- Investment Analysis Agent - OAuth Security Integration for MCP Server
-- ========================================================================
-- This script creates an OAuth 2.0 security integration for authenticating
-- MCP client connections to the SEC_INVESTMENT_MCP server.
--
-- Prerequisites:
--   - SEC_INVESTMENT_MCP server created (08_create_mcp_server.sql)
--   - ACCOUNTADMIN role (required for creating security integrations)
--   - Client application redirect URI(s) identified
--
-- Creates:
--   - Security Integration: SEC_INVESTMENT_MCP_OAUTH
--
-- Important Notes:
--   - The redirect URI must be configured BEFORE creating the integration
--   - You'll need to retrieve client ID and secret after creation
--   - This integration supports confidential OAuth clients only
--
-- Reference: https://docs.snowflake.com/en/sql-reference/sql/create-security-integration-oauth-snowflake
-- ========================================================================

-- OAuth integrations must be created by ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-- ========================================================================
-- STEP 1: Configure Your Redirect URI
-- ========================================================================
-- Before running this script, determine your OAuth redirect URI based on
-- your client application:
--
-- Common redirect URIs:
--   - Claude Desktop: 
--     'http://127.0.0.1:PORT/oauth/callback' (check Claude Desktop docs for port)
--   
--   - Cursor IDE:
--     'http://localhost:PORT/callback' (check Cursor MCP configuration)
--   
--   - Custom Application:
--     Your application's OAuth callback endpoint
--   
--   - Multiple clients (space-separated):
--     'http://localhost:3000/callback http://127.0.0.1:8080/oauth/callback'
--
-- IMPORTANT SECURITY NOTES:
--   - For local development (localhost/127.0.0.1), you must set 
--     OAUTH_ALLOW_NON_TLS_REDIRECT_URI = TRUE
--   - For production, use HTTPS redirect URIs and set
--     OAUTH_ALLOW_NON_TLS_REDIRECT_URI = FALSE (default)
--   - Never expose OAuth integrations with non-TLS redirect URIs in production
--
-- IMPORTANT: Replace the placeholder below with your actual redirect URI(s)
-- ========================================================================

-- ========================================================================
-- STEP 2: Create OAuth Security Integration
-- ========================================================================
-- This creates the OAuth 2.0 integration for MCP client authentication
--
-- IMPORTANT: You must update the OAUTH_REDIRECT_URI value below
-- 
-- For Cursor IDE: The redirect URI depends on Cursor's MCP implementation
-- Check Cursor settings or documentation for the exact URI
-- Common patterns: http://localhost:PORT/callback
--
-- For Claude Desktop: http://127.0.0.1:PORT/oauth/callback
-- (Check Claude Desktop MCP configuration for exact port)
-- ========================================================================

CREATE OR REPLACE SECURITY INTEGRATION SEC_INVESTMENT_MCP_OAUTH
  TYPE = OAUTH
  OAUTH_CLIENT = CUSTOM
  ENABLED = TRUE
  OAUTH_CLIENT_TYPE = 'CONFIDENTIAL'
  -- UPDATE THIS: Replace with your actual redirect URI(s)
  -- For multiple clients/URIs, use space-separated list
  -- Example: 'http://localhost:3000/callback http://127.0.0.1:8080/oauth/callback'
  OAUTH_REDIRECT_URI = 'http://localhost:3000/callback http://localhost:8080/callback http://127.0.0.1:3000/oauth/callback'
  -- Allow non-TLS redirect URIs for local development (localhost/127.0.0.1)
  -- Set to FALSE in production with HTTPS redirect URIs
  OAUTH_ALLOW_NON_TLS_REDIRECT_URI = TRUE
  -- Optional: Specify allowed roles (defaults to all roles user has access to)
  -- OAUTH_ALLOWED_ROLES = ('PUBLIC', 'ACCOUNTADMIN')
  -- Optional: Set token validity duration (default is 90 days)
  -- OAUTH_ISSUE_REFRESH_TOKENS = TRUE
  -- OAUTH_REFRESH_TOKEN_VALIDITY = 7776000  -- 90 days in seconds
  COMMENT = 'OAuth 2.0 integration for SEC Investment MCP server client authentication';

-- ========================================================================
-- STEP 3: Retrieve Client Credentials
-- ========================================================================
-- After creating the integration, retrieve the client ID and client secret
-- These credentials are needed to configure your MCP client application
--
-- IMPORTANT: The integration name MUST be in uppercase
-- ========================================================================

SELECT 'OAuth integration created successfully!' AS status;
SELECT 'Execute the following command to retrieve client credentials:' AS next_step;

-- Display the command to retrieve secrets
SELECT 'SELECT SYSTEM$SHOW_OAUTH_CLIENT_SECRETS(''SEC_INVESTMENT_MCP_OAUTH'');' AS retrieve_secrets_command;

-- Execute the command to get client ID and secret
-- IMPORTANT: Store these credentials securely
SELECT SYSTEM$SHOW_OAUTH_CLIENT_SECRETS('SEC_INVESTMENT_MCP_OAUTH') AS client_credentials;

-- ========================================================================
-- STEP 4: Grant OAuth Integration Usage
-- ========================================================================
-- Grant usage on the OAuth integration to roles that need to authenticate
-- via the MCP server

GRANT USAGE ON INTEGRATION SEC_INVESTMENT_MCP_OAUTH TO ROLE PUBLIC;
GRANT USAGE ON INTEGRATION SEC_INVESTMENT_MCP_OAUTH TO ROLE ACCOUNTADMIN;

-- ========================================================================
-- Verification
-- ========================================================================
-- Display the OAuth integration details
SHOW INTEGRATIONS LIKE 'SEC_INVESTMENT_MCP_OAUTH';

-- Describe the integration to verify configuration
DESCRIBE INTEGRATION SEC_INVESTMENT_MCP_OAUTH;

-- ========================================================================
-- Client Configuration Instructions
-- ========================================================================
SELECT 'OAuth Setup Complete!' AS status;
SELECT 'Next Steps:' AS instructions;

SELECT '1. Save the client_id and client_secret from the output above' AS step_1;
SELECT '2. Configure your MCP client with these OAuth credentials' AS step_2;
SELECT '3. Set the authorization endpoint to your Snowflake account URL' AS step_3;
SELECT '4. See docs/MCP_SERVER_SETUP.md for detailed client configuration examples' AS step_4;

-- ========================================================================
-- OAuth Configuration Reference
-- ========================================================================
/*
Client Configuration Parameters:
================================

1. Authorization Endpoint:
   https://<account_identifier>.snowflakecomputing.com/oauth/authorize

2. Token Endpoint:
   https://<account_identifier>.snowflakecomputing.com/oauth/token-request

3. Client ID:
   Retrieved from SYSTEM$SHOW_OAUTH_CLIENT_SECRETS() output above

4. Client Secret:
   Retrieved from SYSTEM$SHOW_OAUTH_CLIENT_SECRETS() output above

5. Redirect URI:
   Must match the OAUTH_REDIRECT_URI configured in the integration

6. Scope:
   Typically 'session:role:<role_name>' or default scope

Example OAuth Flow:
==================

1. Client redirects user to authorization endpoint with:
   - client_id
   - redirect_uri
   - response_type=code
   - scope (optional)

2. User authenticates with Snowflake credentials

3. Snowflake redirects to redirect_uri with authorization code

4. Client exchanges code for access token at token endpoint:
   - code
   - client_id
   - client_secret
   - redirect_uri
   - grant_type=authorization_code

5. Client uses access token for MCP API requests

Security Best Practices:
=======================

✓ Store client_id and client_secret securely (use environment variables or secrets manager)
✓ Use HTTPS for redirect URIs in production
✓ Set appropriate token validity periods
✓ Limit OAUTH_ALLOWED_ROLES to minimum required roles
✓ Regularly rotate client secrets
✓ Monitor OAuth token usage and failed authentication attempts
✗ Never commit credentials to version control
✗ Never share client secrets in plain text
✗ Avoid using overly permissive roles (like ACCOUNTADMIN) for MCP access

Troubleshooting:
===============

Issue: "Invalid redirect URI"
Solution: Ensure OAUTH_REDIRECT_URI in integration matches client configuration exactly

Issue: "OAuth client not found"
Solution: Integration name must be uppercase in SYSTEM$SHOW_OAUTH_CLIENT_SECRETS()

Issue: "Insufficient privileges"
Solution: Ensure ACCOUNTADMIN role is used to create/modify security integrations

Issue: "Token expired"
Solution: Implement token refresh flow or increase OAUTH_REFRESH_TOKEN_VALIDITY

For more detailed troubleshooting, see docs/MCP_SERVER_SETUP.md
*/

-- ========================================================================
-- Updating the OAuth Integration
-- ========================================================================
/*
To update the integration (e.g., change redirect URI or rotate secrets):

1. Update redirect URI:
   ALTER SECURITY INTEGRATION SEC_INVESTMENT_MCP_OAUTH
     SET OAUTH_REDIRECT_URI = 'http://new-uri.example.com/callback';

2. Regenerate client secret:
   ALTER SECURITY INTEGRATION SEC_INVESTMENT_MCP_OAUTH
     SET OAUTH_CLIENT_RSA_PUBLIC_KEY = NULL;  -- Forces secret regeneration
   
   Then retrieve new credentials:
   SELECT SYSTEM$SHOW_OAUTH_CLIENT_SECRETS('SEC_INVESTMENT_MCP_OAUTH');

3. Disable/Enable integration:
   ALTER SECURITY INTEGRATION SEC_INVESTMENT_MCP_OAUTH SET ENABLED = FALSE;
   ALTER SECURITY INTEGRATION SEC_INVESTMENT_MCP_OAUTH SET ENABLED = TRUE;

4. View current configuration:
   DESCRIBE INTEGRATION SEC_INVESTMENT_MCP_OAUTH;
*/

-- ========================================================================
-- Clean Up (Optional)
-- ========================================================================
/*
To remove the OAuth integration:

USE ROLE ACCOUNTADMIN;
DROP INTEGRATION IF EXISTS SEC_INVESTMENT_MCP_OAUTH;

WARNING: This will invalidate all existing OAuth tokens and client credentials.
Clients will need to re-authenticate after recreation.
*/

-- ========================================================================
-- Multiple Client Support
-- ========================================================================
/*
To support multiple client applications with different redirect URIs:

Option 1: Multiple redirect URIs in single integration (space-separated)
---------------------------------------------------------------------------
CREATE OR REPLACE SECURITY INTEGRATION SEC_INVESTMENT_MCP_OAUTH
  TYPE = OAUTH
  OAUTH_CLIENT = CUSTOM
  ENABLED = TRUE
  OAUTH_CLIENT_TYPE = 'CONFIDENTIAL'
  OAUTH_REDIRECT_URI = 'http://localhost:3000/callback http://localhost:8080/callback'
  COMMENT = 'OAuth integration supporting multiple clients';

Option 2: Separate integrations per client (recommended for production)
------------------------------------------------------------------------
-- Client 1: Claude Desktop
CREATE SECURITY INTEGRATION SEC_INVESTMENT_MCP_CLAUDE_OAUTH
  TYPE = OAUTH
  OAUTH_CLIENT = CUSTOM
  ENABLED = TRUE
  OAUTH_CLIENT_TYPE = 'CONFIDENTIAL'
  OAUTH_REDIRECT_URI = 'http://127.0.0.1:3000/oauth/callback'
  COMMENT = 'OAuth for Claude Desktop MCP client';

-- Client 2: Cursor IDE
CREATE SECURITY INTEGRATION SEC_INVESTMENT_MCP_CURSOR_OAUTH
  TYPE = OAUTH
  OAUTH_CLIENT = CUSTOM
  ENABLED = TRUE
  OAUTH_CLIENT_TYPE = 'CONFIDENTIAL'
  OAUTH_REDIRECT_URI = 'http://localhost:8080/callback'
  COMMENT = 'OAuth for Cursor IDE MCP client';

Separate integrations provide:
- Better audit trails (track which client is being used)
- Independent credential rotation
- Client-specific permission management
- Easier troubleshooting and monitoring
*/

