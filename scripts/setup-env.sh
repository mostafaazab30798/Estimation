#!/usr/bin/env bash
# Copy example env files to gitignored local configs (safe to re-run).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

copy_if_missing() {
  local example="$1"
  local target="$2"
  if [ -f "$target" ]; then
    echo "skip $target (already exists)"
  else
    cp "$example" "$target"
    echo "created $target from $example"
  fi
}

copy_if_missing config/env.prod.example.json config/env.prod.json
copy_if_missing config/env.staging.example.json config/env.staging.json
copy_if_missing config/env.dev.example.json config/env.dev.json

echo ""
echo "Edit config/env.staging.json with your staging Supabase project before QA builds."
echo "Run: flutter run --flavor prod --dart-define-from-file=config/env.prod.json"
