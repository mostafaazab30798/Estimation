#!/usr/bin/env bash
# Apply all migrations to local Supabase and run the RLS security matrix (W1.6).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Starting Supabase (requires Docker)..."
supabase start -x edge-runtime,imgproxy,mailpit,storage-api,vector,realtime

echo "Resetting database from supabase/migrations..."
supabase db reset

echo "Running RLS pgTAP tests..."
supabase test db

echo "RLS matrix passed."
