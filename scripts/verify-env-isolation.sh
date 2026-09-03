#!/usr/bin/env bash
# W1.10 — Verify staging/prod config templates and release workflow isolation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FAIL=0

PROD_URL=$(grep -o '"SUPABASE_URL"[[:space:]]*:[[:space:]]*"[^"]*"' config/env.prod.example.json | sed 's/.*: *"\([^"]*\)"/\1/')
STAGING_URL=$(grep -o '"SUPABASE_URL"[[:space:]]*:[[:space:]]*"[^"]*"' config/env.staging.example.json | sed 's/.*: *"\([^"]*\)"/\1/')

if [ "$PROD_URL" = "$STAGING_URL" ]; then
  echo "ERROR: prod and staging example URLs must differ"
  FAIL=1
fi

if echo "$STAGING_URL" | grep -q 'eqmkbfxerxqihforsgvx'; then
  echo "ERROR: staging example must not reference production project ref"
  FAIL=1
fi

if ! grep -q '\-\-flavor prod' .github/workflows/play-release.yml; then
  echo "ERROR: play-release.yml must build with --flavor prod"
  FAIL=1
fi

if ! grep -q 'SUPABASE_URL' .github/workflows/play-release.yml; then
  echo "ERROR: play-release.yml must pass SUPABASE_URL dart-define"
  FAIL=1
fi

if ! grep -q '\-\-flavor prod' .github/workflows/release.yml; then
  echo "ERROR: release.yml must build with --flavor prod"
  FAIL=1
fi

if ! grep -q 'SUPABASE_URL' .github/workflows/release.yml; then
  echo "ERROR: release.yml must pass SUPABASE_URL dart-define"
  FAIL=1
fi

if ! grep -q 'AppConfig' lib/main.dart; then
  echo "ERROR: main.dart must initialize Supabase via AppConfig"
  FAIL=1
fi

if [ ! -f supabase/tests/database/env_isolation.test.sql ]; then
  echo "ERROR: missing supabase/tests/database/env_isolation.test.sql"
  FAIL=1
fi

if ! grep -q 'W1.10' supabase/tests/database/env_isolation.test.sql 2>/dev/null; then
  echo "ERROR: env_isolation pgTAP suite must document W1.10"
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi

echo "OK: env isolation templates and release workflow checks passed"
