#!/usr/bin/env bash
# W1.10 — Fail CI if client bundle sources reference service-role material.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FAIL=0

if rg -n "service_role|SERVICE_ROLE|sb_secret" lib test --glob '*.dart' 2>/dev/null; then
  echo "ERROR: service-role pattern found in Dart sources"
  FAIL=1
fi

if rg -n "supabase\.co" lib --glob '*.dart' 2>/dev/null; then
  echo "ERROR: hardcoded Supabase URL in lib/ (use AppConfig + dart-define)"
  FAIL=1
fi

if rg -n "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\.eyJpc3MiOiJzdXBhYmFzZS" lib --glob '*.dart' 2>/dev/null; then
  echo "ERROR: hardcoded JWT anon key in lib/"
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi

echo "OK: no client secret / hardcoded prod URL violations"