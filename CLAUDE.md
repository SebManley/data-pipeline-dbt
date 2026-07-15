# data-pipeline-dbt

Portfolio reference project showcasing production dbt patterns on the Olist Brazilian E-Commerce dataset (~100k orders, 2016–2018). Intended for Upwork client portfolio.

## Stack

| Layer | Tool |
|---|---|
| Source data | Olist CSVs (Kaggle API) / 30-row seeds for local dev + CI |
| Database | PostgreSQL 15 (Docker Compose) |
| Transformation | dbt Core 1.11 + dbt-utils |
| Visualisation | Evidence static report (deployed to Netlify) + Metabase (Docker Compose, port 3000, local exploration) |
| CI | GitHub Actions (push/PR: seed → run → test) |
| Python | 3.13, venv, pip |

## File and Folder Structure

```
data-pipeline-dbt/
├── .github/
│   └── workflows/
│       └── ci.yml                      # CI: seed → run → test on push/PR
├── macros/
│   └── generate_schema_name.sql        # routes models to raw / staging / marts schemas
├── models/
│   ├── staging/
│   │   ├── _sources.yml                # source definitions, freshness, relationship tests
│   │   ├── _stg_olist.yml              # staging model tests and column docs
│   │   ├── stg_olist__customers.sql
│   │   ├── stg_olist__orders.sql
│   │   ├── stg_olist__order_items.sql
│   │   └── stg_olist__products.sql     # category name, English translation w/ fallback to Portuguese/'Unknown'
│   └── marts/
│       ├── _marts.yml                  # mart model tests and column docs
│       ├── fct_orders.sql              # incremental, unique_key=order_id, watermark on purchased_at
│       ├── fct_daily_revenue.sql
│       ├── dim_customers.sql           # one row per customer + LTV metrics
│       └── fct_product_category_revenue.sql  # revenue/orders/items per category, excl. cancelled
├── scripts/
│   └── load_source_data.py             # downloads Olist CSVs via Kaggle API → raw schema
├── seeds/                              # 30-row sample (used in CI and local quick-start)
├── report/                             # Evidence static report (portfolio-facing live report)
│   ├── pages/
│   │   └── index.md                    # Overview, Product Category, Order Performance, Customer Insights
│   ├── sources/olist/
│   │   ├── connection.yaml             # Postgres connection (local Docker instance)
│   │   ├── fct_daily_revenue.sql       # one query file per mart table, cached at build time
│   │   ├── fct_orders.sql
│   │   ├── dim_customers.sql
│   │   └── fct_product_category_revenue.sql
│   └── evidence.config.yaml
├── deploy/
│   └── netlify-deploy.md               # manual build + drag-and-drop deploy steps
├── .env.example
├── docker-compose.yml                  # PostgreSQL 15 + Metabase
├── dbt_project.yml
├── packages.yml
├── profiles.yml.example                # copy to ~/.dbt/profiles.yml
└── requirements.txt
```

## Schema Layout

| Schema | Contents | Materialisation |
|---|---|---|
| `raw` | Source tables loaded by seeds or `load_source_data.py` | seed / table |
| `staging` | `stg_olist__*` — rename and cast only, no joins or logic | view |
| `marts` | `fct_*`, `dim_*` — all joins and business logic live here | table / incremental |

Schema routing is handled by `macros/generate_schema_name.sql` — don't change schema prefixes without updating it.

## Common Commands

```bash
docker compose up -d                          # start PostgreSQL + Metabase
dbt deps                                      # install packages
dbt seed && dbt run && dbt test               # quick start with sample data
python scripts/load_source_data.py            # full dataset (requires Kaggle creds)
dbt run --full-refresh                        # rebuild incrementals from scratch
dbt docs generate && dbt docs serve           # lineage graph at localhost:8080

cd report && npm run sources && npm run build # rebuild the static report (needs full dataset loaded first)
```

## Key Patterns

- `fct_orders` is incremental using `WHERE purchased_at > MAX(purchased_at)` watermark + `unique_key = 'order_id'` for upserts
- All models are idempotent — safe to re-run
- Every new model needs a matching YAML block (in `_stg_olist.yml` or `_marts.yml`) with at minimum `not_null` + `unique` tests on the primary key
- CI uses seed data only — no Kaggle credentials needed. Every source table referenced by a staging model needs a matching seed CSV with referentially-consistent keys (e.g. `seeds/olist_products.csv` product_ids match those used in `seeds/olist_order_items.csv`), or CI breaks on missing tables / failed `relationships` tests
- `report/` queries the `marts` schema directly at build time and bakes results into a static site — no live DB needed once deployed. Rebuild + redeploy manually (`deploy/netlify-deploy.md`) whenever the marts data changes meaningfully; there's no automated redeploy since the dataset is static
- Evidence's `core-components` has no pie/donut chart — use a 2-category `BarChart` (`swapXY=true`) instead when mirroring a Metabase donut
- Olist's real `order_status` values use American spelling (`canceled`, not `cancelled`) — `is_cancelled` in `stg_olist__orders.sql` and the `accepted_values` tests must match that spelling or ~625 cancelled orders silently leak into revenue figures
- ~610 products in the real dataset have no `product_category_name` — `stg_olist__products.sql` falls back to `'unknown'` (then title-cased to `'Unknown'`) rather than leaving nulls
- The dataset's final ~6 weeks (from `2018-09-01`) are a sparse trailing sample, not complete data — order volume tapers off day-by-day rather than stopping at a real event. `fct_orders.sql` and `fct_product_category_revenue.sql` filter on the `max_complete_order_date` var (`dbt_project.yml`) to exclude it; `fct_daily_revenue`/`dim_customers` inherit the cutoff via `ref('fct_orders')`. Update the var, not the individual models, if this ever needs to change
