#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_DIR="$PROJECT_DIR/backend"
ENV_FILE="$BACKEND_DIR/.env.local"
SQL_DUMP="${BANG9_SQL_DUMP:-/Volumes/HP USB321FD/캡스톤디자인_5조/코드/SQL문.sql}"
CONTAINER_NAME="bang9-portfolio-db"
VOLUME_NAME="bang9-portfolio-db-data"
PYTHON_BIN="${BANG9_PYTHON_BIN:-/Users/yeoduchi/.cache/bang9-portfolio/venv/bin/python}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE. Copy backend/.env.example first."
  exit 1
fi

if [[ ! -f "$SQL_DUMP" ]]; then
  echo "SQL dump not found: $SQL_DUMP"
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

if ! docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  docker run -d \
    --name "$CONTAINER_NAME" \
    -e MARIADB_ROOT_PASSWORD="$DB_ROOT_PASSWORD" \
    -e MARIADB_DATABASE="$DB_NAME" \
    -e MARIADB_USER="$DB_USER" \
    -e MARIADB_PASSWORD="$DB_PASSWORD" \
    -p "${DB_PORT}:3306" \
    -v "${VOLUME_NAME}:/var/lib/mysql" \
    mariadb:11.3 >/dev/null
else
  docker start "$CONTAINER_NAME" >/dev/null
fi

echo "Waiting for local MariaDB..."
for _ in {1..60}; do
  if docker exec \
    -e MYSQL_PWD="$DB_PASSWORD" \
    "$CONTAINER_NAME" \
    mariadb-admin ping -h 127.0.0.1 -u "$DB_USER" --silent >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

TABLE_EXISTS="$(
  docker exec \
    -e MYSQL_PWD="$DB_PASSWORD" \
    "$CONTAINER_NAME" \
    mariadb -N -u "$DB_USER" "$DB_NAME" \
    -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}' AND table_name='users';"
)"

if [[ "$TABLE_EXISTS" != "1" ]]; then
  echo "Importing the USB snapshot into local MariaDB..."
  docker exec -i \
    -e MYSQL_PWD="$DB_PASSWORD" \
    "$CONTAINER_NAME" \
    mariadb -u "$DB_USER" "$DB_NAME" < "$SQL_DUMP"
else
  echo "Existing bang9_db snapshot found; import skipped."
fi

"$PYTHON_BIN" "$BACKEND_DIR/scripts/seed_portfolio_demo.py"
echo "Bang9 portfolio database is ready on 127.0.0.1:${DB_PORT}."
