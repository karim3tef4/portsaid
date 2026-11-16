#!/usr/bin/env bash
# Applies stub + migrations + seed to a throwaway database and runs the RLS test suite.
set -euo pipefail
cd "$(dirname "$0")/.."
DB=${TEST_DB:-psh_test}
if [ "$(id -u)" = 0 ] && ! su postgres -c "pg_isready -q"; then service postgresql start >/dev/null 2>&1; sleep 4; fi
PSQL="psql -v ON_ERROR_STOP=1 -q -X"
[ "$(id -u)" = 0 ] && PSQL="su postgres -c" || true
run() { if [ "$(id -u)" = 0 ]; then su postgres -c "psql -v ON_ERROR_STOP=1 -q -X $1"; else psql -v ON_ERROR_STOP=1 -q -X "$@"; fi; }
if [ "$(id -u)" = 0 ]; then
  su postgres -c "psql -q -X -c 'drop database if exists $DB' -c 'create database $DB'"
  for f in tests/db/00_supabase_stub.sql supabase/migrations/*.sql supabase/seed.sql tests/db/10_rls.test.sql; do
    echo "→ $f"; su postgres -c "psql -v ON_ERROR_STOP=1 -q -X -d $DB -f $PWD/$f"
  done
else
  psql -q -X -c "drop database if exists $DB" -c "create database $DB"
  for f in tests/db/00_supabase_stub.sql supabase/migrations/*.sql supabase/seed.sql tests/db/10_rls.test.sql; do
    echo "→ $f"; psql -v ON_ERROR_STOP=1 -q -X -d "$DB" -f "$f"
  done
fi
echo "DB tests passed"
