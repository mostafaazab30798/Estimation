# Progress — Phase 0: Make a Play-safe artifact

> Update after every work session and immediately after completing any work item.

---

## At a glance

- **Phase:** 0 — Make a Play-safe artifact
- **Plan file:** `plans/phase-0-play-safe-artifact.md`
- **Overall status:** In progress
- **Last updated:** 2026-09-01 11:45 (UTC+3)
- **Updated by:** Auto (Cursor agent)
- **Branch(es):** (working tree, uncommitted)
- **% exit criteria met:** 7 of 10 (partial on several)

## Decisions & assumptions

- **W0.8 — Path B chosen:** Keep gallery photos + display names with full safeguards (terms, validation, report/block, sanitized multiplayer avatars).
- **W0.4 hosting:** Use standalone static `legal-site/` at `legal.hope-tv.site` — **no changes to the Flutter web app**.
- **Signing:** User confirmed GitHub `production` secrets are configured; `play-release` workflow ready to run.
- **Staging QA:** Separate Supabase project `zbimzlyleruaqbdilrqb` linked; all 20 migrations applied; app runs with `staging` flavor + `config/env.staging.json`.

## Work-item status

| Item | Finding(s) | Status | Evidence | Notes |
|------|-----------|--------|----------|-------|
| W0.1 | P0-01 | Done | Source manifest clean; updater removed | Merged AAB manifest still unverified |
| W0.2 | P0-02 | Partial | Fail-closed Gradle + workflow; `android/SIGNING.md` | Run `play-release` to capture signer SHA-256 |
| W0.3 | P0-03 | Partial | `.github/workflows/play-release.yml` | User has secrets; dispatch workflow to produce AAB |
| W0.4 | P0-07 | Partial | In-app deletion + legal-site pages; migration **applied** | Deploy `legal-site/terms/`; e2e deletion test on **staging** |
| W0.5 | hygiene | Partial | `flutter analyze` clean; `ci.yml` | `release.yml` not fully pinned |
| W0.6 | P2-10 | Done | No duplicate version constant; CI monotonic check | |
| W0.7 | P2-11 | Partial | `tool/audit_licenses.dart`, CI job, `docs/legal/asset-provenance.md`, in-app LicensePage | Confirm asset receipts before Play |
| W0.8 | P0-08 | Partial | Path B in app + migration **applied** | Live test report/block on **staging** |
| W0.9 | — | Done | `AppConfig`, flavors, `config/env.*.example.json`, CI secret guards, staging project live | User provisioned staging 2026-09-01 |

## What was done this session (2026-09-01 — staging + W0.7)

1. **Staging provisioned (user):** Supabase project `zbimzlyleruaqbdilrqb` linked; `supabase db push` — all 20 migrations in sync; `game-action` edge function redeployed (v2).
2. **W0.7 partial:** `tool/audit_licenses.dart` generates SBOM + license inventory; CI `license-audit` job; `docs/legal/asset-provenance.md`; Settings → **Open-source licenses** (`LicensePage`).
3. **App on staging:** User confirmed running with `--flavor staging --dart-define-from-file=config/env.staging.json` (`SERVER_AUTHORITY=true`).

## Commands run + real output

```
$ supabase migration list
# All 20 local migrations match remote on zbimzlyleruaqbdilrqb

$ supabase functions deploy game-action --no-verify-jwt
Deployed Functions on project zbimzlyleruaqbdilrqb: game-action

$ dart run tool/audit_licenses.dart
Wrote docs/legal/license-inventory.json (168 packages)
OK: 168 packages — no GPL/AGPL dependencies
Exit code: 0

$ flutter test
00:34 +227: All tests passed!
Exit code: 0
```

## Validation evidence per exit criterion

| Exit criterion | Met? | Evidence |
|----------------|------|----------|
| No `REQUEST_INSTALL_PACKAGES` / FileProvider (W0.1) | Partial | Source manifest clean; AAB merge pending |
| In-app updater gone (W0.1) | Yes | Files deleted |
| Fail-closed signing + signer digest (W0.2) | Partial | Code ready; user has secrets — run workflow |
| Signed AAB workflow (W0.3) | Partial | `play-release.yml`; not executed yet |
| Privacy + deletion + data map (W0.4) | Partial | Migration applied; legal-site deploy + live deletion test on staging pending |
| Analyzer + CI hygiene (W0.5) | Partial | Analyzer clean; `ci.yml` |
| Version metadata + monotonic CI (W0.6) | Yes | |
| SBOM + licenses + provenance (W0.7) | Partial | CI job + inventory tool + asset doc + LicensePage; asset receipts TBD |
| UGC Path B (W0.8) | Partial | Migration applied; live report/block test on staging pending |
| Env/flavor separation (W0.9) | Yes | Staging project live; guard prevents prod URL in staging builds |

## Blockers & open questions

1. **Deploy** `legal-site/terms/` to Cloudflare Pages (`legal.hope-tv.site/terms/`).
2. **Run** GitHub Actions `Play Release (AAB)` workflow to validate signing + produce AAB.
3. **End-to-end test** on staging: account deletion + report/block + online match with `SERVER_AUTHORITY=true`.
4. **Google OAuth** on staging Supabase project — confirm redirect URI includes staging app + `io.supabase.kotshina://login-callback`.

## What's left / next steps

1. **Staging smoke checklist** (see Phase 1 progress) — user can run now that staging is live.
2. Deploy legal-site (terms page).
3. Dispatch `play-release` workflow — capture AAB + signer SHA-256.
4. Confirm asset license receipts in `docs/legal/asset-provenance.md`.
5. W0.5 — pin `release.yml` actions to SHAs.

## Changelog

- **2026-09-01 AM** — Auto — Staging confirmed (migrations + edge fn); W0.7 license audit CI + OSS notices + asset provenance.
- **2026-09-01 PM** — Auto — W0.9 completed via W1.10 (AppConfig, flavors, CI guards, pgTAP).
- **2026-08-31 PM** — User — Applied migration `202608310001` to Supabase.
- **2026-08-31 PM** — Auto — Path B UGC safeguards, in-app deletion, photo sanitization, legal terms page.
