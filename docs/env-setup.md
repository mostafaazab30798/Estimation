# Environment setup (W0.9 / W1.10)

The Flutter client selects its Supabase project at **build time** via `--dart-define` or `--dart-define-from-file`. Staging and production must never share a project.

## One-time setup

```powershell
# Windows
.\scripts\setup-env.ps1

# macOS / Linux
./scripts/setup-env.sh
```

This creates gitignored `config/env.{prod,staging,dev}.json` from the `*.example.json` templates.

**Before staging QA:** edit `config/env.staging.json` with a **separate** Supabase project (not production).

## Run locally

```bash
flutter run --flavor prod --dart-define-from-file=config/env.prod.json
```

VS Code / Cursor: use the **prod (env file)** launch configuration in `.vscode/launch.json`.

## Environments

| File | `APP_ENV` | Application ID (Android) |
|------|-----------|--------------------------|
| `config/env.dev.json` | `dev` | `…estimation.dev` |
| `config/env.staging.json` | `staging` | `…estimation.staging` |
| `config/env.prod.json` | `production` | `…estimation` |

## W1.10 exit criteria (evidence)

```powershell
# Windows (uses bash when available)
.\scripts\verify-w1.10.ps1
```

```bash
# macOS / Linux / CI
bash scripts/verify-client-secrets.sh
bash scripts/verify-env-isolation.sh
```

## GitHub secrets (production environment)

Required for Play release workflow:

| Secret | Purpose |
|--------|---------|
| `SUPABASE_URL` | Production project URL |
| `SUPABASE_ANON_KEY` | Production anon key (public, but env-scoped) |
| Signing secrets | `ANDROID_KEYSTORE_BASE64`, etc. (existing) |

Release build command (automated in CI):

```bash
flutter build appbundle --release --flavor prod \
  --dart-define=APP_ENV=production \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=PROD_PROJECT_REF=eqmkbfxerxqihforsgvx \
  --dart-define=SERVER_AUTHORITY=true
```

Never add `SUPABASE_SERVICE_ROLE_KEY` to the mobile client or Play workflow.

## Staging guard

If `APP_ENV=staging` and `SUPABASE_URL` contains the production project ref (`eqmkbfxerxqihforsgvx`), the app **refuses to start**. This prevents accidental QA against live player data.
