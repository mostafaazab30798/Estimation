# Runs the online play load test against staging.
# Fetches the service role key via Supabase CLI (never written to disk).

param(
    [int]$Users = 50,
    [int]$Duration = 90,
    [string]$EnvFile = "config/env.staging.json",
    [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$envJson = Get-Content $EnvFile | ConvertFrom-Json
$projectRef = ([uri]$envJson.SUPABASE_URL).Host.Split('.')[0]
if (-not $projectRef) {
    throw "Could not parse project ref from $EnvFile"
}

Write-Host "Fetching service role key for project $projectRef ..."
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$keys = supabase projects api-keys --project-ref $projectRef 2>&1 | Out-String
$ErrorActionPreference = $prevEap
$serviceLine = ($keys -split "`n" | Where-Object { $_ -match 'service_role\s*\|' } | Select-Object -First 1)
if (-not $serviceLine) {
    throw "Could not read service_role key from Supabase CLI. Run: supabase login"
}
$serviceKey = ($serviceLine -split '\|', 2)[1].Trim()

$env:SUPABASE_SERVICE_ROLE_KEY = $serviceKey
if ($SkipCleanup) {
    $env:LOAD_TEST_SKIP_CLEANUP = "1"
}

Write-Host "Starting load test: $Users users, ${Duration}s play window ..."
deno run --allow-net --allow-env --allow-read --allow-write `
    scripts/load-test-online-play.ts `
    --users $Users `
    --duration $Duration `
    --env $EnvFile

exit $LASTEXITCODE
