# Runbook: Snowflake analytics project

Do the steps in order. Do not run a script that drops the database.

You need a Snowflake account where Cortex is enabled, a user who can use `ACCOUNTADMIN` once, and your own CSV files. The SQL uses sample names. Fill the blank table, then change those names and any column that does not match your files. How to do that is in the next section.

`ACCOUNTADMIN` is the account owner. It can drop any database, change any user, and see every row. Use it for four jobs only:

1. Create `ACME_ENGINEER`, the database, the warehouses, and the resource monitors. Grant the engineer ownership of that database, use of those warehouses, and permission to call Cortex. The engineer does not get the right to create databases or warehouses for the account.
2. Create the external access integration dbt needs, and grant the engineer role use of it. An integration is an account object. A project role cannot create one.
3. Create `ACME_REGION_READER` when two groups must see different rows. Creating a role is an account job.
4. Set the user’s default role. Changing a user is an account job. The agent uses that default role.

`ACME_ENGINEER` creates the database, so it owns the schemas. Ownership lets that role create tables, stages, file formats, tasks, the agent, and the evaluation objects.

Write these names down first. Use them everywhere this runbook says `ACME`.

| Blank | Your value |
|---|---|
| Connection name | `acme` |
| Account identifier | no `https://`, no slashes |
| User | |
| Role for the build | `ACME_ENGINEER` |
| Database | `ACME_RETAIL` |
| Transform warehouse | `ACME_TRANSFORM_WH` |
| App warehouse | `ACME_APP_WH` |
| Role used only to create roles and the dbt integration | `ACCOUNTADMIN` |
| Reader role, only if row access is required | `ACME_REGION_READER` |
| States that reader may see | `CA`, `OR`, `WA` |
| CSV stage folder | `@ACME_RETAIL.RAW.SOURCE_STAGE` |

## How to change a name or a column

`ACME` is a sample. Fill the blank table above before you run any SQL. Then, in each statement you run, replace the sample with the value you wrote:

| Sample in this guide | Replace it with |
|---|---|
| `acme` after `-c` | Your connection name |
| `ACME_ENGINEER` | Your build role |
| `ACME_RETAIL` | Your database |
| `ACME_TRANSFORM_WH` | Your transform warehouse |
| `ACME_APP_WH` | Your app warehouse |
| `ACME_REGION_READER` | Your reader role, only if you run step 11 |
| `ACME_DASHBOARD` | Your Streamlit app name |
| `'CA', 'OR', 'WA'` | The region codes that reader may see |

Replace the whole name. If your database is `NORTHWIND`, every `ACME_RETAIL` in the statement becomes `NORTHWIND`. Change the statement you are about to run. Leave this file as the sample for the next project.

The load is written for three files, `customers.csv`, `orders.csv`, and `order_items.csv`, with the columns in step 4. Your files can differ. Use one name for each fact, and use that same name in every later step.

| Sample column | What later steps use it for | If your file uses another name |
|---|---|---|
| `customer_id` | Join customers to orders | Use your key in step 4, the dynamic table, and the semantic view |
| `order_id` | Order key and order count | Same |
| `order_date` | Daily metrics and the agent | Same |
| `order_status` | Which orders count as kept | Keep your spelling. Paste those exact strings into the cohort filter in step 6 |
| `total_amount` | Revenue | Same. If the amount lives on the line file, sum that column instead |
| `registration_date` | Cohort signup month | If the file says `signup_date`, use `signup_date` in the table and in the cohort model |
| `state` | Row access in step 11, on customers, orders, lines, and the dynamic tables | Use your region column in the policy and in `ON (that_column)` |
| `quantity`, `line_total` | Line facts on the agent | If you have no line file, omit `order_items` from the load and from the semantic view |

Three more sample tables are named in the dbt source list: `product_catalog`, `product_reviews`, `support_tickets`. Create them only when you have those files. If you do not, remove the name from `sources.yml` and delete the model files listed in step 6.

The `COPY` path must match the folder you uploaded. `LIST @SOURCE_STAGE;` prints the real path. Put that path in the `COPY`. A file whose columns are in a different order will load into the wrong fields. Reorder the file, or reorder the `CREATE TABLE` list, so position 1 in the file is position 1 in the table.

Bring your own `dbt-analytics` and `streamlit-dashboard` folders. In those files, search for any database, warehouse, or role that is not in your blank table, and replace it.

## Links

| Need | Link |
|---|---|
| End-to-end app guide | https://www.snowflake.com/en/developers/guides/sfguide-build-end-to-end-ai-app-on-snowflake/ |
| Snowflake CLI install | https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation |
| Connection file | https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/specify-credentials |
| Cortex Code, optional | https://docs.snowflake.com/en/user-guide/cortex-code |
| Dynamic tables | https://docs.snowflake.com/en/user-guide/dynamic-tables-about |
| Data quality | https://docs.snowflake.com/en/user-guide/data-quality-intro |
| dbt on Snowflake | https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake |
| dbt CLI commands | https://docs.snowflake.com/en/developer-guide/snowflake-cli/command-reference/dbt-commands/overview |
| dbt profile | https://docs.getdbt.com/docs/core/connect-data-platform/snowflake-setup |
| Streamlit | https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit |
| Semantic view syntax | https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view |
| Cortex Search | https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview |
| Cortex Agents | https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents |
| Row access | https://docs.snowflake.com/en/user-guide/security-row-intro |

An office connection uses SSO or a private key. A password in the connection file is only for one builder on an account that has neither. The password, the private key, and `config.toml` stay on the machine. Do not put them in this runbook or in Git.

## 1. Install the CLI

The Snowflake CLI is the program that sends SQL, deploys dbt, and deploys Streamlit from this machine. Every later step calls it. If `snow` is missing, the rest of the guide cannot run.

In PowerShell:

```powershell
python -m pip install snowflake-cli
```

Close that window. Open a new PowerShell window.

```powershell
snow --version
```

You need a version that accepts `snow dbt execute <project> run`. CLI 3.29.0 does. A warning about encoding is harmless. Keep going.

`snow` is not recognized: the new window was opened before install finished, or Python Scripts is not on `PATH`. Open another new window. If it is still missing, reinstall with `python -m pip install snowflake-cli` and read the Scripts directory printed at the end.

## 2. Create the connection

The connection tells the CLI which account and user to use. An office signs in with SSO or a private key. A wrong account identifier makes every later command fail before any SQL runs.

Run `snow connection add` once, alone. Do not paste the next command into the same prompt. Answer each question as follows.

| Prompt | Answer |
|---|---|
| Name for this connection | `acme` |
| Account name | account identifier only. Reject the value if it contains `https://` or `/` |
| Username | the Snowflake user |
| Authentication | `externalbrowser` for SSO, or key pair. Password only for one builder, and only when the account has neither |
| Role | `ACCOUNTADMIN` for this connection test only. Step 3 switches the connection to `ACME_ENGINEER` |
| Warehouse | a warehouse that already exists on the account, often `COMPUTE_WH` |
| Database | leave blank. The database does not exist yet |
| Schema | leave blank |
| Host | leave blank, unless the office gave you a Private Link host |

SSO. When the prompt asks for an authenticator, enter `externalbrowser` and leave the password empty. If there is no authenticator prompt, set it in the connection file:

```toml
authenticator = "externalbrowser"
```

Key pair. Generate the key outside the repo, then register the public key as `ACCOUNTADMIN`:

```powershell
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

```sql
USE ROLE ACCOUNTADMIN;
ALTER USER IDENTIFIER(CURRENT_USER()) SET RSA_PUBLIC_KEY = '<one line from rsa_key.pub, without the header lines>';
```

```toml
authenticator = "SNOWFLAKE_JWT"
private_key_file = "C:/keys/rsa_key.p8"
```

Password. Use this only for one builder when the account has no SSO and no key pair. The password is stored in the connection file.

```powershell
snow connection test -c acme
```

Pass: a status of OK.

| Error | Fix |
|---|---|
| `251001` invalid account identifier | Remove `https://` and every slash. Run `snow connection add` again |
| `390100` incorrect username or password | Re-enter the user and password |
| Could not use database | Database was set to a name that does not exist. Clear database and schema on the connection and test again |

Confirm:

```powershell
snow sql -c acme -q "SELECT CURRENT_ACCOUNT(), CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE();"
```

`CURRENT_ROLE()` is `ACCOUNTADMIN` for this one test.

## 3. Create the role, then the database

`ACME_ENGINEER` will own the database, so it can create the tables, the agent, and the evaluation objects. The account owner creates the database, the warehouses, and a monthly credit monitor on each warehouse, then hands the database to the engineer. Replace `100` and `50` with the monthly credit budget the office set. The engineer can use those two warehouses. The engineer cannot create another database or warehouse.

Run this whole block once. The account owner runs the first statements. The engineer creates the schemas after the database is handed over.

```sql
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS ACME_ENGINEER
  COMMENT = 'Builds and operates this project';

GRANT ROLE ACME_ENGINEER TO USER IDENTIFIER(CURRENT_USER());
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE ACME_ENGINEER;

CREATE DATABASE IF NOT EXISTS ACME_RETAIL;

CREATE WAREHOUSE IF NOT EXISTS ACME_TRANSFORM_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

CREATE WAREHOUSE IF NOT EXISTS ACME_APP_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

CREATE RESOURCE MONITOR IF NOT EXISTS ACME_TRANSFORM_MONITOR
  WITH CREDIT_QUOTA = 100
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS ON 80 PERCENT DO NOTIFY
            ON 100 PERCENT DO SUSPEND;

CREATE RESOURCE MONITOR IF NOT EXISTS ACME_APP_MONITOR
  WITH CREDIT_QUOTA = 50
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS ON 80 PERCENT DO NOTIFY
            ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE ACME_TRANSFORM_WH SET RESOURCE_MONITOR = ACME_TRANSFORM_MONITOR;
ALTER WAREHOUSE ACME_APP_WH SET RESOURCE_MONITOR = ACME_APP_MONITOR;

GRANT USAGE, OPERATE ON WAREHOUSE ACME_TRANSFORM_WH TO ROLE ACME_ENGINEER;
GRANT USAGE, OPERATE ON WAREHOUSE ACME_APP_WH TO ROLE ACME_ENGINEER;
GRANT OWNERSHIP ON DATABASE ACME_RETAIL TO ROLE ACME_ENGINEER COPY CURRENT GRANTS;

USE ROLE ACME_ENGINEER;

CREATE SCHEMA IF NOT EXISTS ACME_RETAIL.RAW;
CREATE SCHEMA IF NOT EXISTS ACME_RETAIL.DYNAMIC_TABLES;
CREATE SCHEMA IF NOT EXISTS ACME_RETAIL.DBT_STAGING;
CREATE SCHEMA IF NOT EXISTS ACME_RETAIL.DBT_INTERMEDIATE;
CREATE SCHEMA IF NOT EXISTS ACME_RETAIL.DBT_ANALYTICS;
CREATE SCHEMA IF NOT EXISTS ACME_RETAIL.SEMANTIC;

USE DATABASE ACME_RETAIL;
USE SCHEMA RAW;
USE WAREHOUSE ACME_TRANSFORM_WH;

SELECT CURRENT_ROLE(), CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_WAREHOUSE();
```

Pass: the four names are `ACME_ENGINEER`, `ACME_RETAIL`, `RAW`, and `ACME_TRANSFORM_WH`. Both warehouses show a resource monitor. `SHOW GRANTS TO ROLE ACME_ENGINEER` does not include `CREATE DATABASE` or `CREATE WAREHOUSE` on the account.

Set the connection so every later command uses the engineer role. In the connection file, on the `acme` connection only:

```toml
database = "ACME_RETAIL"
schema = "RAW"
warehouse = "ACME_TRANSFORM_WH"
role = "ACME_ENGINEER"
```

```powershell
snow connection test -c acme
```

## 4. Create the tables and load the files

These tables are the source the rest of the project reads. The row counts prove the files landed. Write down the exact order-status spelling from the load. The cohort model in step 6 has to use those same words, or it returns no rows.

The `CREATE TABLE` columns are the sample. If your header row uses other names, change the column list to your names before you load, and use those names again in steps 5, 6, 8, and 11. The map is in "How to change a name or a column."

```sql
USE ROLE ACME_ENGINEER;
USE DATABASE ACME_RETAIL;
USE SCHEMA RAW;
USE WAREHOUSE ACME_TRANSFORM_WH;

CREATE TABLE IF NOT EXISTS customers (
    customer_id INT,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(200),
    city VARCHAR(50),
    state VARCHAR(2),
    zip_code VARCHAR(10),
    registration_date DATE,
    customer_segment VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS orders (
    order_id VARCHAR(36),
    customer_id INT,
    order_date TIMESTAMP,
    order_status VARCHAR(20),
    total_amount DECIMAL(12, 2),
    discount_percent DECIMAL(5, 2),
    shipping_cost DECIMAL(8, 2)
);

CREATE TABLE IF NOT EXISTS order_items (
    order_item_id VARCHAR(36),
    order_id VARCHAR(36),
    product_id INT,
    product_name VARCHAR(100),
    product_category VARCHAR(50),
    quantity INT,
    unit_price DECIMAL(10, 2),
    line_total DECIMAL(12, 2)
);

CREATE STAGE IF NOT EXISTS SOURCE_STAGE
  DIRECTORY = (ENABLE = TRUE);

CREATE OR REPLACE FILE FORMAT CSV_FORMAT
  TYPE = CSV
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('', 'NULL', 'null')
  EMPTY_FIELD_AS_NULL = TRUE;
```

Put the files in the stage with Snowsight: Data, Databases, `ACME_RETAIL`, `RAW`, Stages, `SOURCE_STAGE`, `+ Files`. Upload `customers.csv`, `orders.csv`, and `order_items.csv` into folders of those names, or upload them at the stage root and change the paths below.

The CSV columns must be in the same order as the `CREATE TABLE` statements. If they are not, stop and reorder the file or the column list. Do not load a mismatched file.

```sql
COPY INTO customers
FROM @SOURCE_STAGE/customers/
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'ABORT_STATEMENT';

COPY INTO orders
FROM @SOURCE_STAGE/orders/
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'ABORT_STATEMENT';

COPY INTO order_items
FROM @SOURCE_STAGE/order_items/
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'ABORT_STATEMENT';
```

`COPY` says 0 files: the path is wrong. Run `LIST @SOURCE_STAGE;` and use the path it prints.

Write down the results of this query. The dashboard and the agent have to match them.

```sql
SELECT 'customers' AS table_name, COUNT(*) AS rows FROM customers
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items;

SELECT order_status, COUNT(*) AS orders
FROM orders
GROUP BY 1
ORDER BY 2 DESC;

SELECT MIN(order_date) AS first_order, MAX(order_date) AS last_order FROM orders;
SELECT MIN(registration_date) AS first_signup, MAX(registration_date) AS last_signup FROM customers;
```

Pass: all three counts are greater than zero, and you have copied the exact `order_status` spelling, including capitals.

Profile orders before you build on them:

```sql
SELECT
    COUNT(*) AS total_rows,
    COUNT_IF(order_id IS NULL) AS order_id_nulls,
    COUNT_IF(order_status IS NULL) AS status_nulls,
    APPROX_COUNT_DISTINCT(order_status) AS status_values,
    COUNT_IF(total_amount IS NULL) AS amount_nulls,
    MIN(total_amount) AS amount_min,
    MAX(total_amount) AS amount_max,
    COUNT_IF(total_amount < 0) AS negative_amounts
FROM orders;
```

If `order_id_nulls` is greater than zero, fix the file before continuing. A null order id cannot be joined.

## 5. Build the dynamic tables

A dynamic table keeps a query result current as new orders arrive, without a full reload each night. The order table refreshes on a one-hour lag. The daily metrics use `DOWNSTREAM`, so they refresh only after the order table has changed. That is the pipeline the dashboard and the agent sit on.

Silver refreshes on a schedule. Gold uses `DOWNSTREAM`.

The `SELECT` below uses the sample column names. If you renamed a column in step 4, use that name here. Drop `discount_percent` or `shipping_cost` from the select if your orders file does not have them, and drop them from `final_amount` too. These `CREATE OR REPLACE` statements are for the first build in an empty schema. After the objects exist, follow the Production section.

`state` is joined onto the order and the line so step 11 can hide rows on the curated tables, not only on `CUSTOMERS`. `final_amount` is the revenue the agent uses.

```sql
USE SCHEMA ACME_RETAIL.DYNAMIC_TABLES;

CREATE OR REPLACE DYNAMIC TABLE enriched_orders
  TARGET_LAG = '1 hour'
  WAREHOUSE = ACME_TRANSFORM_WH
  INITIALIZE = ON_SCHEDULE
  REFRESH_MODE = AUTO
AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_status,
    DATE(o.order_date) AS order_date_only,
    c.state,
    o.total_amount,
    o.discount_percent,
    o.shipping_cost,
    ROUND(o.total_amount * (o.discount_percent / 100), 2) AS discount_amount,
    ROUND(o.total_amount - (o.total_amount * (o.discount_percent / 100)) + COALESCE(o.shipping_cost, 0), 2) AS final_amount
FROM ACME_RETAIL.RAW.ORDERS o
LEFT JOIN ACME_RETAIL.RAW.CUSTOMERS c
  ON c.customer_id = o.customer_id;

CREATE OR REPLACE DYNAMIC TABLE enriched_order_items
  TARGET_LAG = DOWNSTREAM
  WAREHOUSE = ACME_TRANSFORM_WH
  INITIALIZE = ON_SCHEDULE
  REFRESH_MODE = AUTO
AS
SELECT
    i.order_item_id,
    i.order_id,
    i.product_id,
    i.quantity,
    i.line_total,
    o.state
FROM ACME_RETAIL.RAW.ORDER_ITEMS i
JOIN ACME_RETAIL.DYNAMIC_TABLES.ENRICHED_ORDERS o
  ON o.order_id = i.order_id;

CREATE OR REPLACE DYNAMIC TABLE daily_business_metrics
  TARGET_LAG = DOWNSTREAM
  WAREHOUSE = ACME_TRANSFORM_WH
  INITIALIZE = ON_SCHEDULE
  REFRESH_MODE = AUTO
AS
SELECT
    order_date_only,
    state,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers,
    SUM(final_amount) AS total_revenue
FROM ACME_RETAIL.DYNAMIC_TABLES.ENRICHED_ORDERS
GROUP BY order_date_only, state;

SELECT name, scheduling_state, target_lag, row_count
FROM ACME_RETAIL.INFORMATION_SCHEMA.DYNAMIC_TABLES
ORDER BY name;
```

Pass: all three tables are `ACTIVE`. `ENRICHED_ORDERS` has the same row count as `RAW.ORDERS`. If `scheduling_state` is not `ACTIVE`, run `SELECT SYSTEM$DYNAMIC_TABLE_REFRESH_HISTORY('ACME_RETAIL.DYNAMIC_TABLES.ENRICHED_ORDERS');` and read the error in the result. If you did not load `order_items`, skip `ENRICHED_ORDER_ITEMS`.

Null checks, on columns that must not be null:

```sql
USE SCHEMA ACME_RETAIL.RAW;
ALTER TABLE orders SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';
ALTER TABLE orders ADD DATA METRIC FUNCTION
  SNOWFLAKE.CORE.NULL_COUNT ON (order_id),
  SNOWFLAKE.CORE.NULL_COUNT ON (customer_id),
  SNOWFLAKE.CORE.NULL_COUNT ON (order_date);
```

If Snowflake says the metric is already attached, skip that statement.

## 6. Run dbt

dbt builds the customer, product, and cohort tables on top of the raw load. Those tables are what the dashboard and the business questions use for lifetime value, segments, and retention. The cohort filter must match the status spelling saved in step 4.

Start from the dbt project for this catalog. Point `profiles.yml` and `sources.yml` at `ACME_RETAIL`.

Replace `dbt-analytics/profiles.yml` with:

```yaml
acme:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      password: "{{ env_var('SNOWFLAKE_PASSWORD', '') }}"
      role: ACME_ENGINEER
      warehouse: ACME_TRANSFORM_WH
      database: ACME_RETAIL
      schema: staging
      threads: 4
      client_session_keep_alive: false
```

In `dbt_project.yml`, set `name: acme` and `profile: acme`. Keep staging as views in schema `dbt_staging`, intermediate as views in schema `dbt_intermediate`, and marts as tables in schema `dbt_analytics`.

Replace the `database:` line in `models/staging/sources.yml`:

```yaml
version: 2

sources:
  - name: raw
    database: ACME_RETAIL
    schema: RAW
    tables:
      - name: customers
      - name: orders
      - name: order_items
      - name: product_catalog
      - name: product_reviews
      - name: support_tickets
```

This copied project lists six sources. Keep a table in `sources.yml` only if you created it in step 4. For each source you did not load, delete the files in this table before `dbt run`, or the run fails on a missing table:

| Missing source | Delete these files |
|---|---|
| `product_catalog` | `models/staging/stg_products.sql`, `models/staging/stg_order_items.sql` only if it joins the catalog, `models/intermediate/int_product_metrics.sql`, `models/marts/product/` |
| `product_reviews` | `models/staging/stg_product_reviews.sql` |
| `support_tickets` | `models/staging/stg_support_tickets.sql`, `models/intermediate/int_customer_support.sql`, `models/marts/support/` |

Open `models/marts/cohort/monthly_cohorts.sql`. Replace the list below with the exact `order_status` strings you wrote down in step 4. The sample is `Completed` and `Shipped`:

```sql
where order_status in ('Completed', 'Shipped')
```

Lowercase `'completed'` returns zero rows when the table says `Completed`.

The engineer role owns the schema, so it creates the network rule. Only the integration stays with `ACCOUNTADMIN`.

```sql
USE ROLE ACME_ENGINEER;

CREATE OR REPLACE NETWORK RULE ACME_RETAIL.DBT_STAGING.ACME_DBT_NETWORK_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('hub.getdbt.com', 'codeload.github.com');

USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION ACME_DBT_EXT_ACCESS
  ALLOWED_NETWORK_RULES = (ACME_RETAIL.DBT_STAGING.ACME_DBT_NETWORK_RULE)
  ENABLED = TRUE;

GRANT USAGE ON INTEGRATION ACME_DBT_EXT_ACCESS TO ROLE ACME_ENGINEER;

USE ROLE ACME_ENGINEER;
```

Add key tests next to the staging models before the first deploy. `customer_id` and `order_id` must be unique and not null. Use your real column names if step 4 changed them.

```yaml
version: 2

models:
  - name: stg_customers
    columns:
      - name: customer_id
        tests:
          - unique
          - not_null
  - name: stg_orders
    columns:
      - name: order_id
        tests:
          - unique
          - not_null
```

From the `dbt-analytics` directory:

```powershell
snow dbt deploy acme_analytics -c acme --external-access-integration ACME_DBT_EXT_ACCESS
snow dbt execute -c acme acme_analytics test
snow dbt execute -c acme acme_analytics run
```

`test` must pass before you treat `run` as finished. A failed `unique` or `not_null` test means the load has a bad key. Fix the file and run `test` again.

`dbt found 1 package(s) ... only 0 package(s) installed`: the deploy did not get network access. Repeat the deploy command with `--external-access-integration ACME_DBT_EXT_ACCESS`.

The CLI prints a help screen of `build`, `run`, `test`: you used `--args`. The command is `snow dbt execute -c acme acme_analytics run`.

One model failed or a mart has zero rows:

```powershell
snow dbt execute -c acme acme_analytics run --select monthly_cohorts
```

```sql
SELECT table_name, row_count
FROM ACME_RETAIL.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'DBT_ANALYTICS'
ORDER BY table_name;
```

Pass: `CUSTOMER_LIFETIME_VALUE` and `CUSTOMER_SEGMENTATION` have one row per customer you loaded. `MONTHLY_COHORTS` has more than zero rows. A zero there means the status filter still does not match step 4.

## 7. Deploy the dashboard

Streamlit is the page people open to see customers, orders, and revenue. Deploying it inside Snowflake means the page reads this database on the app warehouse, with no separate web server to run.

Copy `streamlit-dashboard` into the new project. Replace `snowflake.yml` with:

```yaml
definition_version: 2
entities:
  acme_dashboard:
    type: streamlit
    identifier:
      name: ACME_DASHBOARD
      schema: RAW
      database: ACME_RETAIL
    title: "Acme analytics"
    query_warehouse: ACME_APP_WH
    main_file: streamlit_app.py
    stage: ACME_RETAIL.RAW.ACME_DASHBOARD_STAGE
    artifacts:
      - streamlit_app.py
      - shared.py
      - app.css
      - environment.yml
      - assets/
      - pages/
```

In the Python pages, search for any database name that is not yours and replace it with the database from your blank table. A copied dashboard may still say `DASH_AUTOMATED_INTELLIGENCE_DB` in:

- `pages/summary.py`
- `pages/pipeline_health.py`
- `pages/customer_product_analytics.py`

If a page has a **Run MERGE** button, do not click it. That button calls a procedure and warehouses this runbook does not create. Use the page that reads `RAW.ORDERS` and `RAW.ORDER_ITEMS`. If your orders table has another name, point that page at your table.

In `pages/pipeline_health.py`, the block that selects from `INTERACTIVE.CUSTOMER_ORDER_ANALYTICS` errors until an interactive table exists. Leave that page on the dynamic-tables section. Skip interactive tables unless a lookup is too slow.

From the `streamlit-dashboard` directory:

```powershell
snow streamlit deploy acme_dashboard -c acme --replace
```

Choose warehouse runtime if the CLI asks. Do not choose container runtime.

Open Snowsight, go to Projects, Streamlit, `ACME_DASHBOARD`. The customer, order, item, and revenue numbers must match the query you saved in step 4.

## 8. Create the semantic view and the agent

The semantic view names the tables, the joins, and the metrics, so Cortex Analyst can turn a question into SQL. The agent is the object CoWork and `DATA_AGENT_RUN` call. Without the view, the agent has no governed way to query revenue and orders.

Run this as `ACME_ENGINEER`. The semantic view uses the clause order `TABLES`, `RELATIONSHIPS`, `FACTS`, `DIMENSIONS`, `METRICS`. It reads the curated dynamic tables and the dbt customer view, which is a view over `RAW.CUSTOMERS`, so the row policy on customers still applies. Revenue is `final_amount`. This `CREATE OR REPLACE` is for the first build in an empty schema.

Every column below must exist on those objects. If one is missing, delete that fact, dimension, or metric. If you did not load `order_items`, delete the `items` table, its relationship, and its facts.

```sql
USE ROLE ACME_ENGINEER;
USE DATABASE ACME_RETAIL;
USE SCHEMA SEMANTIC;
USE WAREHOUSE ACME_APP_WH;

CREATE OR REPLACE SEMANTIC VIEW business_analytics_semantic
  TABLES (
    orders AS ACME_RETAIL.DYNAMIC_TABLES.ENRICHED_ORDERS
      PRIMARY KEY (order_id)
      COMMENT = 'Curated orders with final amount and state',
    customers AS ACME_RETAIL.DBT_STAGING.STG_CUSTOMERS
      PRIMARY KEY (customer_id)
      COMMENT = 'Customers from the dbt staging view',
    items AS ACME_RETAIL.DYNAMIC_TABLES.ENRICHED_ORDER_ITEMS
      PRIMARY KEY (order_item_id)
      COMMENT = 'Curated order lines'
  )
  RELATIONSHIPS (
    orders (customer_id) REFERENCES customers,
    items (order_id) REFERENCES orders
  )
  FACTS (
    orders.final_amount AS final_amount COMMENT = 'Order amount after discount and shipping',
    items.quantity AS quantity COMMENT = 'Units',
    items.line_total AS line_total COMMENT = 'Line amount'
  )
  DIMENSIONS (
    orders.order_status AS order_status COMMENT = 'Order status',
    orders.order_date AS order_date COMMENT = 'Order date',
    orders.state AS state COMMENT = 'Customer state on the order',
    customers.state AS customer_state COMMENT = 'Customer state'
  )
  METRICS (
    orders.total_revenue AS SUM(final_amount) COMMENT = 'Sum of final order amount',
    orders.order_count AS COUNT(DISTINCT orders.order_id) COMMENT = 'Number of orders',
    customers.customer_count AS COUNT(DISTINCT customers.customer_id) COMMENT = 'Number of customers'
  )
  COMMENT = 'Questions about curated orders, customers, and revenue';

SHOW SEMANTIC VIEWS IN SCHEMA ACME_RETAIL.SEMANTIC;
```

`SHOW` must list `BUSINESS_ANALYTICS_SEMANTIC`. If the statement fails, the usual cause is a column name in the view that is not on your table. Remove that fact, dimension, or metric and run it again.

```sql
CREATE OR REPLACE AGENT ACME_RETAIL.SEMANTIC.BUSINESS_INSIGHTS_AGENT
  COMMENT = 'Answers questions from the semantic view'
FROM SPECIFICATION $$
{
  "instructions": {
    "response": "Be concise. Cite the numbers from the query. Format money with a dollar sign and two decimals.",
    "sample_questions": [
      {"question": "What is total revenue by month?"},
      {"question": "How many customers are in each state?"}
    ]
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "query_business_data",
        "description": "Metrics and trends for orders and customers."
      }
    }
  ],
  "tool_resources": {
    "query_business_data": {
      "semantic_view": "ACME_RETAIL.SEMANTIC.BUSINESS_ANALYTICS_SEMANTIC",
      "execution_environment": {"type": "warehouse", "warehouse": "ACME_APP_WH"}
    }
  }
}
$$;

ALTER AGENT ACME_RETAIL.SEMANTIC.BUSINESS_INSIGHTS_AGENT
  SET PROFILE = '{"display_name": "Business Insights", "color": "#29B5E8"}';

SHOW AGENTS IN SCHEMA ACME_RETAIL.SEMANTIC;
```

Open the agent in Snowsight: AI & ML, Agents, `BUSINESS_INSIGHTS_AGENT`. Ask: "What is total revenue by month?" Compare the total with `SELECT SUM(final_amount) FROM ACME_RETAIL.DYNAMIC_TABLES.ENRICHED_ORDERS`.

The agent says the table is empty, and the SQL total is not zero: the chat is using a role that cannot see the rows. CoWork and the agent use the user's default role, not the role selected in the Snowsight picker. Step 12 sets that default to `ACME_ENGINEER`.

Search over reviews is optional. Skip it when you have no review text. When you do, create the service and only then add a search tool. A search tool needs `PRODUCT_REVIEWS`, `SUPPORT_TICKETS`, and `PRODUCT_CATALOG`.

## 9. Publish the MCP server

The MCP server exposes the agent, the analyst view, and customer-feedback search as tools another program can call. This is how the same agent is used outside the Snowflake chat page.

```sql
USE ROLE ACME_ENGINEER;
USE SCHEMA ACME_RETAIL.SEMANTIC;

CREATE OR REPLACE MCP SERVER BUSINESS_INSIGHTS_MCP
FROM SPECIFICATION $$
  tools:
    - name: "business-insights-agent"
      type: "CORTEX_AGENT_RUN"
      identifier: "ACME_RETAIL.SEMANTIC.BUSINESS_INSIGHTS_AGENT"
      description: "Answers questions from the semantic view."
      title: "Business Insights Agent"
    - name: "revenue-analytics"
      type: "CORTEX_ANALYST_MESSAGE"
      identifier: "ACME_RETAIL.SEMANTIC.BUSINESS_ANALYTICS_SEMANTIC"
      description: "Text to SQL for revenue, orders, and customers."
      title: "Revenue Analytics"
$$;

SHOW MCP SERVERS IN SCHEMA ACME_RETAIL.SEMANTIC;
```

Pass: `BUSINESS_INSIGHTS_MCP` is listed.

The URL for a client is:

```text
https://<account_host>/api/v2/databases/ACME_RETAIL/schemas/SEMANTIC/mcp-servers/BUSINESS_INSIGHTS_MCP
```

`<account_host>` is the host you use to open Snowsight, without a path. Save that URL in the client. In Cortex Code the command is `cortex mcp add business-insights <url> --type http`. Cortex Code is optional. The agent in Snowsight already answers questions without it.

## 10. Score the agent

An evaluation asks the agent questions you already know the answer to, then scores the reply. Answer correctness and logical consistency are the scores that say whether the answer is right. The engineer role must own the schema, because the evaluation creates a file format, a stage, and a task there.

Create the question table as `ACME_ENGINEER`. That role owns the schema, so the evaluation can create its file format, stage, and task. Use questions you can check with SQL. One row is enough to prove the path. Add more before you rely on the score.

```sql
USE SCHEMA ACME_RETAIL.SEMANTIC;

CREATE OR REPLACE TABLE agent_evaluation_data (
    input_query VARCHAR,
    ground_truth VARIANT
);

INSERT INTO agent_evaluation_data
SELECT
    'What is total revenue by month?',
    PARSE_JSON('{"ground_truth_output": "One row per month with the sum of final_amount from the curated orders table."}');

CALL SYSTEM$CREATE_EVALUATION_DATASET(
    'Cortex Agent',
    'ACME_RETAIL.SEMANTIC.AGENT_EVALUATION_DATA',
    'ACME_RETAIL.SEMANTIC.ACME_EVAL_DATASET',
    OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'GROUND_TRUTH')
);
```

Then in Snowsight, set the role to `ACME_ENGINEER`:

1. Open the agent `BUSINESS_INSIGHTS_AGENT`.
2. Open Evaluations.
3. Choose the existing dataset `ACME_EVAL_DATASET`. Do not create a custom dataset.
4. Choose **Run an eval manually**. Do not choose **Run an eval with CoCo**.
5. Name the run. Schema `SEMANTIC`. Input column `INPUT_QUERY`.
6. Add two metrics only: Answer Correctness, version v3, and Logical Consistency, version v3. Do not add a custom metric. Do not leave the version on auto.
7. Run it.

`003001` insufficient privileges, or a missing file format, stage, or task: the Snowsight role does not own `ACME_RETAIL.SEMANTIC`. Switch to `ACME_ENGINEER` and run it again. Do not switch to `ACCOUNTADMIN` to get past it.

The score appears on that run. The table `AGENT_EVALUATION_DATA` stores the question, not the score. Save a screenshot of the run.

## 11. Add row access, when two groups must not see the same rows

A row access policy hides rows by role. The same rule goes on customers, orders, order lines, and the curated dynamic tables. A reader who can query orders must not see another region's revenue. Use it when two teams share the data. Skip this step when everyone who can query the tables is allowed to see every row.

`ACCOUNTADMIN` only creates the reader role. `ACME_ENGINEER` owns the tables, so it creates the policies and attaches them. Replace `'CA', 'OR', 'WA'` with the codes from your blank table before you run the block. The two mapping tables have no policy and are not granted to the reader. The policy owner reads them while deciding which rows to return. Rebuild those two tables after every new load.

```sql
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS ACME_REGION_READER
  COMMENT = 'Sees only the states listed in the policy';

GRANT ROLE ACME_REGION_READER TO ROLE ACME_ENGINEER;

USE ROLE ACME_ENGINEER;
USE SCHEMA ACME_RETAIL.RAW;

CREATE OR REPLACE TABLE customer_region AS
SELECT customer_id, state FROM customers;

CREATE OR REPLACE TABLE order_region AS
SELECT o.order_id, c.state
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id;

CREATE OR REPLACE ROW ACCESS POLICY state_region_policy
AS (state VARCHAR) RETURNS BOOLEAN ->
    CASE
        WHEN CURRENT_ROLE() = 'ACME_ENGINEER' THEN TRUE
        WHEN CURRENT_ROLE() = 'ACME_REGION_READER'
             AND state IN ('CA', 'OR', 'WA') THEN TRUE
        ELSE FALSE
    END
    COMMENT = 'Reader sees the listed states only';

CREATE OR REPLACE ROW ACCESS POLICY customer_key_region_policy
AS (customer_id NUMBER) RETURNS BOOLEAN ->
    CASE
        WHEN CURRENT_ROLE() = 'ACME_ENGINEER' THEN TRUE
        WHEN CURRENT_ROLE() = 'ACME_REGION_READER' AND EXISTS (
            SELECT 1 FROM ACME_RETAIL.RAW.CUSTOMER_REGION r
            WHERE r.customer_id = customer_id
              AND r.state IN ('CA', 'OR', 'WA')
        ) THEN TRUE
        ELSE FALSE
    END
    COMMENT = 'Reader sees orders for the listed states only';

CREATE OR REPLACE ROW ACCESS POLICY order_key_region_policy
AS (order_id VARCHAR) RETURNS BOOLEAN ->
    CASE
        WHEN CURRENT_ROLE() = 'ACME_ENGINEER' THEN TRUE
        WHEN CURRENT_ROLE() = 'ACME_REGION_READER' AND EXISTS (
            SELECT 1 FROM ACME_RETAIL.RAW.ORDER_REGION r
            WHERE r.order_id = order_id
              AND r.state IN ('CA', 'OR', 'WA')
        ) THEN TRUE
        ELSE FALSE
    END
    COMMENT = 'Reader sees lines for the listed states only';

ALTER TABLE ACME_RETAIL.RAW.CUSTOMERS
  ADD ROW ACCESS POLICY state_region_policy ON (state);
ALTER TABLE ACME_RETAIL.RAW.ORDERS
  ADD ROW ACCESS POLICY customer_key_region_policy ON (customer_id);
ALTER TABLE ACME_RETAIL.RAW.ORDER_ITEMS
  ADD ROW ACCESS POLICY order_key_region_policy ON (order_id);
ALTER TABLE ACME_RETAIL.DYNAMIC_TABLES.ENRICHED_ORDERS
  ADD ROW ACCESS POLICY state_region_policy ON (state);
ALTER TABLE ACME_RETAIL.DYNAMIC_TABLES.ENRICHED_ORDER_ITEMS
  ADD ROW ACCESS POLICY state_region_policy ON (state);
ALTER TABLE ACME_RETAIL.DYNAMIC_TABLES.DAILY_BUSINESS_METRICS
  ADD ROW ACCESS POLICY state_region_policy ON (state);

GRANT USAGE ON DATABASE ACME_RETAIL TO ROLE ACME_REGION_READER;
GRANT USAGE ON SCHEMA ACME_RETAIL.RAW TO ROLE ACME_REGION_READER;
GRANT USAGE ON SCHEMA ACME_RETAIL.DYNAMIC_TABLES TO ROLE ACME_REGION_READER;
GRANT USAGE ON SCHEMA ACME_RETAIL.DBT_STAGING TO ROLE ACME_REGION_READER;
GRANT USAGE ON SCHEMA ACME_RETAIL.SEMANTIC TO ROLE ACME_REGION_READER;
GRANT USAGE ON WAREHOUSE ACME_APP_WH TO ROLE ACME_REGION_READER;
GRANT SELECT ON TABLE ACME_RETAIL.RAW.CUSTOMERS TO ROLE ACME_REGION_READER;
GRANT SELECT ON TABLE ACME_RETAIL.RAW.ORDERS TO ROLE ACME_REGION_READER;
GRANT SELECT ON TABLE ACME_RETAIL.RAW.ORDER_ITEMS TO ROLE ACME_REGION_READER;
GRANT SELECT ON TABLE ACME_RETAIL.DYNAMIC_TABLES.ENRICHED_ORDERS TO ROLE ACME_REGION_READER;
GRANT SELECT ON TABLE ACME_RETAIL.DYNAMIC_TABLES.ENRICHED_ORDER_ITEMS TO ROLE ACME_REGION_READER;
GRANT SELECT ON TABLE ACME_RETAIL.DYNAMIC_TABLES.DAILY_BUSINESS_METRICS TO ROLE ACME_REGION_READER;
GRANT SELECT ON VIEW ACME_RETAIL.DBT_STAGING.STG_CUSTOMERS TO ROLE ACME_REGION_READER;
GRANT SELECT ON SEMANTIC VIEW ACME_RETAIL.SEMANTIC.BUSINESS_ANALYTICS_SEMANTIC TO ROLE ACME_REGION_READER;
GRANT USAGE ON AGENT ACME_RETAIL.SEMANTIC.BUSINESS_INSIGHTS_AGENT TO ROLE ACME_REGION_READER;
```

Do not grant `SELECT` on all tables in `RAW`. The mapping tables stay ungranted. If you did not load `order_items`, skip the policy and the grant on `ORDER_ITEMS` and `ENRICHED_ORDER_ITEMS`. If a table already has a policy, drop it from the table, then add it again. `ACCOUNTADMIN` is not in the policy, so that role sees zero rows. That is the result you want. The Streamlit app runs as `ACME_ENGINEER`, so grant the app only to people who may see every row.

Prove both roles. The reader queries must list only the states in the policy, on customers and on orders.

```sql
USE ROLE ACME_ENGINEER;
SELECT 'customers' AS src, COUNT(*) AS rows, COUNT(DISTINCT state) AS states FROM ACME_RETAIL.RAW.CUSTOMERS
UNION ALL
SELECT 'orders', COUNT(*), COUNT(DISTINCT c.state)
FROM ACME_RETAIL.RAW.ORDERS o
JOIN ACME_RETAIL.RAW.CUSTOMERS c ON c.customer_id = o.customer_id;

USE ROLE ACME_REGION_READER;
SELECT 'customers' AS src, COUNT(*) AS rows,
       LISTAGG(DISTINCT state, ', ') WITHIN GROUP (ORDER BY state) AS states
FROM ACME_RETAIL.RAW.CUSTOMERS
UNION ALL
SELECT 'orders', COUNT(*),
       LISTAGG(DISTINCT state, ', ') WITHIN GROUP (ORDER BY state)
FROM ACME_RETAIL.DYNAMIC_TABLES.ENRICHED_ORDERS;

USE ROLE ACME_ENGINEER;
```

Write both counts down. Grant `ACME_REGION_READER` only to people who should see that slice.

The agent follows the policy of the person's default role. To test the reader view in CoWork:

```sql
USE ROLE ACCOUNTADMIN;
ALTER USER IDENTIFIER(CURRENT_USER()) SET DEFAULT_ROLE = ACME_REGION_READER;
```

Set it back to `ACME_ENGINEER` when the check is finished. A later build command fails if the default role is still the reader.

## 12. Set the default role

CoWork and the agent use the user's default role, including when Snowsight shows a different role selected. This step sets that default to `ACME_ENGINEER`, so the agent can see the tables it owns. A wrong default makes the agent report an empty table.

```sql
USE ROLE ACCOUNTADMIN;
ALTER USER IDENTIFIER(CURRENT_USER()) SET DEFAULT_ROLE = ACME_ENGINEER;

USE ROLE ACME_ENGINEER;
SELECT CURRENT_ROLE() AS role, COUNT(*) AS orders FROM ACME_RETAIL.RAW.ORDERS;
```

Pass: the role is `ACME_ENGINEER` and the count matches step 4.

## 13. Sign off

This is the check that the earlier steps landed. A passing row means the load, the pipeline, the marts, the dashboard, and the agent agree on the same numbers. Do not call the build finished while a row in this table fails.

| Check | How | Pass |
|---|---|---|
| Account | `SELECT CURRENT_ACCOUNT()` | The office account |
| Role used to build | `SELECT CURRENT_ROLE()` during steps 4 through 10 | `ACME_ENGINEER` |
| Load | Step 4 counts | Greater than zero, and you saved the status spellings |
| Pipeline | Dynamic table query in step 5 | Both `ACTIVE`, enriched orders equals raw orders |
| dbt | `snow dbt execute ... test`, then the mart query in step 6 | `unique` and `not_null` pass. Lifetime value has the customer count. Cohorts are not zero |
| Warehouses | `SHOW WAREHOUSES` | Both have a resource monitor |
| Dashboard | Streamlit Production tab | Same customer, order, and revenue numbers |
| Agent | "What is total revenue by month?" | The sum matches `SUM(final_amount)` on `ENRICHED_ORDERS` |
| MCP | `SHOW MCP SERVERS` | `BUSINESS_INSIGHTS_MCP` exists |
| Evaluation | Snowsight run | Screenshot of answer correctness and logical consistency, version v3 |
| Row access | Step 11, only if you ran it | Reader states on customers and on `ENRICHED_ORDERS` are only the list in the policy |
| Secrets | `git status` | No connection file, password, or key |

## Production

Build steps 3 through 10 in a development database first. Production is a second database the business reads. Open a change ticket before anything is created there.

The account owner creates the production database, the two warehouses, and a resource monitor on each, with the monthly credit quota the office set. The engineer receives ownership of that database and `USAGE` and `OPERATE` on those warehouses, as in step 3. The engineer still does not receive `CREATE DATABASE` or `CREATE WAREHOUSE` on the account.

The first deploy into an empty production schema may use the create statements from this guide. After an object exists, do not run `CREATE OR REPLACE` on it from a laptop. A replace drops the live table, dynamic table, agent, or integration. Ship a reviewed change that uses `ALTER`, or a dbt run from the ticket.

From the reviewed dbt project, against the production connection:

```powershell
snow dbt execute -c acme acme_analytics test
snow dbt execute -c acme acme_analytics run
```

`test` must pass before `run` is applied to production. Rebuild `CUSTOMER_REGION` and `ORDER_REGION` after the load, then run the sign-off table on the production database. The agent total is `SUM(final_amount)` from `DYNAMIC_TABLES.ENRICHED_ORDERS`. The reader role sees only its regions on customers, orders, order lines, and the three dynamic tables.

## Errors

| What you see | What to do |
|---|---|
| Encoding mismatch warning from `snow` | Ignore it |
| `251001` | Account identifier contains a URL or a slash |
| `390100` | Username or password is wrong |
| Database does not exist at login | Clear database and schema, create them in step 3, then set them |
| `dbt` package count is zero | Redeploy with `--external-access-integration ACME_DBT_EXT_ACCESS` |
| `snow dbt execute` prints a command list | Put `run` after the project name. Do not use `--args` |
| Cohort mart has 0 rows | Status filter spelling does not match step 4 |
| Agent says 0 rows | Default role cannot see the table. Row policy is the usual cause |
| Eval `003001` | Snowsight is not using `ACME_ENGINEER`, the owner of `SEMANTIC` |
| Eval opens a custom-metric form | Cancel. Use manual run, v3, two metrics |
| Streamlit merge button fails | Do not click it. Use the Production tab |
| Pipeline Health errors on interactive tables | Expected. That table is not part of this runbook |
