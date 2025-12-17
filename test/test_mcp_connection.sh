#!/bin/bash
# Quick MCP Connection Test
# Tests if your PAT and MCP endpoint are working correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "MCP Server Connection Test"
echo "========================================="
echo ""

# Check if SNOWFLAKE_PAT is set
if [ -z "$SNOWFLAKE_PAT" ]; then
    echo -e "${RED}❌ Error: SNOWFLAKE_PAT environment variable not set${NC}"
    echo ""
    echo "To fix:"
    echo "  export SNOWFLAKE_PAT='your_token_here'"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} SNOWFLAKE_PAT is set"
echo "  Token: ${SNOWFLAKE_PAT:0:20}... (truncated)"
echo ""

# Configuration
ACCOUNT_URL="https://dcb76012.snowflakecomputing.com"
DATABASE="sec_files"
SCHEMA="data"
MCP_SERVER="SEC_INVESTMENT_MCP"
ENDPOINT="$ACCOUNT_URL/api/v2/databases/$DATABASE/schemas/$SCHEMA/mcp-servers/$MCP_SERVER"

echo "Endpoint: $ENDPOINT"
echo ""

# Test 1: Initialize
echo "Test 1: Initialize MCP Server"
echo "------------------------------"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ENDPOINT" \
  -H "Authorization: Bearer $SNOWFLAKE_PAT" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
      "protocolVersion": "2025-06-18",
      "capabilities": {},
      "clientInfo": {
        "name": "test-client",
        "version": "1.0.0"
      }
    }
  }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✓ Success!${NC} HTTP $HTTP_CODE"
    echo ""
    echo "Response:"
    echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
    echo ""
else
    echo -e "${RED}❌ Failed!${NC} HTTP $HTTP_CODE"
    echo ""
    echo "Response:"
    echo "$BODY"
    echo ""
    
    if [ "$HTTP_CODE" -eq 401 ]; then
        echo -e "${YELLOW}Diagnosis: Authentication failed${NC}"
        echo "  - Your PAT token may be invalid, expired, or revoked"
        echo "  - Create a new PAT: Snowflake UI → Profile → Security → + Token"
        echo ""
    elif [ "$HTTP_CODE" -eq 404 ]; then
        echo -e "${YELLOW}Diagnosis: MCP server not found${NC}"
        echo "  - Run: snow sql -c mcastro -f sql_scripts/08_create_mcp_server.sql"
        echo ""
    elif [ "$HTTP_CODE" -eq 403 ]; then
        echo -e "${YELLOW}Diagnosis: Insufficient privileges${NC}"
        echo "  - Your role may not have access to the MCP server"
        echo "  - Run grants from sql_scripts/03_create_semantic_view.sql"
        echo ""
    fi
    
    exit 1
fi

# Test 2: List Tools
echo "Test 2: List Available Tools"
echo "-----------------------------"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ENDPOINT" \
  -H "Authorization: Bearer $SNOWFLAKE_PAT" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/list",
    "params": {}
  }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✓ Success!${NC} HTTP $HTTP_CODE"
    echo ""
    
    # Extract tool names
    TOOL_COUNT=$(echo "$BODY" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data.get('result', {}).get('tools', [])))" 2>/dev/null || echo "0")
    
    if [ "$TOOL_COUNT" -gt 0 ]; then
        echo "Found $TOOL_COUNT tools:"
        echo "$BODY" | python3 -c "import sys, json; data = json.load(sys.stdin); tools = data.get('result', {}).get('tools', []); [print(f\"  - {t.get('name')}: {t.get('title')}\") for t in tools]" 2>/dev/null || echo "$BODY"
    else
        echo "Response:"
        echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
    fi
    echo ""
else
    echo -e "${RED}❌ Failed!${NC} HTTP $HTTP_CODE"
    echo ""
    echo "Response:"
    echo "$BODY"
    echo ""
    exit 1
fi

echo "========================================="
echo -e "${GREEN}✓ All tests passed!${NC}"
echo "========================================="
echo ""
echo "Your MCP server is working correctly."
echo "If Cursor IDE still shows 'loading tools', try:"
echo "  1. Completely quit Cursor (Cmd+Q on Mac)"
echo "  2. Restart Cursor"
echo "  3. Check Cursor logs for errors"
echo ""


