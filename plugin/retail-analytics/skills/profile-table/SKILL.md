---
name: profile-table
description: "Profile a Snowflake table or view: row count, NULL counts per column, distinct value counts, top values for low-cardinality columns, and flagged data quality issues. Use whenever the user wants to profile, inspect, explore, sanity-check, or assess the quality of a table, even if they don't say 'profile'. Triggers: profile table, profile-table, table profile, data profiling, column stats, null check, distinct values, cardinality, is this table clean, data quality check on a table, what's in this table."
---

# Profile Table

Read-only profiling of one Snowflake table or view. Produces a per-column profile and a ranked list of potential data quality issues.

## Input

- **Table name** (required). Accept `DB.SCHEMA.TABLE`, `SCHEMA.TABLE`, or `TABLE`; resolve missing parts from `CURRENT_DATABASE()` / `CURRENT_SCHEMA()`. If still ambiguous, ask.
- **Optional:** column subset, sample percentage, NULL threshold (default 5%).

## Workflow

### Step 1: Resolve and validate the table

Each identifier part must match `^[A-Za-z_][A-Za-z0-9_$]*$` or be a properly double-quoted identifier. The table name is interpolated into SQL, so reject anything else rather than risk injection.

Get metadata (one query):

```sql
SELECT c.column_name, c.data_type, c.ordinal_position, t.row_count, t.bytes, t.table_type
FROM <DB>.INFORMATION_SCHEMA.COLUMNS c
JOIN <DB>.INFORMATION_SCHEMA.TABLES t
  ON t.table_schema = c.table_schema AND t.table_name = c.table_name
WHERE c.table_schema = '<SCHEMA>' AND c.table_name = '<TABLE>'
ORDER BY c.ordinal_position;
```

No rows → table doesn't exist or the role can't see it. Stop and say which.

### Step 2: Check scan size

`row_count` from metadata is free and exact for tables (NULL for views).

**⚠️ STOP** if `row_count > 100,000,000` or `bytes > 50 GB` (or a view of unknown size over large tables). Tell the user the scope and offer:
1. Full scan
2. Sample (`SAMPLE (1)` or a percentage they choose) — NULL/distinct figures become estimates
3. Narrow to specific columns

Smaller tables: proceed without asking.

### Step 3: Run the single-pass profile

Generate one query covering every column so the table is scanned once. Per column:

```sql
COUNT_IF(<col> IS NULL)            AS "<col>__nulls",
APPROX_COUNT_DISTINCT(<col>)       AS "<col>__distinct"
```

Add by type (these feed Step 5 flags):

| Type | Extra expressions |
|---|---|
| TEXT | `COUNT_IF(TRIM(<col>) = '')` blanks; `COUNT_IF(LOWER(TRIM(<col>)) IN ('n/a','na','null','none','unknown','-','?'))` placeholders; `MIN(LENGTH(<col>))`, `MAX(LENGTH(<col>))` |
| NUMBER / FLOAT | `MIN`, `MAX`, `COUNT_IF(<col> < 0)` negatives, `COUNT_IF(<col> = 0)` zeros |
| DATE / TIMESTAMP | `MIN`, `MAX`, `COUNT_IF(<col> > CURRENT_TIMESTAMP())` future-dated |
| BOOLEAN | `COUNT_IF(<col>)` true count |
| VARIANT / OBJECT / ARRAY / GEOGRAPHY | NULL count only; `APPROX_COUNT_DISTINCT` is unsupported on some semi-structured types, so skip it |

Plus `COUNT(*) AS total_rows` (use this, not metadata, when sampling or profiling a view).

**Wide tables:** if more than ~60 columns, split into batches of ~60 columns per query so the SELECT list stays manageable; each batch is still one scan.

Use `APPROX_COUNT_DISTINCT` rather than `COUNT(DISTINCT)` because exact distinct counts on many columns are expensive; it is within ~2% and good enough for profiling. Say the counts are approximate.

### Step 4: Top values for low-cardinality columns

For columns with `distinct <= 20` (and not all-NULL), show value frequencies. Combine into one query with `UNION ALL`:

```sql
SELECT '<col>' AS column_name, <col>::VARCHAR AS value, COUNT(*) AS cnt
FROM <table> GROUP BY 2
UNION ALL ...
ORDER BY column_name, cnt DESC;
```

Skip if there are none. Cap at 15 columns to bound the scan.

### Step 5: Flag issues

Apply these rules to the Step 3/4 results. Severity guides ordering in the report.

| Severity | Flag | Rule |
|---|---|---|
| High | All NULL | nulls = total_rows |
| High | Key not unique | Column name is `ID` or ends in `_ID`/`_KEY`, distinct < 98% of non-null rows, and it looks like the table's grain (first column or only `*_ID` with near-row-count distinct) |
| High | NULLs in likely key | Same key heuristic, nulls > 0 |
| Medium | High NULL rate | nulls / total_rows > threshold (default 5%) |
| Medium | Constant column | distinct = 1 |
| Medium | Future-dated | future count > 0 |
| Medium | Placeholder / blank text | placeholders + blanks > 0 |
| Low | Some NULLs | 0 < NULL% ≤ threshold — report the count; small but non-zero NULLs often break sums and joins |
| Low | Negative values | negatives > 0 in columns named like amount, price, cost, quantity, qty, total |
| Low | Unexpected cardinality | TEXT with distinct ≈ total_rows (free text or ID stored as text), or a `*_CATEGORY`/`*_STATUS`/`*_TYPE` column with distinct > 100 |

These are heuristics, so present them as "potential" issues. Do not claim a column is a key unless the name/cardinality evidence supports it.

## Output

```
Profile: DB.SCHEMA.TABLE  (<table_type>, <total_rows> rows, <size>; sampled: yes/no)

| Column | Type | NULLs | NULL % | Distinct (approx) | Min | Max | Notes |
|---|---|---|---|---|---|---|---|

Top values (low-cardinality columns)
<col>: value (count), value (count), ...

Potential data quality issues (N)
1. [High] <COLUMN> — <flag>: <evidence with numbers>
2. ...
```

- Format large numbers with thousands separators; NULL % to 2 decimals.
- If no issues: "No potential issues found by these checks." — don't claim the data is clean beyond what was checked.
- Optionally render a bar chart of NULL % by column (columns with NULLs only) with `visualize_data`.
- End with one or two concrete next steps where relevant (e.g. attach `NULL_COUNT` DMFs to flagged columns via the `data-quality` skill). Suggest; don't execute.

## Stopping Points

- ✋ Step 1: Table can't be resolved or identifier is unsafe
- ✋ Step 2: Large scan (>100M rows or >50 GB) — ask full / sample / narrow

All queries are read-only; no other approval needed.
