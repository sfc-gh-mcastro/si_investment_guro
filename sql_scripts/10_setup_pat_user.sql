-- ========================================================================
-- Investment Analysis Agent - PAT Service Account Setup
-- ========================================================================
-- This script creates a dedicated service account for PAT (Programmatic
-- Access Token) based MCP server access.
--
-- Purpose:
--   - Create a service user specifically for MCP access
--   - Grant minimal required permissions (least-privilege principle)
--   - Provide instructions for PAT creation
--   - Isolate MCP access from personal user accounts
--
-- Prerequisites:
--   - SEC_INVESTMENT_MCP server created (08_create_mcp_server.sql)
--   - ACCOUNTADMIN role (for user and role creation)
--   - All underlying MCP tools created and accessible
--
-- Reference: https://docs.snowflake.com/en/user-guide/authentication-tokens
-- ========================================================================

-- Must be run as ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-- ========================================================================
-- STEP 1: Create Dedicated Role for MCP Access
-- ========================================================================
-- Create a custom role with minimal permissions needed for MCP server usage

CREATE ROLE IF NOT EXISTS MCP_ACCESS_ROLE
    COMMENT = 'Role for programmatic MCP server access with minimal privileges';

-- ========================================================================
-- STEP 2: Grant Permissions to MCP Role
-- ========================================================================
-- Grant only the permissions needed for MCP server and its tools

-- MCP Server access
GRANT USAGE ON DATABASE sec_files TO ROLE MCP_ACCESS_ROLE;
GRANT USAGE ON SCHEMA sec_files.data TO ROLE MCP_ACCESS_ROLE;
GRANT USAGE ON MCP SERVER sec_files.data.SEC_INVESTMENT_MCP TO ROLE MCP_ACCESS_ROLE;

-- Tool 1: Cortex Analyst (Semantic View access)
GRANT SELECT ON SEMANTIC VIEW sec_files.data.SEC_REVENUE_SEMANTIC_VIEW TO ROLE MCP_ACCESS_ROLE;

-- Tool 2: Cortex Search (Search Service access)
GRANT USAGE ON CORTEX SEARCH SERVICE sec_files.data.corp_mem TO ROLE MCP_ACCESS_ROLE;

-- Tool 3: Cortex Agent access
GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE MCP_ACCESS_ROLE;
GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE MCP_ACCESS_ROLE;
GRANT USAGE ON AGENT snowflake_intelligence.agents.SNOWFLAKE_INVESTMENT_GURO TO ROLE MCP_ACCESS_ROLE;

-- Tool 4: SQL Execution (warehouse access needed)
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE MCP_ACCESS_ROLE;

-- Allow querying SEC metrics table directly
GRANT SELECT ON TABLE sec_files.data.SEC_METRICS_DAILY TO ROLE MCP_ACCESS_ROLE;
GRANT SELECT ON TABLE sec_files.data.DOCS_CHUNKS_TABLE TO ROLE MCP_ACCESS_ROLE;

-- ========================================================================
-- STEP 3: Create Service Account User
-- ========================================================================
-- Create a dedicated user for MCP access
-- 
-- IMPORTANT: You can either:
--   Option A: Create a new service user (recommended for production)
--   Option B: Use an existing user and grant them the MCP_ACCESS_ROLE
--
-- This script shows Option A (creating new service user)
-- ========================================================================

-- Option A: Create new service user
CREATE USER IF NOT EXISTS mcp_service_user
    PASSWORD = 'ChangeMe123!'  -- CHANGE THIS PASSWORD!
    DEFAULT_ROLE = MCP_ACCESS_ROLE
    DEFAULT_WAREHOUSE = COMPUTE_WH
    MUST_CHANGE_PASSWORD = FALSE  -- Set to TRUE if user should change on first login
    COMMENT = 'Service account for MCP server programmatic access';

-- Grant the MCP role to the service user
GRANT ROLE MCP_ACCESS_ROLE TO USER mcp_service_user;

-- ========================================================================
-- STEP 4: Create PAT for Service User
-- ========================================================================
-- PAT creation must be done through Snowflake UI:
--
-- Instructions:
-- 1. Log out and log back in as mcp_service_user (or as yourself if using existing user)
-- 2. Navigate to: Profile → My Profile → Security tab
-- 3. Scroll to "Programmatic Access Tokens" section
-- 4. Click "+ Token" button
-- 5. Configure token:
--    - Name: "MCP Server Access"
--    - Lifetime: 30-90 days (choose appropriate duration)
--    - Role: MCP_ACCESS_ROLE (will be pre-selected if it's the default role)
-- 6. Click "Generate Token"
-- 7. **COPY THE TOKEN IMMEDIATELY** (shown only once!)
-- 8. Store securely:
--    - Environment variable: export SNOWFLAKE_PAT="token_here"
--    - Or in .env file: SNOWFLAKE_PAT=token_here
--    - Or in secrets manager (AWS Secrets Manager, Azure Key Vault, etc.)
--
-- IMPORTANT SECURITY NOTES:
-- - Never commit PAT to version control
-- - Store in environment variable or secrets manager
-- - Rotate tokens regularly (every 30-90 days)
-- - Revoke immediately if compromised
-- - Monitor token usage through query history
-- ========================================================================

-- ========================================================================
-- STEP 5: Verification
-- ========================================================================
-- Verify the service user and role are set up correctly

-- Show the service user
SHOW USERS LIKE 'mcp_service_user';

-- Show the MCP role
SHOW ROLES LIKE 'MCP_ACCESS_ROLE';

-- Show grants to the MCP role
SHOW GRANTS TO ROLE MCP_ACCESS_ROLE;

-- Show grants to the service user
SHOW GRANTS TO USER mcp_service_user;

-- Display success message
SELECT '✅ Service account setup complete!' AS status;
SELECT 'Next Steps:' AS instructions;
SELECT '1. Create PAT using Snowflake UI (see instructions above)' AS step_1;
SELECT '2. Store PAT securely (environment variable or secrets manager)' AS step_2;
SELECT '3. Test with: python test/test_mcp_with_pat.py' AS step_3;
SELECT '4. See docs/PAT_AUTHENTICATION.md for detailed guide' AS step_4;

-- ========================================================================
-- STEP 6: Testing Access (Optional)
-- ========================================================================
-- After creating PAT, test the service user has correct permissions

-- Test as the service user (using PAT):
/*
-- These queries should succeed when executed with the PAT:

-- Test 1: Can access MCP server
SHOW MCP SERVERS IN SCHEMA sec_files.data;

-- Test 2: Can access semantic view
SELECT * FROM sec_files.data.SEC_REVENUE_SEMANTIC_VIEW LIMIT 1;

-- Test 3: Can access search service
SHOW CORTEX SEARCH SERVICES IN SCHEMA sec_files.data;

-- Test 4: Can access agent
SHOW AGENTS IN SCHEMA snowflake_intelligence.agents;

-- Test 5: Can execute SQL
SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_DATABASE();
*/

-- ========================================================================
-- ALTERNATIVE: Grant MCP Role to Existing User
-- ========================================================================
-- If you prefer to use an existing user instead of creating a new one:
/*
USE ROLE ACCOUNTADMIN;

-- Grant the MCP role to your existing user
GRANT ROLE MCP_ACCESS_ROLE TO USER <your_username>;

-- Set it as default (optional)
ALTER USER <your_username> SET DEFAULT_ROLE = MCP_ACCESS_ROLE;

-- Then create PAT as that user following instructions in STEP 4
*/

-- ========================================================================
-- Token Management Queries
-- ========================================================================
-- Useful queries for managing PATs

-- View all active tokens for the service user
-- SHOW TOKENS FOR USER mcp_service_user;

-- Revoke a specific token (if needed)
-- ALTER USER mcp_service_user REVOKE TOKEN '<token_id>';

-- Monitor PAT usage in query history
/*
USE ROLE ACCOUNTADMIN;

SELECT 
    query_id,
    query_text,
    user_name,
    role_name,
    start_time,
    execution_status
FROM snowflake.account_usage.query_history
WHERE user_name = 'MCP_SERVICE_USER'
    AND start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 100;
*/

-- ========================================================================
-- Security Best Practices
-- ========================================================================
/*
PAT Security Checklist:

✅ DO:
- Use dedicated service account for MCP access
- Grant minimal required permissions (least-privilege)
- Store PAT in environment variables or secrets manager
- Rotate tokens every 30-90 days
- Monitor token usage through query history
- Revoke tokens immediately if compromised
- Use different tokens for different environments (dev/staging/prod)

❌ DON'T:
- Commit PAT to version control (Git, SVN, etc.)
- Share PAT via email or messaging apps
- Use same token across multiple applications
- Use ACCOUNTADMIN role for PAT (too privileged)
- Store PAT in plain text files
- Log PAT values in application logs

Regular Maintenance:
- Review active tokens monthly
- Audit token usage quarterly
- Update passwords on service accounts annually
- Review and minimize role permissions regularly
*/

-- ========================================================================
-- Troubleshooting
-- ========================================================================
/*
Issue: "Invalid access token"
Solution:
- Verify token is correct (no extra spaces)
- Check token hasn't been revoked: SHOW TOKENS FOR USER mcp_service_user;
- Generate new token if needed

Issue: "Insufficient privileges"
Solution:
- Check role has necessary grants: SHOW GRANTS TO ROLE MCP_ACCESS_ROLE;
- Verify user is using correct role: SELECT CURRENT_ROLE();
- Add missing grants from STEP 2 above

Issue: "MCP server not found"
Solution:
- Verify MCP server exists: SHOW MCP SERVERS IN SCHEMA sec_files.data;
- Check user has USAGE on database and schema
- Run script 08_create_mcp_server.sql if not created

Issue: Token expiring too frequently
Solution:
- Create new token with longer lifetime (up to 90 days)
- Set calendar reminder for token rotation
- Consider implementing automated token rotation
*/

-- ========================================================================
-- Clean Up (Optional - Use with Caution)
-- ========================================================================
/*
-- To remove the service account and role (only if no longer needed):

USE ROLE ACCOUNTADMIN;

-- Revoke all tokens for the user first
SHOW TOKENS FOR USER mcp_service_user;
-- Manually revoke each token or:
-- ALTER USER mcp_service_user REVOKE TOKEN '<token_id>';

-- Drop the user
DROP USER IF EXISTS mcp_service_user;

-- Drop the role
DROP ROLE IF EXISTS MCP_ACCESS_ROLE;

WARNING: This will invalidate all PATs created for this user!
*/

