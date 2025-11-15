-- ========================================================================
-- Investment Analysis Agent - Web Access Functions
-- ========================================================================
-- This script creates Python functions for web scraping and web search.
-- These functions will be used as tools by the Snowflake Intelligence agent.
--
-- Prerequisites:
--   - External access integration created (04_create_external_access.sql)
--   - ACCOUNTADMIN role for creating functions with external access
--   - snowflake_intelligence.agents schema exists
--
-- Creates:
--   - Function: Web_scrape(weburl STRING) - Extracts text from web pages
--   - Function: Web_search(query STRING) - Searches web and returns top 3 results
-- ========================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE snowflake_intelligence;
USE SCHEMA agents;

-- ========================================================================
-- Web Scraping Function
-- ========================================================================
-- Extracts and returns the text content from any given web URL
-- Uses BeautifulSoup to parse HTML and extract readable text
CREATE OR REPLACE FUNCTION Web_scrape(weburl STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
HANDLER = 'get_page'
EXTERNAL_ACCESS_INTEGRATIONS = (Snowflake_intelligence_ExternalAccess_Integration)
PACKAGES = ('requests', 'beautifulsoup4')
COMMENT = 'Extracts text content from a web page. Useful for analyzing web content, articles, and documentation.'
AS
$$
import _snowflake
import requests
from bs4 import BeautifulSoup

def get_page(weburl):
    """
    Fetches a web page and extracts all text content.
    
    Args:
        weburl (str): The URL to scrape (must include http:// or https://)
    
    Returns:
        str: The extracted text content from the page
    """
    try:
        url = f"{weburl}"
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, 'html.parser')
        return soup.get_text(separator=' ', strip=True)
    except Exception as e:
        return f"Error scraping webpage: {str(e)}"
$$;

-- ========================================================================
-- Web Search Function
-- ========================================================================
-- Performs a web search using DuckDuckGo and returns top 3 results as JSON
-- Filters out advertisements and returns structured results
CREATE OR REPLACE FUNCTION Web_search(query STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
HANDLER = 'search_web'
EXTERNAL_ACCESS_INTEGRATIONS = (Snowflake_intelligence_ExternalAccess_Integration)
PACKAGES = ('requests', 'beautifulsoup4')
COMMENT = 'Searches the web using DuckDuckGo and returns top 3 results as JSON. Useful for finding information, URLs, and research.'
AS
$$
import _snowflake
import requests
from bs4 import BeautifulSoup
import urllib.parse
import json

def search_web(query):
    """
    Performs a web search and returns structured results.
    
    Args:
        query (str): The search query
    
    Returns:
        str: JSON string containing top 3 search results with title, link, and snippet
    """
    encoded_query = urllib.parse.quote_plus(query)
    search_url = f"https://html.duckduckgo.com/html/?q={encoded_query}"
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }

    try:
        response = requests.get(search_url, headers=headers, timeout=10)
        response.raise_for_status() 
        
        soup = BeautifulSoup(response.text, 'html.parser')
        
        search_results_list = []
        
        results_container = soup.find(id='links')

        if results_container:
            for result in results_container.find_all('div', class_='result'):
                # Check if the result is an ad and skip it
                if 'result--ad' in result.get('class', []):
                    continue

                # Find title, link, and snippet
                title_tag = result.find('a', class_='result__a')
                link_tag = result.find('a', class_='result__url')
                snippet_tag = result.find('a', class_='result__snippet')
                
                if title_tag and link_tag and snippet_tag:
                    title = title_tag.get_text(strip=True)
                    link = link_tag['href']
                    snippet = snippet_tag.get_text(strip=True)
                    
                    # Append the result as a dictionary to our list
                    search_results_list.append({
                        "title": title,
                        "link": link,
                        "snippet": snippet
                    })

                # Break the loop once we have the top 3 results
                if len(search_results_list) >= 3:
                    break

        if search_results_list:
            # Return the list of dictionaries as a JSON string
            return json.dumps(search_results_list, indent=2)
        else:
            # Return a JSON string indicating no results found
            return json.dumps({"status": "No search results found."})

    except requests.exceptions.RequestException as e:
        return json.dumps({"error": f"An error occurred while making the request: {e}"})
    except Exception as e:
        return json.dumps({"error": f"An unexpected error occurred during parsing: {e}"})
$$;

-- Grant execute privileges to roles that will use these functions
GRANT USAGE ON FUNCTION Web_scrape(STRING) TO ROLE PUBLIC;
GRANT USAGE ON FUNCTION Web_search(STRING) TO ROLE PUBLIC;

-- ========================================================================
-- Verification and Testing
-- ========================================================================
-- Test the Web_scrape function
SELECT 'Testing Web_scrape function...' AS test_step;
SELECT Web_scrape('https://www.snowflake.com/en/blog/') AS scrape_result;

-- Test the Web_search function
SELECT 'Testing Web_search function...' AS test_step;
SELECT Web_search('Snowflake quarterly earnings') AS search_result;

SELECT 'Web functions created successfully' AS status;
SELECT 'Functions are ready to be added as tools to the agent' AS next_step;

