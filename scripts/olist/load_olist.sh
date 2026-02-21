#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

required_csvs=(
  "olist_customers_dataset.csv"
  "olist_geolocation_dataset.csv"
  "olist_order_items_dataset.csv"
  "olist_order_payments_dataset.csv"
  "olist_order_reviews_dataset.csv"
  "olist_orders_dataset.csv"
  "olist_products_dataset.csv"
  "olist_sellers_dataset.csv"
  "product_category_name_translation.csv"
)

if ! command -v psql >/dev/null 2>&1; then
  echo "Erro: comando 'psql' não encontrado no container." >&2
  echo "Instale o cliente PostgreSQL e tente novamente." >&2
  echo "Exemplo (Debian/Ubuntu): apt-get update && apt-get install -y postgresql-client" >&2
  exit 1
fi

missing_csvs=()
for csv_name in "${required_csvs[@]}"; do
  if [[ ! -f "${ROOT_DIR}/datasets/${csv_name}" ]]; then
    missing_csvs+=("${csv_name}")
  fi
done

if (( ${#missing_csvs[@]} > 0 )); then
  echo "Erro: CSV(s) obrigatório(s) não encontrado(s):" >&2
  for csv_name in "${missing_csvs[@]}"; do
    echo "  - ${csv_name}" >&2
  done
  exit 1
fi

psql_base=(psql -v ON_ERROR_STOP=1)

if [[ -n "${DATABASE_URL:-}" ]]; then
  psql_base+=("${DATABASE_URL}")
  echo "Usando conexão via DATABASE_URL"
else
  psql_base+=(
    --host "${PGHOST:-localhost}"
    --port "${PGPORT:-5432}"
    --dbname "${PGDATABASE:-postgres}"
    --username "${PGUSER:-postgres}"
  )
  export PGPASSWORD="${PGPASSWORD:-}"
  echo "Usando conexão via variáveis PG* (host=${PGHOST:-localhost}, db=${PGDATABASE:-postgres})"
fi

cd "${ROOT_DIR}"

echo "[1/4] Criando estrutura relacional (sem FKs)..."
"${psql_base[@]}" -f "scripts/olist/01_create_tables.sql"

echo "[2/4] Carregando CSVs com \\copy..."
"${psql_base[@]}" -f "scripts/olist/02_load_data.sql"

echo "[3/4] Aplicando FKs pós-carga..."
"${psql_base[@]}" -f "scripts/olist/03_add_constraints.sql"

echo "[4/4] Verificando contagens..."
"${psql_base[@]}" <<'SQL'
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM ecommerce.customers
UNION ALL
SELECT 'geolocation', COUNT(*) FROM ecommerce.geolocation
UNION ALL
SELECT 'orders', COUNT(*) FROM ecommerce.orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM ecommerce.order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM ecommerce.order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM ecommerce.order_reviews
UNION ALL
SELECT 'products', COUNT(*) FROM ecommerce.products
UNION ALL
SELECT 'sellers', COUNT(*) FROM ecommerce.sellers
UNION ALL
SELECT 'product_category_name_translation', COUNT(*) FROM ecommerce.product_category_name_translation
ORDER BY table_name;
SQL

echo "Carga Olist finalizada com sucesso."