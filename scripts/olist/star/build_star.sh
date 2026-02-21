#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

if ! command -v psql >/dev/null 2>&1; then
  echo "Erro: comando 'psql' não encontrado no container." >&2
  echo "Instale o cliente PostgreSQL e tente novamente." >&2
  echo "Exemplo (Debian/Ubuntu): apt-get update && apt-get install -y postgresql-client" >&2
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

echo "[1/4] Drop/create star schema tables..."
"${psql_base[@]}" -f "scripts/olist/star/10_drop_create_star.sql"

echo "[2/4] Building dimensions..."
"${psql_base[@]}" -f "scripts/olist/star/11_build_dimensions.sql"

echo "[3/4] Building facts..."
"${psql_base[@]}" -f "scripts/olist/star/12_build_facts.sql"

echo "[4/4] Creating indexes, analyze and checks..."
"${psql_base[@]}" -f "scripts/olist/star/13_indexes_analyze_checks.sql"

echo "Star schema build finalizado com sucesso."
