#!/usr/bin/env bash
set -euo pipefail

NAME="${1:-update}"
STAMP="$(date '+%Y%m%d%H%M%S')"
OUT="supabase/migrations/${STAMP}_${NAME}.sql"

mkdir -p supabase/migrations

# Order matters: tables → functions → views → triggers
cat /dev/null > "$OUT"

append_dir () {
  local DIR="$1"
  if [ -d "$DIR" ]; then
    # sort for deterministic order (handles 001_*, 010_* naming)
    while IFS= read -r -d '' f; do
      echo "-- >>> ${f}" >> "$OUT"
      cat "$f" >> "$OUT"
      echo -e "\n" >> "$OUT"
    done < <(find "$DIR" -type f -name '*.sql' -print0 | sort -z)
  fi
}

echo "-- Generated from db/ on $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$OUT"
echo "BEGIN;" >> "$OUT"

append_dir "db/tables"
append_dir "db/functions"
append_dir "db/views"
append_dir "db/triggers"

echo "COMMIT;" >> "$OUT"

echo "✅ Created migration: $OUT"
