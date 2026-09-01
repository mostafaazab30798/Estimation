# Copy example env files to gitignored local configs (safe to re-run).
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

function Copy-IfMissing($example, $target) {
    if (Test-Path $target) {
        Write-Host "skip $target (already exists)"
    } else {
        Copy-Item $example $target
        Write-Host "created $target from $example"
    }
}

Copy-IfMissing "config/env.prod.example.json" "config/env.prod.json"
Copy-IfMissing "config/env.staging.example.json" "config/env.staging.json"
Copy-IfMissing "config/env.dev.example.json" "config/env.dev.json"

Write-Host ""
Write-Host "Edit config/env.staging.json with your staging Supabase project before QA builds."
Write-Host "Run: flutter run --flavor prod --dart-define-from-file=config/env.prod.json"
