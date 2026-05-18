"""
load_source_data.py

Loads the full Olist CSV dataset into the PostgreSQL raw schema.
Use this when you want to run dbt against the complete 100k-row dataset
instead of the seed sample.

Download the dataset from:
  https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
Unzip into a local directory and pass it via --data-dir.

Usage:
  python scripts/load_source_data.py --data-dir ./data/olist/

Environment variables (set in .env):
  POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD
"""

import argparse
import logging
import os
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()
logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
log = logging.getLogger(__name__)

TABLES = {
  'olist_orders':      'olist_orders_dataset.csv',
  'olist_order_items': 'olist_order_items_dataset.csv',
  'olist_customers':   'olist_customers_dataset.csv',
  'olist_products':    'olist_products_dataset.csv',
  'olist_sellers':     'olist_sellers_dataset.csv',
  'olist_payments':    'olist_order_payments_dataset.csv',
  'olist_reviews':     'olist_order_reviews_dataset.csv',
}


def build_connection_string() -> str:
  host = os.environ['POSTGRES_HOST']
  port = os.environ.get('POSTGRES_PORT', '5432')
  db   = os.environ['POSTGRES_DB']
  user = os.environ['POSTGRES_USER']
  pwd  = os.environ['POSTGRES_PASSWORD']
  return f'postgresql://{user}:{pwd}@{host}:{port}/{db}'


def ensure_schema(engine, schema: str) -> None:
  with engine.begin() as conn:
    conn.execute(text(f'CREATE SCHEMA IF NOT EXISTS {schema}'))
  log.info('Schema "%s" ready.', schema)


def load_table(engine, table_name: str, csv_path: Path, schema: str = 'raw') -> None:
  if not csv_path.exists():
    log.warning('Skipping %s — file not found: %s', table_name, csv_path)
    return

  log.info('Loading %s from %s ...', table_name, csv_path.name)
  df = pd.read_csv(csv_path, low_memory=False)
  df.to_sql(
    table_name,
    engine,
    schema=schema,
    if_exists='replace',
    index=False,
    chunksize=5_000,
  )
  log.info('  -> %d rows loaded into %s.%s', len(df), schema, table_name)


def run(data_dir: Path, schema: str = 'raw') -> None:
  engine = create_engine(build_connection_string())
  ensure_schema(engine, schema)

  for table_name, filename in TABLES.items():
    load_table(engine, table_name, data_dir / filename, schema=schema)

  log.info('All tables loaded. Run `dbt run` to build models.')


if __name__ == '__main__':
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument(
    '--data-dir',
    type=Path,
    required=True,
    help='Directory containing the Olist CSV files.',
  )
  parser.add_argument(
    '--schema',
    default='raw',
    help='Target PostgreSQL schema (default: raw).',
  )
  args = parser.parse_args()
  run(data_dir=args.data_dir, schema=args.schema)
