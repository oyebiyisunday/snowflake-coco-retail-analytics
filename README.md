# Snowflake Cortex Code retail analytics

Snowflake Cortex Code (CoCo), Snowflake CoWork, Snowflake CLI, Cortex Agent, Cortex Analyst, Cortex Search, MCP, dbt Projects on Snowflake, and Streamlit in Snowflake.

Retail analytics for a ski and snowboard catalog: a profiling plugin, a cohort model, a Business Insights agent, and the screens from the run. The office runbook is [REAL-PROJECT.md](REAL-PROJECT.md).

## Screens

| Screen | What it shows | File |
|---|---|---|
| Dashboard | Customers, orders, and $5.26B revenue | [images/dashboard-summary.png](images/dashboard-summary.png) |
| Dashboard charts | Order status and revenue by category | [images/dashboard-charts.png](images/dashboard-charts.png) |
| Order size | Revenue by order size and category | [images/product-sales-by-order-size.png](images/product-sales-by-order-size.png) |
| Pipeline health | Five dynamic tables, all active | [images/pipeline-health.png](images/pipeline-health.png) |
| Interactive tables | $5.26B revenue, 1.98M customers | [images/interactive-tables.png](images/interactive-tables.png) |
| Product analytics | Customer lifetime value, segments, and status | [images/product-analytics.png](images/product-analytics.png) |
| Monthly revenue | Bar chart, August–November 2026 | [images/monthly-revenue.png](images/monthly-revenue.png) |
| Agent | Same months as a CoWork table | [images/revenue-chart.png](images/revenue-chart.png) |
| Agent answer | CoWork: August is the lowest month, tools named, revenue table | [images/agent-cowork-answer.png](images/agent-cowork-answer.png) |
| August reviews | CoWork review summary for that month | [images/agent-cowork-reviews.png](images/agent-cowork-reviews.png) |
| Agent from SQL | Same question. Tools: `query_business_data`, `system_execute_sql`, `search_customer_feedback` | [images/agent-answer.png](images/agent-answer.png) |
| Agent overview | 3 sessions and token use | [images/agent-overview.png](images/agent-overview.png) |
| Evaluation | Answer correctness 0.91, logical consistency 0.81 | [images/eval-scores.png](images/eval-scores.png) |

## Results

- **10,669,345** orders, **2,000,000** customers, **25,063,074** order items
- Revenue rises from **$1.05B** in August 2026 to **$1.88B** in November 2026
- August 2026 is the lowest month: **$1,046,175,318.12** and **2,152,541** orders
- `MONTHLY_COHORTS` has **244** rows across **61** signup months. The status filter is `Completed` and `Shipped`
- Agent evaluation: answer correctness **0.91**, logical consistency **0.81**, tool execution **1.00**. Tool selection is **0.00** because the dataset stores the question and the expected answer, not the expected tool
- Row access: the admin role sees all 10 regions. `WEST_COAST_MANAGER` sees only CA, OR, and WA

## Tools

Snowflake CLI **3.29.0**, Cortex Code CLI **1.2.14**, dbt **1.9.4**.

| Tool | Name |
|---|---|
| Snowflake CoWork | Business Insights |
| Cortex Agent | `BUSINESS_INSIGHTS_AGENT` |
| Cortex Analyst | `query_business_data` on `BUSINESS_ANALYTICS_SEMANTIC` |
| Cortex Search | `search_customer_feedback` on `CUSTOMER_FEEDBACK_SEARCH`, `search_products` on `PRODUCT_SEARCH_SERVICE` |
| SQL execution | `system_execute_sql` |
| Agent run from SQL | `SNOWFLAKE.CORTEX.DATA_AGENT_RUN` |
| MCP server | `BUSINESS_INSIGHTS_MCP`: `business-insights-agent`, `revenue-analytics`, `customer-feedback-search` |
| Streamlit in Snowflake | `THE_DASHBOARD` on `HOL_WH` |
| dbt Projects on Snowflake | `AUTOMATED_INTELLIGENCE_DBT_PROJECT`, model `MONTHLY_COHORTS` |
| Dynamic tables | `ENRICHED_ORDERS`, `ENRICHED_ORDER_ITEMS`, `FACT_ORDERS`, `DAILY_BUSINESS_METRICS`, `PRODUCT_PERFORMANCE_METRICS` |
| Agent evaluation | Answer Correctness v3, Logical Consistency v3, Tool Execution Accuracy, Tool Selection Accuracy |
| Row access | `CUSTOMERS_REGION_POLICY`, role `WEST_COAST_MANAGER` |
| Profiling plugin | `retail-analytics` 1.1.0, skill `profile-table` |

The agent reply, the SQL, and the cohort model are in `proof/`. The plugin is in `plugin/retail-analytics/`.
