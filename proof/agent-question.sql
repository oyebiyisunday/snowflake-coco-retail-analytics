USE ROLE ACCOUNTADMIN;
USE WAREHOUSE HOL_WH;

SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_INSIGHTS_AGENT',
  $${
    "messages": [
      {
        "role": "user",
        "content": [
          {
            "type": "text",
            "text": "Which month had the lowest revenue, and what do customer reviews say about that period?"
          }
        ]
      }
    ]
  }$$
) AS agent_response;
