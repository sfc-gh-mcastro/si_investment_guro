"""
LangGraph Agent with Snowflake Managed MCP Server
Complete OAuth 2.0 authentication flow integrated
"""

import os
import json
import asyncio
from openai import OpenAI
import httpx
import webbrowser
from typing import TypedDict, Sequence, Optional
from dotenv import load_dotenv
from urllib.parse import urlencode, urlparse, parse_qs
from http.server import HTTPServer, BaseHTTPRequestHandler

from langchain_core.messages import BaseMessage, HumanMessage, AIMessage, SystemMessage
from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph, END, START

load_dotenv()

# region agent log
# Debug log path (NDJSON). Instrumentation writes here in DEBUG MODE.
DEBUG_LOG_PATH = "/Users/mcastro/Documents/github/sfc-gh-mcastro/si_investment_guro/.cursor/debug.log"

def _dbg(hypothesisId: str, location: str, message: str, data: dict | None = None, runId: str = "pre-fix"):
    """Append one NDJSON debug line. Never log secrets."""
    try:
        payload = {
            "sessionId": "debug-session",
            "runId": runId,
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "data": data or {},
            "timestamp": int(__import__("time").time() * 1000),
        }
        with open(DEBUG_LOG_PATH, "a", encoding="utf-8") as f:
            f.write(json.dumps(payload) + "\n")
    except Exception:
        pass
# endregion


class AgentState(TypedDict):
    """State for the agent workflow"""
    messages: Sequence[BaseMessage]
    available_tools: list
    mcp_session_id: Optional[str]


class OAuthCallbackHandler(BaseHTTPRequestHandler):
    """HTTP server handler to capture OAuth callback"""
    
    authorization_code = None
    
    def do_GET(self):
        """Handle GET request from OAuth redirect"""
        # Parse the authorization code from the callback URL
        query_components = parse_qs(urlparse(self.path).query)
        
        # Check for error in callback
        if 'error' in query_components:
            error_code = query_components.get('error', ['unknown'])[0]
            error_desc = query_components.get('error_description', ['No description'])[0]
            
            # Send error response to browser
            self.send_response(400)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(f"""
                <html>
                <body style="font-family: Arial; text-align: center; padding: 50px;">
                    <h1 style="color: red;">&#10060; OAuth Error from Snowflake</h1>
                    <p><strong>Error:</strong> {error_code}</p>
                    <p><strong>Description:</strong> {error_desc}</p>
                </body>
                </html>
            """.encode())
            return
        
        if 'code' in query_components:
            OAuthCallbackHandler.authorization_code = query_components['code'][0]
            
            # Send success response to browser
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b"""
                <html>
                <body style="font-family: Arial; text-align: center; padding: 50px;">
                    <h1 style="color: green;">&#9989; Authentication Successful!</h1>
                    <p>You can close this window and return to your terminal.</p>
                </body>
                </html>
            """)
        else:
            # Error response
            self.send_response(400)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b"""
                <html>
                <body style="font-family: Arial; text-align: center; padding: 50px;">
                    <h1 style="color: red;">&#10060; Authentication Failed</h1>
                    <p>No authorization code received. Please try again.</p>
                </body>
                </html>
            """)
    
    def log_message(self, format, *args):
        """Suppress server log messages"""
        pass


class SnowflakeMCPClient:
    """MCP Client with OAuth 2.0 authentication for Snowflake Managed MCP Server"""
    
    def __init__(self):
        # Snowflake account locators must be lowercase for OAuth
        self.account = os.getenv("SNOWFLAKE_ACCOUNT").lower() if os.getenv("SNOWFLAKE_ACCOUNT") else None
        self.oauth_client_id = os.getenv("OAUTH_CLIENT_ID")
        self.oauth_client_secret = os.getenv("OAUTH_CLIENT_SECRET")

        # Normalize common env-var copy/paste issues: surrounding quotes + trailing newlines/spaces.
        # region agent log
        raw_client_id = self.oauth_client_id
        raw_client_secret = self.oauth_client_secret
        # endregion

        def _normalize_env(v: str | None) -> str | None:
            if v is None:
                return None
            v2 = v.strip()
            if (v2.startswith('"') and v2.endswith('"')) or (v2.startswith("'") and v2.endswith("'")):
                v2 = v2[1:-1].strip()
            return v2

        self.oauth_client_id = _normalize_env(self.oauth_client_id)
        self.oauth_client_secret = _normalize_env(self.oauth_client_secret)
        self.database = os.getenv("SNOWFLAKE_DATABASE", "SALES_INTELLIGENCE")
        self.schema = os.getenv("SNOWFLAKE_SCHEMA", "DATA")
        self.mcp_server_name = os.getenv("MCP_SERVER_NAME", "SALES_INTELLIGENCE_MCP")
        self.role = os.getenv("SNOWFLAKE_ROLE", "AICOLLEGE")
        
        self.redirect_uri = "http://localhost:3000/oauth/callback"
        self.access_token = None
        self.base_url = None
        self.session_id = 0
        self.tools = []
        self.llm = None
        self.graph = None

        # region agent log
        _dbg(
            hypothesisId="H1",
            location="agent.py:SnowflakeMCPClient.__init__",
            message="Loaded OAuth/Snowflake env config (no secrets)",
            data={
                "account_present": bool(self.account),
                "account_value": self.account,
                "oauth_client_id_present": bool(self.oauth_client_id),
                "oauth_client_id_len": len(self.oauth_client_id) if self.oauth_client_id else 0,
                "oauth_client_secret_present": bool(self.oauth_client_secret),
                "oauth_client_secret_len": len(self.oauth_client_secret) if self.oauth_client_secret else 0,
                "oauth_client_id_had_whitespace": (raw_client_id != raw_client_id.strip()) if raw_client_id else False,
                "oauth_client_secret_had_whitespace": (raw_client_secret != raw_client_secret.strip()) if raw_client_secret else False,
                "oauth_client_id_wrapped_in_quotes": (
                    (raw_client_id.strip().startswith('"') and raw_client_id.strip().endswith('"'))
                    or (raw_client_id.strip().startswith("'") and raw_client_id.strip().endswith("'"))
                )
                if raw_client_id
                else False,
                "oauth_client_secret_wrapped_in_quotes": (
                    (raw_client_secret.strip().startswith('"') and raw_client_secret.strip().endswith('"'))
                    or (raw_client_secret.strip().startswith("'") and raw_client_secret.strip().endswith("'"))
                )
                if raw_client_secret
                else False,
                "oauth_client_id_normalized_changed": (raw_client_id != self.oauth_client_id) if raw_client_id else False,
                "oauth_client_secret_normalized_changed": (raw_client_secret != self.oauth_client_secret) if raw_client_secret else False,
                "redirect_uri": self.redirect_uri,
                "role": self.role,
                "database": self.database,
                "schema": self.schema,
                "mcp_server_name": self.mcp_server_name,
            },
        )
        # endregion
        
    def setup_connection(self):
        """Setup connection parameters to Snowflake MCP Server"""
        self.base_url = (
            f"https://{self.account}.snowflakecomputing.com"
            f"/api/v2/databases/{self.database}/schemas/{self.schema}/mcp-servers/{self.mcp_server_name}"
        )
        
        print(f"📡 MCP Server URL: {self.base_url}")
    
    async def authenticate(self):
        """
        Complete OAuth 2.0 authentication flow
        1. Open browser for user authorization
        2. Start local server to capture callback
        3. Exchange authorization code for access token
        """
        print("\n🔐 Starting OAuth 2.0 authentication...")
        print(f"   Client ID: {self.oauth_client_id}")
        print(f"   Redirect URI: {self.redirect_uri}")
        print(f"   Role: {self.role}")

        # region agent log
        _dbg(
            hypothesisId="H2",
            location="agent.py:SnowflakeMCPClient.authenticate",
            message="Starting OAuth flow",
            data={
                "redirect_uri": self.redirect_uri,
                "role": self.role,
                "account_value": self.account,
                "client_id_present": bool(self.oauth_client_id),
                "client_id_len": len(self.oauth_client_id) if self.oauth_client_id else 0,
            },
        )
        # endregion
        
        # Step 1: Build authorization URL
        # Include session:role scope to specify the role
        auth_params = {
            "client_id": self.oauth_client_id,
            "response_type": "code",
            "redirect_uri": self.redirect_uri,
            "scope": f"session:role:{self.role}"
        }
        
        auth_url = f"https://{self.account}.snowflakecomputing.com/oauth/authorize?{urlencode(auth_params)}"

        # region agent log
        _dbg(
            hypothesisId="H2",
            location="agent.py:SnowflakeMCPClient.authenticate",
            message="Built authorize URL + params (no secrets)",
            data={
                "auth_url": auth_url,
                "scope": auth_params.get("scope"),
                "redirect_uri": auth_params.get("redirect_uri"),
            },
        )
        # endregion
        
        print(f"\n📝 Opening browser for authentication...")
        print(f"   Authorization URL: {auth_url}")
        print(f"\n   If browser doesn't open, visit the URL above\n")
        print("⚠️  DEBUG INFO:")
        print(f"   Account: {self.account}")
        print(f"   Client ID (from env): {self.oauth_client_id}")
        print(f"   Redirect URI: {self.redirect_uri}")
        print(f"   Auth params: {auth_params}\n")
        print("⚠️  IMPORTANT:")
        print(f"   - If you see 'WebAuthn assertion is invalid' in browser:")
        print(f"     This means your account requires MFA/WebAuthn authentication")
        print(f"     You need to complete the MFA challenge (fingerprint/security key)")
        print(f"   - Make sure OAuth client redirect URI matches: {self.redirect_uri}")
        print(f"   - Make sure the role '{self.role}' is in PRE_AUTHORIZED_ROLES_LIST\n")
        
        # Step 2: Open browser
        webbrowser.open(auth_url)
        
        # Step 3: Start local server to capture callback
        print("⏳ Waiting for authorization (check your browser)...\n")
        
        server = HTTPServer(('localhost', 3000), OAuthCallbackHandler)
        
        # Wait for one request (the OAuth callback)
        server.handle_request()
        
        authorization_code = OAuthCallbackHandler.authorization_code
        
        if not authorization_code:
            print("\n❌ No authorization code received from Snowflake")
            print("   This usually means:")
            print("   1. You clicked 'Deny' in the browser")
            print("   2. OAuth integration configuration mismatch")
            print("   3. Redirect URI mismatch")
            print(f"   4. Check browser for error details\n")
            raise Exception("Failed to receive authorization code")
        
        print("✅ Authorization code received")

        # region agent log
        _dbg(
            hypothesisId="H3",
            location="agent.py:SnowflakeMCPClient.authenticate",
            message="Received authorization code from callback",
            data={
                "code_present": bool(authorization_code),
                "code_len": len(authorization_code) if authorization_code else 0,
            },
        )
        # endregion
        
        # Step 4: Exchange authorization code for access token
        print("🔄 Exchanging code for access token...")
        
        token_url = f"https://{self.account}.snowflakecomputing.com/oauth/token-request"
        
        print(f"   Token URL: {token_url}")
        print(f"   Client ID: {self.oauth_client_id}")
        print(f"   Client ID length: {len(self.oauth_client_id) if self.oauth_client_id else 0}")
        print(f"   Client Secret length: {len(self.oauth_client_secret) if self.oauth_client_secret else 0}")
        print(f"   Redirect URI: {self.redirect_uri}\n")

        # region agent log
        _dbg(
            hypothesisId="H1",
            location="agent.py:SnowflakeMCPClient.authenticate",
            message="About to POST token exchange request (no secrets)",
            data={
                "token_url": token_url,
                "redirect_uri": self.redirect_uri,
                "client_id_present": bool(self.oauth_client_id),
                "client_id_len": len(self.oauth_client_id) if self.oauth_client_id else 0,
                "client_secret_present": bool(self.oauth_client_secret),
                "client_secret_len": len(self.oauth_client_secret) if self.oauth_client_secret else 0,
                "grant_type": "authorization_code",
            },
        )
        # endregion
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                token_url,
                data={
                    "grant_type": "authorization_code",
                    "code": authorization_code,
                    "redirect_uri": self.redirect_uri,
                    "client_id": self.oauth_client_id,
                    "client_secret": self.oauth_client_secret
                },
                headers={
                    "Content-Type": "application/x-www-form-urlencoded"
                }
            )

            # region agent log
            safe_error = None
            safe_error_description = None
            safe_message = None
            try:
                j = response.json()
                safe_error = j.get("error")
                safe_error_description = j.get("error_description")
                safe_message = j.get("message")
            except Exception:
                safe_error = None
            _dbg(
                hypothesisId="H1",
                location="agent.py:SnowflakeMCPClient.authenticate",
                message="Token exchange response received",
                data={
                    "status_code": response.status_code,
                    "error": safe_error,
                    "error_description": safe_error_description,
                    "message": safe_message,
                },
            )
            # endregion

            # If Snowflake requires confidential client auth via HTTP Basic, retry that way.
            # This is a diagnostic + compatibility fallback; secrets are never logged.
            if response.status_code != 200 and safe_error == "invalid_client":
                # region agent log
                _dbg(
                    hypothesisId="H4",
                    location="agent.py:SnowflakeMCPClient.authenticate",
                    message="Retrying token exchange using HTTP Basic auth (no secrets)",
                    data={"token_url": token_url},
                )
                # endregion

                response_basic = await client.post(
                    token_url,
                    data={
                        "grant_type": "authorization_code",
                        "code": authorization_code,
                        "redirect_uri": self.redirect_uri,
                    },
                    auth=(self.oauth_client_id, self.oauth_client_secret),
                    headers={"Content-Type": "application/x-www-form-urlencoded"},
                )

                # region agent log
                b_error = None
                b_error_description = None
                b_message = None
                try:
                    bj = response_basic.json()
                    b_error = bj.get("error")
                    b_error_description = bj.get("error_description")
                    b_message = bj.get("message")
                except Exception:
                    b_error = None
                _dbg(
                    hypothesisId="H4",
                    location="agent.py:SnowflakeMCPClient.authenticate",
                    message="Token exchange (basic auth) response received",
                    data={
                        "status_code": response_basic.status_code,
                        "error": b_error,
                        "error_description": b_error_description,
                        "message": b_message,
                    },
                )
                # endregion

                # Prefer successful retry response
                if response_basic.status_code == 200:
                    response = response_basic
            
            if response.status_code != 200:
                raise Exception(f"Token exchange failed: {response.status_code} - {response.text}")
            
            token_data = response.json()
            self.access_token = token_data["access_token"]
        
        print("✅ Access token obtained")
        print(f"   Token expires in: {token_data.get('expires_in', 'unknown')} seconds\n")
    
    async def initialize_mcp_session(self):
        """Initialize MCP session with Snowflake"""
        print("🤝 Initializing MCP session...")
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                self.base_url,
                json={
                    "jsonrpc": "2.0",
                    "id": self.session_id,
                    "method": "initialize",
                    "params": {"protocolVersion": "2025-06-18"}
                },
                headers={
                    "Authorization": f"Bearer {self.access_token}",
                    "Content-Type": "application/json",
                    "X-Snowflake-Authorization-Token-Type": "OAUTH",
                    "X-Snowflake-Role": self.role
                }
            )
            
            if response.status_code != 200:
                raise Exception(f"MCP initialization failed: {response.status_code} - {response.text}")
            
            result = response.json()
            
            if "error" in result:
                raise Exception(f"MCP error: {result['error']}")
            
            print(f"✅ MCP Session initialized")
            
            # Print server info if available
            if 'result' in result and isinstance(result['result'], dict):
                if 'serverInfo' in result['result']:
                    server_info = result['result']['serverInfo']
                    print(f"   Server: {server_info.get('name', 'unknown')}")
                    print(f"   Version: {server_info.get('version', 'unknown')}")
                elif 'server_info' in result['result']:
                    server_info = result['result']['server_info']
                    print(f"   Server: {server_info.get('name', 'unknown')}")
                    print(f"   Version: {server_info.get('version', 'unknown')}")
            print()
            
            self.session_id += 1
            
            return result
    
    async def discover_tools(self):
        """Discover tools available via MCP Server"""
        print("🔍 Discovering tools...\n")
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                self.base_url,
                json={
                    "jsonrpc": "2.0",
                    "id": self.session_id,
                    "method": "tools/list",
                    "params": {}
                },
                headers={
                    "Authorization": f"Bearer {self.access_token}",
                    "Content-Type": "application/json",
                    "X-Snowflake-Authorization-Token-Type": "OAUTH",
                    "X-Snowflake-Role": self.role
                }
            )
            
            if response.status_code != 200:
                raise Exception(f"Tool discovery failed: {response.status_code} - {response.text}")
            
            result = response.json()
            
            if "error" in result:
                raise Exception(f"Tool discovery error: {result['error']}")
            
            self.tools = result['result']['tools']
            self.session_id += 1
            
            print(f"📋 Found {len(self.tools)} tools:\n")
            for tool in self.tools:
                print(f"  • {tool['name']}")
                print(f"    {tool['description'][:80]}...")
                print(f"    Input Schema: {tool['inputSchema']}")
                print()
            
            return self.tools
    
    async def call_tool(self, tool_name: str, arguments: dict):
        """Call a tool via MCP"""
        print(f"\n🔧 Calling tool: {tool_name}")
        print(f"   Arguments: {arguments}")
        print(f"   Using parameter format: {list(arguments.keys()) if arguments else 'empty'}\n")
        
        async with httpx.AsyncClient(timeout=300.0) as client:
            response = await client.post(
                self.base_url,
                json={
                    "jsonrpc": "2.0",
                    "id": self.session_id,
                    "method": "tools/call",
                    "params": {
                        "name": tool_name,
                        "arguments": arguments
                    }
                },
                headers={
                    "Authorization": f"Bearer {self.access_token}",
                    "Content-Type": "application/json",
                    "X-Snowflake-Authorization-Token-Type": "OAUTH",
                    "X-Snowflake-Role": self.role
                }
            )
            
            if response.status_code != 200:
                raise Exception(f"Tool call failed: {response.status_code} - {response.text}")
            
            result = response.json()
            print(f"MCP Response: {result}")
            
            if "error" in result:
                raise Exception(f"Tool call error: {result['error']}")
            
            # Check if result contains an error message (nested in content)
            if "result" in result:
                result_content = result["result"]
                if isinstance(result_content, dict) and result_content.get("isError"):
                    error_text = ""
                    if "content" in result_content:
                        for item in result_content["content"]:
                            if isinstance(item, dict) and item.get("type") == "text":
                                error_text = item.get("text", "")
                    print(f"\n❌ MCP Tool Error Details:")
                    print(f"   {error_text}")
                    raise Exception(f"Tool execution error: {error_text}")
            
            self.session_id += 1
            
            return result['result']
    
    def setup_llm(self):
        """Setup OpenAI SDK configured to use Snowflake Cortex (GPT-5)"""
        print("🤖 Setting up GPT-5 via Snowflake Cortex...\n")
        
        # Get PAT token from environment (this is what works with Cortex)
        pat_token = os.getenv("SNOWFLAKE_PAT")
        account_url = os.getenv("SNOWFLAKE_ACCOUNT_URL", f"https://{self.account}.snowflakecomputing.com")
        
        if not pat_token:
            print("❌ ERROR: SNOWFLAKE_PAT not found in .env file!")
            print("   You need a Programmatic Access Token (PAT) for Cortex API calls.")
            print("   This is different from OAuth tokens.")
            print("\n   To generate a PAT:")
            print("   1. Go to Snowsight → Account")
            print("   2. User → Click your user → Security")
            print("   3. Create new Authentication Token")
            print("   4. Add to .env: SNOWFLAKE_PAT=<token>\n")
            raise Exception("SNOWFLAKE_PAT not configured")
        
        try:
            self.llm = OpenAI(
                api_key=pat_token,
                base_url=f"{account_url}/api/v2/cortex/v1"
            )
            
            print("✅ GPT-5 (via Snowflake Cortex) configured")
            print(f"   Base URL: {account_url}/api/v2/cortex/v1")
            print(f"   Model: openai-gpt-5\n")
            print("Available MCP tools:")
            for tool in self.tools:
                print(f"  • {tool['name']}")
            print()
        except Exception as e:
            print(f"❌ Failed to initialize GPT-5 client: {e}")
            raise
    
    async def agent_node(self, state: AgentState) -> AgentState:
        """LangGraph agent node - GPT-5 LLM decides when to call MCP tools"""
        messages = state["messages"]
        
        print(f"🧠 LangGraph Agent Processing with GPT-5...\n")
        
        try:
            # Get the last user message
            last_message = messages[-1]
            user_query = last_message.content if hasattr(last_message, 'content') else str(last_message)
            
            # Create a system prompt that explains the available tools
            tools_desc = "\n".join([f"  • {tool['name']}: {tool['description'][:100]}" for tool in self.tools])
            
            system_prompt = f"""You are a helpful sales intelligence assistant powered by Snowflake Cortex GPT-5.

You have access to the following tools:
{tools_desc}

When answering questions about sales data, metrics, deals, or conversations:
1. If you need actual sales data or insights on sales conversations to answer the question, call the sales-intelligence-agent tool
3. Use the tool's response to provide accurate, specific answers
4. Always cite the data source when providing metrics or numbers"""
            
            print(f"📤 User Query: {user_query}\n")
            print(f"🤖 Calling GPT-5...\n")
            
            try:
                # Build tool definitions for GPT-5
                tools_for_gpt5 = [
                    {
                        "type": "function",
                        "function": {
                            "name": tool["name"],
                            "description": tool["description"],
                            "parameters": tool.get("inputSchema", {})
                        }
                    }
                    for tool in self.tools
                ]
                
                # First call: GPT-5 decides whether to call the tool
                response = self.llm.chat.completions.create(
                    model="openai-gpt-5",
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_query}
                    ],
                    tools=tools_for_gpt5,
                    tool_choice="auto"
                )
                
                # Check if GPT-5 wants to call a tool
                if response.choices[0].message.tool_calls:
                    tool_call = response.choices[0].message.tool_calls[0]
                    tool_name = tool_call.function.name
                    tool_args = json.loads(tool_call.function.arguments)
                    
                    print(f"🔧 GPT-5 chose to call tool: {tool_name}")
                    print(f"   Arguments: {tool_args}\n")
                    
                    # Call the MCP tool
                    mcp_result = await self.call_tool(tool_name, tool_args)
                    
                    # Extract response text from MCP
                    mcp_response_text = str(mcp_result)
                    if isinstance(mcp_result, dict) and 'content' in mcp_result:
                        mcp_response_text = ""
                        for item in mcp_result.get('content', []):
                            if isinstance(item, dict) and item.get('type') == 'text':
                                mcp_response_text += item.get('text', '')
                    
                    print(f"✅ MCP Tool Response:\n{mcp_response_text}\n")
                    
                    # Second call: GPT-5 synthesizes with tool response
                    print(f"🤖 GPT-5 synthesizing final answer...\n")
                    
                    synthesis_response = self.llm.chat.completions.create(
                        model="openai-gpt-5",
                        messages=[
                            {"role": "system", "content": system_prompt},
                            {"role": "user", "content": user_query},
                            {"role": "assistant", "content": response.choices[0].message.content or ""},
                            {"role": "user", "content": f"Tool response:\n\n{mcp_response_text}\n\nNow provide a comprehensive answer based on this data."}
                        ]
                    )
                    
                    final_response = synthesis_response.choices[0].message.content
                    print(f"✅ Final Response:\n{final_response}\n")
                else:
                    # GPT-5 chose not to call tool, use its response directly
                    final_response = response.choices[0].message.content
                    print(f"✅ GPT-5 Response (no tool call needed):\n{final_response}\n")
                
            except Exception as e:
                print(f"❌ Error during GPT-5 call: {e}")
                raise
            
            # Add the response to messages
            agent_message = AIMessage(content=final_response)
            
            return {
                "messages": list(messages) + [agent_message],
                "available_tools": state.get("available_tools", []),
                "mcp_session_id": state.get("mcp_session_id")
            }
            
        except Exception as e:
            print(f"❌ Agent error: {e}\n")
            error_message = AIMessage(content=f"Error: {str(e)}")
            return {
                "messages": list(messages) + [error_message],
                "available_tools": state.get("available_tools", []),
                "mcp_session_id": state.get("mcp_session_id")
            }
    
    async def should_continue(self, state: AgentState) -> str:
        """Decide workflow continuation - for now, always end after agent processes"""
        return "end"
    
    async def create_workflow(self):
        """Create LangGraph workflow - simplified single-node flow"""
        print("🔧 Building LangGraph workflow...\n")
        
        workflow = StateGraph[AgentState, AgentState, AgentState](AgentState)
        
        # Add the agent node
        workflow.add_node("agent", self.agent_node)
        
        # Set entry point
        workflow.set_entry_point("agent")
        
        # Set end point
        workflow.set_finish_point("agent")
        
        self.graph = workflow.compile()
        print("✅ Workflow built\n")
    
    async def interactive_session(self):
        """Interactive chat"""
        print("\n" + "="*60)
        print("🤖 Snowflake MCP Agent Ready!")
        print("="*60)
        print("\nCommands:")
        print("  'exit' - Quit the session")
        print("  'tools' - List available tools")
        print("\nType your question or command:\n")
        
        conversation_history = []
        
        while True:
            try:
                user_input = input("💬 You: ")
                
                if user_input.lower() in ['exit', 'quit', 'q']:
                    print("\n👋 Goodbye!")
                    break
                
                if user_input.lower() == 'tools':
                    print("\n📋 Available Tools:")
                    for tool in self.tools:
                        print(f"\n  • {tool['name']}")
                        print(f"    {tool['description']}")
                    print()
                    continue
                
                conversation_history.append(HumanMessage(content=user_input))
                
                state = {
                    "messages": conversation_history,
                    "available_tools": self.tools,
                    "mcp_session_id": str(self.session_id)
                }
                
                result = await self.graph.ainvoke(state)
                final_message = result["messages"][-1]
                conversation_history.append(final_message)
                
                print(f"\n🤖 Agent: {final_message.content}\n")
                
            except KeyboardInterrupt:
                print("\n\n👋 Goodbye!")
                break
            except Exception as e:
                print(f"\n❌ Error: {e}\n")


async def main():
    """Main function"""
    print("="*60)
    print("🤖 Snowflake MCP Client with OAuth 2.0")
    print("="*60)
    
    # Check required environment variables
    required_vars = [
        "SNOWFLAKE_ACCOUNT",
        "OAUTH_CLIENT_ID",
        "OAUTH_CLIENT_SECRET"
    ]
    
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    
    if missing_vars:
        print(f"\n❌ Missing required environment variables:")
        for var in missing_vars:
            print(f"   - {var}")
        print("\nPlease set these in your .env file")
        return
    
    client = SnowflakeMCPClient()
    
    try:
        # Setup
        client.setup_connection()
        
        # OAuth Authentication
        await client.authenticate()
        
        # Initialize MCP
        await client.initialize_mcp_session()
        await client.discover_tools()
        
        # Setup LLM and workflow
        client.setup_llm()
        await client.create_workflow()
        
        # Interactive session
        await client.interactive_session()
        
    except Exception as e:
        print(f"\n❌ Error: {str(e)}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(main())
