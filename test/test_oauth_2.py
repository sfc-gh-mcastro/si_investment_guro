import requests
import json
from urllib.parse import urlencode

# Configuration
ACCOUNT_URL = "https://dcb76012.snowflakecomputing.com"
CLIENT_ID = "2R88SPaG4LMn+qslD+PINJ/9zOs="
CLIENT_SECRET = "m1GfuXeoBoz6coUQ0zSEjdqJLKb19TEyK4beH+Iy1lE="
REDIRECT_URI = "http://127.0.0.1:3000/oauth/callback"

# Simpler authorization URL - no scope
auth_params = {
    'client_id': CLIENT_ID,
    'redirect_uri': REDIRECT_URI,
    'response_type': 'code'
}
auth_url = f"{ACCOUNT_URL}/oauth/authorize?{urlencode(auth_params)}"

print(f"Open this URL:\n{auth_url}\n")
auth_code = input("Enter the authorization code: ")

# Exchange code for token
token_response = requests.post(
    f"{ACCOUNT_URL}/oauth/token-request",
    data={
        'grant_type': 'authorization_code',
        'code': auth_code,
        'client_id': CLIENT_ID,
        'client_secret': CLIENT_SECRET,
        'redirect_uri': REDIRECT_URI
    },
    headers={'Content-Type': 'application/x-www-form-urlencoded'}
)

print(f"Status: {token_response.status_code}")
print(f"Response: {token_response.text}")