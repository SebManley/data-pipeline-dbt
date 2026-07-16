# ecommerce-analytics-pipeline

![CI](https://github.com/SebManley/ecommerce-analytics-pipeline/actions/workflows/ci.yml/badge.svg)
![dbt](https://img.shields.io/badge/dbt-1.11-orange)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED)

A dbt pipeline for the public **Olist Brazilian E-commerce** dataset (~100k orders,
2016–2018): source data lands in PostgreSQL, moves through staging and mart layers,
and is tested and rebuilt automatically in CI.

**View the live report →** [https://olist-data-pipeline-dbt.netlify.app/](https://olist-data-pipeline-dbt.netlify.app/)

---

## Project Highlights

- **Layered model architecture.** Raw sources flow through staging models that only
  rename and cast, then into business-ready marts where all joins, aggregations, and
  logic live — keeping each layer's responsibility clean and independently testable.

- **Incremental loading.** `fct_orders` uses a watermark strategy, processing only
  orders newer than what's already loaded on each run, with upserts handled via a
  unique key — the pattern used for any high-volume fact table in production.

- **Comprehensive testing.** Every model carries not-null, uniqueness, and
  cross-layer relationship tests, plus expression tests for business rules like
  non-negative order totals, so a broken pipeline fails loudly in CI instead of
  silently corrupting downstream data.

- **Custom schema routing.** A macro maps models to `raw`, `staging`, and `marts`
  schemas based on their folder rather than dbt's default target-based naming,
  keeping the database organized the same way the codebase is.

- **Fully containerized local environment.** PostgreSQL and Metabase both spin up
  via Docker Compose, so a fresh clone is running end-to-end in minutes with no
  manual database setup.

- **Automated CI.** Every push and pull request seeds sample data, builds the full
  model set, and runs the test suite in GitHub Actions, catching breakages before
  they reach `main`.

- **Production-scale data loading.** A loader script pulls the full ~100k-order
  dataset from Kaggle's API, so local development and CI can run against a
  lightweight seed while still supporting a full-scale rebuild on demand.

---

## Architecture

Raw source tables sit in a `raw` schema. Staging models rename and cast columns
with no business logic, and mart models — the layer everything downstream reads
from — handle all joins, aggregations, and derived metrics.

`fct_orders` loads incrementally: each run processes only orders newer than what's
already in the table and upserts on `order_id`. `fct_daily_revenue`, `dim_customers`,
and `fct_product_category_revenue` are all built on top of it, so they inherit its
filters automatically rather than each needing their own copy of the same logic.

---

## Data lineage

```
raw.olist_customers ──► stg_olist__customers ──┐
raw.olist_orders ─────► stg_olist__orders ─────┼──► fct_orders (incremental) ──┬──► fct_daily_revenue
raw.olist_order_items ► stg_olist__order_items ┘        │                     └──► dim_customers
                                                         │
raw.olist_products ───────────┐                         │
raw.olist_category_translation┴► stg_olist__products ───┴──(joined with stg_olist__order_items)──► fct_product_category_revenue
```

---

## Quick start

### Prerequisites
- Docker Desktop
- Python 3.13+

### 1. Clone and configure

```bash
git clone https://github.com/SebManley/ecommerce-analytics-pipeline.git
cd ecommerce-analytics-pipeline

cp .env.example .env
cp profiles.yml.example ~/.dbt/profiles.yml
```

### 2. Set up Python environment

```bash
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

### 3. Start PostgreSQL

```bash
docker compose up -d
```

### 4. Install dbt packages

```bash
dbt deps
```

### 5. Seed sample data and run models

```bash
dbt seed     # loads 30-row sample into raw schema
dbt run      # builds staging views + mart tables
dbt test     # runs all generic and relationship tests
```

### 6. Explore the lineage graph

```bash
dbt docs generate && dbt docs serve
# open http://localhost:8080
```

---

## Local exploration with Metabase

For ad hoc querying against local data, Metabase is included in the Docker Compose setup
and starts automatically with `docker compose up -d`.

**First-time setup:**
1. Open http://localhost:3000
2. Create an admin account when prompted
3. Add a PostgreSQL database connection:

| Field | Value |
|---|---|
| Host | `postgres` |
| Port | `5432` |
| Database | `olist` |
| Username | `dbt` |
| Password | `dbt` |

4. Set the default schema to `marts`

---

## Loading the full dataset

The script downloads the dataset automatically via the Kaggle API.

1. Generate an API token at [kaggle.com/settings](https://www.kaggle.com/settings) → API → Create New Token
2. Add the credentials to your `.env`:
   ```
   KAGGLE_USERNAME=your_username
   KAGGLE_KEY=your_api_key
   ```
3. Run:
   ```bash
   python scripts/load_source_data.py    # downloads + loads all tables
   dbt run --full-refresh                # rebuild incrementals from scratch
   ```

If you already have the CSVs locally, skip the download:
```bash
python scripts/load_source_data.py --skip-download --download-dir ./data/olist/
```

---

## Project structure

```
├── models/
│   ├── staging/         # views — rename, cast, no business logic
│   │   ├── _sources.yml
│   │   ├── _stg_olist.yml
│   │   ├── stg_olist__customers.sql
│   │   ├── stg_olist__orders.sql
│   │   ├── stg_olist__order_items.sql
│   │   └── stg_olist__products.sql     # category, English translation w/ fallback
│   └── marts/           # tables / incrementals — business-ready
│       ├── _marts.yml
│       ├── fct_orders.sql              (incremental, unique_key = order_id)
│       ├── fct_daily_revenue.sql       (daily revenue aggregation)
│       ├── dim_customers.sql           (one row per real customer + LTV)
│       └── fct_product_category_revenue.sql  (revenue/orders per category)
├── seeds/               # 30-row sample for local dev and CI
├── macros/              # generate_schema_name override
├── scripts/
│   └── load_source_data.py
├── report/              # Evidence static report — see "Live Report" above
│   ├── pages/index.md   # daily revenue, order performance, customer segments
│   └── sources/olist/   # per-mart queries + Postgres connection
├── deploy/
│   └── netlify-deploy.md
├── .github/workflows/ci.yml
├── docker-compose.yml
├── dbt_project.yml
└── packages.yml
```

---

## Schema layout

| Schema | Contains | Materialization |
|---|---|---|
| `raw` | Seeded / loaded source tables | seed |
| `staging` | `stg_olist__*` models | view |
| `marts` | `fct_*`, `dim_*` models | table / incremental |

---

## Key model: fct_orders (incremental)

`fct_orders` uses a watermark strategy — each run only processes orders newer than
the latest `purchased_at` already in the table:

```sql
{% if is_incremental() %}
  WHERE purchased_at > (SELECT MAX(purchased_at) FROM {{ this }})
{% endif %}
```

Upserts are handled via `unique_key = 'order_id'`. Run `dbt run --full-refresh`
to rebuild from scratch.

---

## Dataset

[Olist Brazilian E-Commerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
by Olist, licensed under CC BY-NC-SA 4.0.

The seeds in this repo are a 30-order sample for local development. The full dataset
(~100k orders, 2016–2018) is loaded via `scripts/load_source_data.py`.

The source data's final ~6 weeks (orders placed on/after 2018-09-01) are a sparse trailing
sample rather than complete data — volume tapers off day-by-day instead of stopping at a
real business event. The marts exclude orders on/after that date (`max_complete_order_date`
in `dbt_project.yml`) so trend charts aren't skewed by a misleading drop-off.
