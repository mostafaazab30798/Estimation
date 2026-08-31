# Progress — Phase 0: Make a Play-safe artifact

> Update after every work session and immediately after completing any work item.

---

## At a glance

- **Phase:** 0 — Make a Play-safe artifact
- **Plan file:** `plans/phase-0-play-safe-artifact.md`
- **Overall status:** In progress
- **Last updated:** 2026-08-31 12:25 (UTC+3)
- **Updated by:** Auto (Cursor agent)
- **Branch(es):** (working tree, uncommitted)
- **% exit criteria met:** 6 of 10 (partial on several)

## Decisions & assumptions

- **W0.8 — Path B chosen:** Keep gallery photos + display names with full safeguards (terms, validation, report/block, sanitized multiplayer avatars).
- **W0.4 hosting:** Use standalone static `legal-site/` at `legal.hope-tv.site` — **no changes to the Flutter web app**.
- **Signing:** User confirmed GitHub `production` secrets are configured; `play-release` workflow ready to run.

## Work-item status

| Item | Finding(s) | Status | Evidence | Notes |
|------|-----------|--------|----------|-------|
| W0.1 | P0-01 | Done | Source manifest clean; updater removed | Merged AAB manifest still unverified |
| W0.2 | P0-02 | Partial | Fail-closed Gradle + workflow; `android/SIGNING.md` | Run `play-release` to capture signer SHA-256 |
| W0.3 | P0-03 | Partial | `.github/workflows/play-release.yml` | User has secrets; dispatch workflow to produce AAB |
| W0.4 | P0-07 | Partial | In-app deletion + legal-site pages; migration **applied** | Deploy `legal-site/terms/`; e2e deletion test |
| W0.5 | hygiene | Partial | `flutter analyze` clean; `ci.yml` | `release.yml` not fully pinned |
| W0.6 | P2-10 | Done | No duplicate version constant; CI monotonic check | |
| W0.7 | P2-11 | Not started | — | SBOM, licenses, asset provenance |
| W0.8 | P0-08 | Partial | Path B in app + migration **applied** | Live test report/block |
| W0.9 | — | Not started | — | Env/flavor separation |

## What was done this session (2026-08-31 afternoon)

### W0.8 — Path B (UGC safeguards)
- Terms acceptance gate before name change / gallery upload (`_ensureTermsAccepted`, `UgcService.acceptTerms`).
- Client name validation (`DisplayNameValidator`) + server trigger in migration.
- Report + block UI (`user_safety_sheet.dart`): long-press on leaderboard rows and in-game player cards.
- Multiplayer photo sanitization: `ProfileService.publicAvatarRef()` → `ugc:custom` (no base64 over network) in `game_client`, `game_server`, `local_game_*`.
- `public_profiles` view + leaderboard queries exclude email; blocked users filtered from leaderboard.
- Community guidelines page: `legal-site/terms/index.html`.

### W0.4 — Privacy / deletion (Android-only, no Flutter web changes)
- In-app account deletion: Profile → Settings → Delete account → type `DELETE` → Google re-auth → `delete_user_account` RPC.
- Existing static legal site unchanged in architecture; updated `account-deletion/index.html` to document in-app route.
- Privacy policy + terms links remain in Settings (external `legal.hope-tv.site`).

### Backend
- Migration `202608310001_ugc_moderation_and_deletion.sql` — **applied** (user, 2026-08-31).

## Commands run + real output

```
$ flutter analyze
No issues found! (ran in 9.6s)
Exit code: 0

$ flutter test
00:33 +204: All tests passed!
Exit code: 0
```

## Validation evidence per exit criterion

| Exit criterion | Met? | Evidence |
|----------------|------|----------|
| No `REQUEST_INSTALL_PACKAGES` / FileProvider (W0.1) | Partial | Source manifest clean; AAB merge pending |
| In-app updater gone (W0.1) | Yes | Files deleted |
| Fail-closed signing + signer digest (W0.2) | Partial | Code ready; user has secrets — run workflow |
| Signed AAB workflow (W0.3) | Partial | `play-release.yml`; not executed yet |
| Privacy + deletion + data map (W0.4) | Partial | Migration applied; legal-site deploy + live deletion test pending |
| Analyzer + CI hygiene (W0.5) | Partial | Analyzer clean; `ci.yml` |
| Version metadata + monotonic CI (W0.6) | Yes | |
| SBOM + licenses + provenance (W0.7) | No | |
| UGC Path B (W0.8) | Partial | Migration applied; live report/block test pending |
| Env/flavor separation (W0.9) | No | |

## Blockers & open questions

1. ~~**Apply Supabase migration**~~ — **Done** (user, 2026-08-31).
2. **Deploy** `legal-site/terms/` to Cloudflare Pages (`legal.hope-tv.site/terms/`).
3. **Run** GitHub Actions `Play Release (AAB)` workflow to validate signing + produce AAB.
4. **End-to-end test** account deletion + report/block on throwaway Google account.

## What's left / next steps

1. Smoke-test UGC + deletion (see Phase 1 progress checklist).
2. Deploy legal-site (terms page).
3. Dispatch `play-release` workflow — capture AAB + signer SHA-256.
4. W0.7 SBOM/licenses/asset provenance.
5. W0.9 environment/flavor separation.

## Changelog

- **2026-08-31 PM** — User — Applied migration `202608310001` to Supabase.
- **2026-08-31 PM** — Auto — Progress updated after migration apply.
- **2026-08-31 PM** — Auto — Path B UGC safeguards, in-app deletion, photo sanitization, legal terms page; migration authored.
- **2026-08-31 AM** — Auto — W0.1, W0.6 done; partial W0.2, W0.3, W0.5.
