"""
load_source_data.py

Downloads the full Olist Brazilian e-commerce dataset from Kaggle via API,
then loads all tables into the PostgreSQL raw schema.

Usage:
  python scripts/load_source_data.py                          # download + load
  python scripts/load_source_data.py --skip-download          # load already-downloaded files
  python scripts/load_source_data.py --download-dir ./data/   # custom download path

Environment variables (set in .env):
  KAGGLE_USERNAME   — from https://www.kaggle.com/settings > API
  KAGGLE_KEY        — from https://www.kaggle.com/settings > API
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

KAGGLE_DATASET = 'olistbr/brazilian-ecommerce'
DEFAULT_DOWNLOAD_DIR = Path('./data/olist')

TABLES = {
  'olist_orders':      'olist_orders_dataset.csv',
  'olist_order_items': 'olist_order_items_dataset.csv',
  'olist_customers':   'olist_customers_dataset.csv',
  'olist_products':    'olist_products_dataset.csv',
  'olist_sellers':     'olist_sellers_dataset.csv',
  'olist_payments':    'olist_order_payments_dataset.csv',
  'olist_reviews':     'olist_order_reviews_dataset.csv',
}


def download_dataset(download_dir: Path) -> Path:
  """Download and unzip the Olist dataset from Kaggle. Returns the download directory."""
  import kaggle  # noqa: PLC0415 — import deferred so missing package gives a clear error

  download_dir.mkdir(parents=True, exist_ok=True)
  log.info('Downloading %s to %s ...', KAGGLE_DATASET, download_dir)
  kaggle.api.authenticate()
  kaggle.api.dataset_download_files(KAGGLE_DATASET, path=str(download_dir), unzip=True)
  log.info('Download complete.')
  return download_dir


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


def run(download_dir: Path, schema: str, skip_download: bool) -> None:
  if not skip_download:
    download_dataset(download_dir)

  engine = create_engine(build_connection_string())
  ensure_schema(engine, schema)

  for table_name, filename in TABLES.items():
    load_table(engine, table_name, download_dir / filename, schema=schema)

  log.info('All tables loaded. Run `dbt run --full-refresh` to rebuild models.')


if __name__ == '__main__':
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument(
    '--download-dir',
    type=Path,
    default=DEFAULT_DOWNLOAD_DIR,
    help=f'Directory to download/read Olist CSV files (default: {DEFAULT_DOWNLOAD_DIR}).',
  )
  parser.add_argument(
    '--skip-download',
    action='store_true',
    help='Skip the Kaggle download step and load from --download-dir directly.',
  )
  parser.add_argument(
    '--schema',
    default='raw',
    help='Target PostgreSQL schema (default: raw).',
  )
  args = parser.parse_args()
  run(download_dir=args.download_dir, schema=args.schema, skip_download=args.skip_download)
