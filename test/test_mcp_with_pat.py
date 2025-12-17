#!/usr/bin/env python3
"""
Test Snowflake MCP Server with PAT Authentication

This script tests the Snowflake MCP server using Programmatic Access Token (PAT)
authentication instead of OAuth. This is simpler for development and works with
MFA-enabled accounts.

Usage:
    1. Create a PAT in Snowflake UI (Profile → Security → + Token)
    2. Export it as an environment variable:
       export SNOWFLAKE_PAT="your_token_here"
    3. Run this script:
       python test/test_mcp_with_pat.py

Requirements:
    pip install requests python-dotenv
"""

import os
import sys
import json
import requests
from pathlib import Path

# Try to load from .env file if available
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    print("Note: python-dotenv not installed. Using environment variables only.")
    print("Install with: pip install python-dotenv")

# Configuration
ACCOUNT_URL = os.getenv('SNOWFLAKE_ACCOUNT_URL', 'https://dcb76012.snowflakecomputing.com')
PAT_TOKEN = os.getenv('SNOWFLAKE_PAT')
DATABASE = os.getenv('SNOWFLAKE_DATABASE', 'sec_files')
SCHEMA = os.getenv('SNOWFLAKE_SCHEMA', 'data')
MCP_SERVER = os.getenv('SNOWFLAKE_MCP_SERVER', 'SEC_INVESTMENT_MCP')

# Build MCP endpoint
MCP_ENDPOINT = f"{ACCOUNT_URL}/api/v2/databases/{DATABASE}/schemas/{SCHEMA}/mcp-servers/{MCP_SERVER}"


def check_configuration():
    """Verify required configuration is present"""
    if not PAT_TOKEN:
        print("❌ Error: SNOWFLAKE_PAT environment variable not set")
        print("\nTo fix:")
        print("1. Create a PAT in Snowflake UI:")
        print("   - Profile → Security → Programmatic Access Tokens → + Token")
        print("2. Export it as an environment variable:")
        print("   export SNOWFLAKE_PAT='your_token_here'")
        print("\nOr create a .env file in the project root:")
        print("   SNOWFLAKE_PAT=your_token_here")
        print("   SNOWFLAKE_ACCOUNT_URL=https://your_account.snowflakecomputing.com")
        return False
    
    print("✅ Configuration loaded:")
    print(f"   Account: {ACCOUNT_URL}")
    print(f"   Database: {DATABASE}")
    print(f"   Schema: {SCHEMA}")
    print(f"   MCP Server: {MCP_SERVER}")
    print(f"   PAT Token: {PAT_TOKEN[:20]}... (truncated)")
    return True


def make_mcp_request(method, params=None, request_id=1):
    """
    Make an MCP request with PAT authentication
    
    Args:
        method: MCP method name (e.g., 'initialize', 'tools/list', 'tools/call')
        params: Method parameters (dict)
        request_id: JSON-RPC request ID
    
    Returns:
        Response JSON
    """
    try:
        response = requests.post(
            MCP_ENDPOINT,
            headers={
                'Authorization': f'Bearer {PAT_TOKEN}',
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            json={
                'jsonrpc': '2.0',
                'id': request_id,
                'method': method,
                'params': params or {}
            },
            timeout=60
        )
        
        # Check HTTP status
        if response.status_code != 200:
            print(f"❌ HTTP Error {response.status_code}")
            print(f"   Response: {response.text}")
            return None
        
        return response.json()
    
    except requests.exceptions.Timeout:
        print("❌ Request timeout (60s)")
        return None
    except requests.exceptions.ConnectionError as e:
        print(f"❌ Connection error: {e}")
        return None
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return None


def test_initialize():
    """Test 1: Initialize MCP server connection"""
    print("\n" + "="*70)
    print("TEST 1: Initialize MCP Server")
    print("="*70)
    
    result = make_mcp_request('initialize', {
        'protocolVersion': '2025-06-18'
    })
    
    if result and 'result' in result:
        print("✅ MCP server initialized successfully")
        print(f"\nServer Info:")
        server_info = result['result'].get('server_info', {})
        print(f"   Name: {server_info.get('name', 'N/A')}")
        print(f"   Title: {server_info.get('title', 'N/A')}")
        print(f"   Version: {server_info.get('version', 'N/A')}")
        print(f"   Protocol: {result['result'].get('proto_version', 'N/A')}")
        return True
    else:
        print("❌ Failed to initialize MCP server")
        if result:
            print(f"   Error: {json.dumps(result, indent=2)}")
        return False


def test_list_tools():
    """Test 2: List available tools"""
    print("\n" + "="*70)
    print("TEST 2: List Available Tools")
    print("="*70)
    
    result = make_mcp_request('tools/list', {})
    
    if result and 'result' in result:
        tools = result['result'].get('tools', [])
        print(f"✅ Found {len(tools)} tools:\n")
        
        for i, tool in enumerate(tools, 1):
            print(f"{i}. {tool.get('name', 'Unknown')}")
            print(f"   Title: {tool.get('title', 'N/A')}")
            print(f"   Description: {tool.get('description', 'N/A')[:100]}...")
            print()
        
        return True, tools
    else:
        print("❌ Failed to list tools")
        if result:
            print(f"   Error: {json.dumps(result, indent=2)}")
        return False, []


def test_cortex_analyst():
    """Test 3: Call Cortex Analyst tool"""
    print("\n" + "="*70)
    print("TEST 3: Cortex Analyst Tool (revenue-semantic-view)")
    print("="*70)
    
    question = "What companies are available in the database?"
    print(f"Question: {question}\n")
    
    result = make_mcp_request('tools/call', {
        'name': 'revenue-semantic-view',
        'arguments': {
            'message': question
        }
    }, request_id=3)
    
    if result and 'result' in result:
        print("✅ Cortex Analyst response received:\n")
        content = result['result'].get('content', [])
        for item in content:
            if item.get('type') == 'text':
                print(f"   {item.get('text', 'No text')}")
        return True
    else:
        print("❌ Cortex Analyst call failed")
        if result:
            print(f"   Error: {json.dumps(result, indent=2)}")
        return False


def test_cortex_search():
    """Test 4: Call Cortex Search tool"""
    print("\n" + "="*70)
    print("TEST 4: Cortex Search Tool (search-investment-docs)")
    print("="*70)
    
    query = "revenue analysis"
    print(f"Query: {query}\n")
    
    result = make_mcp_request('tools/call', {
        'name': 'search-investment-docs',
        'arguments': {
            'query': query,
            'limit': 3
        }
    }, request_id=4)
    
    if result and 'result' in result:
        print("✅ Cortex Search response received:\n")
        content = result['result'].get('content', [])
        if content:
            print(f"   Found {len(content)} results")
            for i, item in enumerate(content[:3], 1):
                print(f"   {i}. {str(item)[:100]}...")
        else:
            print("   No results found (may need documents uploaded)")
        return True
    else:
        print("❌ Cortex Search call failed")
        if result:
            print(f"   Error: {json.dumps(result, indent=2)}")
        return False


def test_sql_executor():
    """Test 5: Call SQL Execution tool"""
    print("\n" + "="*70)
    print("TEST 5: SQL Execution Tool (sql-executor)")
    print("="*70)
    
    sql_query = "SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_DATABASE()"
    print(f"Query: {sql_query}\n")
    
    result = make_mcp_request('tools/call', {
        'name': 'sql-executor',
        'arguments': {
            'query': sql_query
        }
    }, request_id=5)
    
    if result and 'result' in result:
        print("✅ SQL execution completed:\n")
        content = result['result'].get('content', [])
        for item in content:
            print(f"   {item}")
        return True
    else:
        print("❌ SQL execution failed")
        if result:
            print(f"   Error: {json.dumps(result, indent=2)}")
        return False


def test_cortex_agent():
    """Test 6: Call Cortex Agent tool"""
    print("\n" + "="*70)
    print("TEST 6: Cortex Agent Tool (investment-guro-agent)")
    print("="*70)
    
    message = "What is Snowflake's revenue in fiscal year 2024?"
    print(f"Message: {message}\n")
    
    result = make_mcp_request('tools/call', {
        'name': 'investment-guro-agent',
        'arguments': {
            'message': message
        }
    }, request_id=6)
    
    if result and 'result' in result:
        print("✅ Cortex Agent response received:\n")
        content = result['result'].get('content', [])
        for item in content:
            if item.get('type') == 'text':
                response_text = item.get('text', 'No text')
                # Truncate if too long
                if len(response_text) > 500:
                    print(f"   {response_text[:500]}...")
                    print(f"   (truncated, total length: {len(response_text)} chars)")
                else:
                    print(f"   {response_text}")
        return True
    else:
        print("❌ Cortex Agent call failed")
        if result:
            print(f"   Error: {json.dumps(result, indent=2)}")
        return False


def main():
    """Run all tests"""
    print("="*70)
    print("Snowflake MCP Server Test Suite (PAT Authentication)")
    print("="*70)
    
    # Check configuration
    if not check_configuration():
        sys.exit(1)
    
    # Run tests
    tests_passed = 0
    tests_total = 6
    
    if test_initialize():
        tests_passed += 1
    
    success, tools = test_list_tools()
    if success:
        tests_passed += 1
    
    if test_cortex_analyst():
        tests_passed += 1
    
    if test_cortex_search():
        tests_passed += 1
    
    if test_sql_executor():
        tests_passed += 1
    
    if test_cortex_agent():
        tests_passed += 1
    
    # Summary
    print("\n" + "="*70)
    print("TEST SUMMARY")
    print("="*70)
    print(f"Tests Passed: {tests_passed}/{tests_total}")
    
    if tests_passed == tests_total:
        print("✅ All tests passed!")
        sys.exit(0)
    else:
        print(f"⚠️  {tests_total - tests_passed} test(s) failed")
        sys.exit(1)


if __name__ == '__main__':
    main()

