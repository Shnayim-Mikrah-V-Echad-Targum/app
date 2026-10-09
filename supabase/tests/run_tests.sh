#!/usr/bin/env bash
# Applies the Supabase migrations to a throwaway PostgreSQL server (with a
# small stub for Supabase's auth schema and roles) and runs behavior tests.
#
#   supabase/tests/run_tests.sh
#
# Needs PostgreSQL 15+ server binaries (initdb, pg_ctl, postgres) and psql.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
bindir="${PG_BINDIR:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}"
work="$(mktemp -d)"
port="${PG_TEST_PORT:-54329}"
run_as=()
if [ "$(id -u)" = 0 ]; then
  chown postgres "$work"
  run_as=(runuser -u postgres --)
fi
cleanup() {
  "${run_as[@]}" "$bindir/pg_ctl" -D "$work/data" -m immediate stop >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

"${run_as[@]}" "$bindir/initdb" -D "$work/data" -U postgres --encoding=UTF8 --locale=C.UTF-8 >/dev/null
"${run_as[@]}" "$bindir/pg_ctl" -D "$work/data" -o "-p $port -k $work -c listen_addresses=''" -l "$work/log" -w start >/dev/null

psql_cmd=(psql -h "$work" -p "$port" -U postgres -d postgres -v ON_ERROR_STOP=1 -q)
"${run_as[@]}" "${psql_cmd[@]}" -f "$here/supabase_stub.sql"
for f in "$root"/supabase/migrations/*.sql; do
  echo "applying $(basename "$f")"
  "${run_as[@]}" "${psql_cmd[@]}" -f "$f"
done
"${run_as[@]}" "${psql_cmd[@]}" -f "$here/behavior.sql" 2>&1 | sed 's/^psql:[^ ]* NOTICE:  /  /'
