-- ========================================================================
-- Investment Analysis Agent - External Access Integration
-- ========================================================================
-- This script creates network rules and external access integration to enable
-- web scraping and web search capabilities for the agent.
--
-- Prerequisites:
--   - Must run as ACCOUNTADMIN role
--   - Network access to ports 80 and 443 must be allowed by organization
--   - Security team approval recommended for production environments
--
-- Creates:
--   - Network rule: Snowflake_intelligence_WebAccessRule (ports 80, 443)
--   - External access integration: Snowflake_intelligence_ExternalAccess_Integration
--
-- Security Note:
--   This grants functions the ability to make outbound HTTP/HTTPS requests.
--   Coordinate with your security team before deploying to production.
-- ========================================================================

USE ROLE ACCOUNTADMIN;
--USE SCHEMA snowflake_intelligence.agents;

-- Create network rule for HTTP and HTTPS access
-- This allows functions to make web requests on ports 80 and 443
CREATE OR REPLACE NETWORK RULE Snowflake_intelligence_WebAccessRule
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('0.0.0.0:80', '0.0.0.0:443')
    COMMENT = 'Network rule allowing HTTP and HTTPS access for web scraping and search functions';

-- Create external access integration using the network rule
-- This integration will be referenced by Python functions that need web access
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION Snowflake_intelligence_ExternalAccess_Integration
    ALLOWED_NETWORK_RULES = (Snowflake_intelligence_WebAccessRule)
    ENABLED = TRUE
    COMMENT = 'External access integration for web scraping and search capabilities in investment analysis agent';

-- Grant usage on the integration to roles that will create/use the functions
-- Adjust based on your role-based access control requirements
GRANT USAGE ON INTEGRATION Snowflake_intelligence_ExternalAccess_Integration TO ROLE PUBLIC;

-- ========================================================================
-- Verification
-- ========================================================================
SHOW NETWORK RULES LIKE 'Snowflake_intelligence_WebAccessRule';
SHOW INTEGRATIONS LIKE 'Snowflake_intelligence_ExternalAccess_Integration';

SELECT 'External access integration created successfully' AS status;
SELECT 'Web functions can now access HTTP and HTTPS endpoints' AS capability;

