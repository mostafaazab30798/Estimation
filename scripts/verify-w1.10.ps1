# W1.10 — Run client secret + env isolation checks (Windows-friendly).
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (Get-Command bash -ErrorAction SilentlyContinue) {
    bash scripts/verify-client-secrets.sh
    bash scripts/verify-env-isolation.sh
    exit $LASTEXITCODE
}

Write-Host "bash not found; running PowerShell fallback checks..."

$fail = 0

$dartFiles = Get-ChildItem -Path lib,test -Filter *.dart -Recurse -ErrorAction SilentlyContinue
foreach ($pattern in @('service_role', 'SERVICE_ROLE', 'sb_secret')) {
    $hits = $dartFiles | Select-String -Pattern $pattern -SimpleMatch
    if ($hits) {
        Write-Host "ERROR: $pattern found in Dart sources"
        $hits | ForEach-Object { Write-Host $_.Line }
        $fail = 1
    }
}

$libHits = Get-ChildItem lib -Filter *.dart -Recurse | Select-String -Pattern 'supabase\.co'
if ($libHits) {
    Write-Host "ERROR: hardcoded Supabase URL in lib/"
    $fail = 1
}

if (-not (Select-String -Path lib/main.dart -Pattern 'AppConfig' -Quiet)) {
    Write-Host "ERROR: main.dart must initialize Supabase via AppConfig"
    $fail = 1
}

if ($fail -ne 0) { exit 1 }
Write-Host "OK: W1.10 PowerShell fallback checks passed"
