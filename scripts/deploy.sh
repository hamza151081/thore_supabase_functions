#!/usr/bin/env bash
set -euo pipefail

# 1) Build a migration from db/ (pass a name like "missions_view_rpc")
./scripts/build-migration.sh "${1:-deploy}"

# 2) Push migrations to the linked Supabase project
supabase db push

# 3) Deploy all Edge Functions (optional)
for d in edge-functions/* ; do
  [ -d "$d" ] && supabase functions deploy "$(basename "$d")"
done
