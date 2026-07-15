# data-pipeline-dbt

![CI](https://github.com/SebManley/data-pipeline-dbt/actions/workflows/ci.yml/badge.svg)
![dbt](https://img.shields.io/badge/dbt-1.11-orange)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED)

A dbt pipeline built on the public **Olist Brazilian E-commerce** dataset
(~100k orders). Demonstrating clean model layering, incremental loads, comprehensive testing, and automated CI.

**[View the live report →](https://olist-data-pipeline-dbt.netlify.app/)**

---

## Project Highlights

| Pattern | Where |
|---|---|
| Source → Staging → Mart layering | `models/staging/`, `models/marts/` |
| Incremental model (watermark strategy) | `fct_orders.sql` |
| Generic + expression tests on every model | `_sources.yml`, `_stg_olist.yml`, `_marts.yml` |
| FK relationship tests across layers | `_sources.yml` → customer / order relationships |
| Custom schema macro (raw / staging / marts) | `macros/generate_schema_name.sql` |
| Docker Compose local environment | `docker-compose.yml` |
| CI: seed → run → test on every push | `.github/workflows/ci.yml` |
| Full-dataset loader for Kaggle CSVs | `scripts/load_source_data.py` |

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
git clone https://github.com/SebManley/data-pipeline-dbt.git
cd data-pipeline-dbt

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
