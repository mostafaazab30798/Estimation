# Phase 4 — Controlled Play rollout

> **Source:** [Google Play Deep Audit 2026-08-31](../GOOGLE_PLAY_DEEP_AUDIT_2026-08-31.md) · **Phase objective (verbatim):** "Complete store declarations/assets, internal and closed testing, resolve pre-launch reports, stage production gradually, and monitor vitals/support before expanding."

Everything technical is done and proven by now. This phase is the **store + operations** work: create the app correctly in Play Console, declare data/policy honestly, ship through internal → closed → staged production gates, and watch vitals. Most items are Play Console actions, not code — the progress report should capture screenshots/console links/dates as evidence.

## 📋 Mandatory reporting requirement — read first

After **every** work session and immediately after completing any single work item, create/update **`plans/progress/phase-4-progress.md`** (copy from [`progress/_TEMPLATE.md`](progress/_TEMPLATE.md)). A reader who sees only that file must know what's done, verified (with real evidence — Play Console screenshots/links, track names, tester counts + dates, pre-launch report status, rollout %), remaining, blocked. No claim without evidence. State skips/partials; report failures honestly.

> **Hard gate:** Do not start Phase 4 production steps until **all of the Definition of Ready** (see [README](README.md)) is met — every P0 closed with evidence, all P1 security closed, signed API-36 AAB passing internal testing, no private-card leak, no client-forgeable results, account deletion working, disclosures matching behavior, device matrix meeting budgets.

## Findings / checklist covered

| Source | Item |
|---|---|
| Store & operational checklist | App creation + App Signing enrollment |
| Store & operational checklist | Internal testing upload + pre-launch resolution |
| Store & operational checklist | Privacy/deletion URLs, Data Safety, content rating/IARC, target audience, ads declaration, app-access/reviewer notes, contact |
| Store & operational checklist | Store listing assets (icon, feature graphic, screenshots, descriptions, localized text) |
| Store & operational checklist | Real-money gambling declaration (none, if true) |
| Store & operational checklist | Closed test: 12+ testers for 14 continuous days (personal accounts created after 2023-11-13) |
| Store & operational checklist | Developer identity/device verification |
| Store & operational checklist | Rollout gates, rollback criteria, support ownership, incident response, DB backup/restore, key/account recovery |
| Store & operational checklist | Re-check target API policy immediately before submission |

> **Depends on:** Phase 0 (signed AAB, privacy policy, deletion URLs, Data Safety answers, UGC decision), Phase 3 (crash/ANR instrumentation for vitals, device-matrix evidence, pre-launch readiness).

---

## Work items

### W4.1 — Create the app + enroll in Play App Signing

**Tasks**
1. Create the app in Play Console with the exact final package ID **`com.mostafaazab.estimation`** (confirm ownership/uniqueness — this was the one open item on the "Package identity" gate).
2. Enroll in **Play App Signing**; register the upload certificate whose SHA-256 you recorded in [Phase 0](phase-0-play-safe-artifact.md) W0.2.

**Validation:** App exists under the correct ID; App Signing enrolled; upload cert digest matches Phase 0.

---

### W4.2 — Internal testing + pre-launch report

**Tasks**
1. Upload the signed AAB ([Phase 0](phase-0-play-safe-artifact.md) W0.3) to the **internal testing** track.
2. Run and **resolve every** pre-launch, policy, SDK, and device-catalog issue.

**Validation:** Play Console accepts `app-release.aab`; version code ≥ 22 (monotonic), target API 36, correct signer, no forbidden permission (proves [Phase 0](phase-0-play-safe-artifact.md) W0.1/W0.2/W0.3 in the real console). Pre-launch report is clean or every item is triaged with a recorded resolution.

---

### W4.3 — Data Safety, privacy, content rating, and declarations

**Tasks**
1. Supply the **privacy-policy URL** and **account-deletion URL** (in-app + web) from [Phase 0](phase-0-play-safe-artifact.md) W0.4.
2. Complete the **Data Safety** form from the authored answers ([Phase 0](phase-0-play-safe-artifact.md) W0.4) — include the diagnostics SDK if added in [Phase 3](phase-3-device-quality.md) W3.1.
3. Complete **content rating / IARC** answers accurately; answer card-game/content questions honestly.
4. Declare **no real-money gambling** if that remains true.
5. Complete **target-audience**, **ads declaration** (no ads, per audit), **app-access / reviewer instructions** (how to reach multiplayer, test accounts), and **contact details**.

**Validation:** Every declaration matches actual production behavior (the audit's central privacy requirement). Data Safety reflects the real data map + all SDKs.

References: [User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en) · [Data Safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en) · [Account deletion](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en-EN)

---

### W4.4 — Store listing assets

**Tasks**
1. High-resolution icon, feature graphic, screenshots for **every supported form factor** (phone + tablet/foldable — matches [Phase 3](phase-3-device-quality.md) matrix).
2. Descriptions + localized listing text (AR/EN — matches [Phase 3](phase-3-device-quality.md) W3.3 locales).
3. Ensure screenshots reflect **actual** functionality.

**Validation:** Listing complete for all form factors; screenshots are genuine, not mocked.

---

### W4.5 — Closed testing (if required)

**Why:** Personal developer accounts created after **2023-11-13** must run a closed test with **≥ 12 opted-in testers continuously for 14 days** before applying for production.

**Tasks**
1. Determine account type/creation date (record it).
2. If required: recruit 12+ testers, run the closed track continuously for 14 days, keep engagement evidence.

**Validation:** If applicable, 12+ testers active across 14 continuous days; screenshots/dates recorded. If not applicable, record why.

Ref: <https://support.google.com/googleplay/android-developer/answer/14151465?hl=en-GB>

---

### W4.6 — Developer identity/device verification

**Why:** Android developer verification enforcement begins in selected regions on **2026-09-30** and expands later.

**Tasks**
1. Complete developer identity/device verification where applicable to the account/regions.

**Validation:** Verification complete or explicitly not-yet-required for the account's regions (record which).

Refs: [developer verification](https://support.google.com/android-developer-console/answer/16561738?hl=en) · [Play Console requirements](https://support.google.com/googleplay/android-developer/answer/10788890?hl=en)

---

### W4.7 — Rollout gates + operations runbook

**Tasks**
1. Define internal → closed → **staged production** rollout gates with explicit **rollback criteria**.
2. Assign **support ownership**, an **incident-response** path, **database backup/restore** procedure, and **key/account recovery** (extends [Phase 0](phase-0-play-safe-artifact.md) W0.2 `SIGNING.md`).
3. Document how vitals/support are watched before expanding rollout ([Phase 3](phase-3-device-quality.md) W3.1 instrumentation feeds this).

**Validation:** A written runbook exists covering gates, rollback, support, incident response, backup/restore, recovery.

---

### W4.8 — Final pre-submission policy re-check

**Why:** Play's target API and other policies change; verify immediately before submission (audit note: as of audit date, new apps + updates must target Android 16 / API 36 — the app is at 36).

**Tasks**
1. Re-read Play's current target API + related policies right before submitting.
2. Confirm nothing regressed since Phase 0–3 (permissions, signing, disclosures).

**Validation:** Target API still compliant at submission time; a final checklist pass confirms no regression.

Ref: <https://support.google.com/googleplay/android-developer/answer/11926878?hl=en>

---

### W4.9 — Staged production + vitals watch

**Tasks**
1. Promote to production on a **gradual staged rollout**.
2. Monitor **Play vitals** (crash/ANR) by device + version ([Phase 3](phase-3-device-quality.md) thresholds) and support channels.
3. Expand rollout only when vitals stay materially below Play thresholds; use rollback criteria (W4.7) otherwise.

**Validation:** Staged rollout started at a low %; vitals dashboard shows crash < 1.09% / ANR < 0.47% (target well below) before each expansion; rollback path exercised or confirmed ready.

---

## Phase 4 exit criteria (= launch)

Close only with Play Console evidence in `plans/progress/phase-4-progress.md`:

- [ ] App created under `com.mostafaazab.estimation`; Play App Signing enrolled; upload cert matches Phase 0 (W4.1).
- [ ] Signed AAB on internal track; pre-launch report clean/triaged (W4.2).
- [ ] Privacy + deletion URLs supplied; Data Safety + content rating + all declarations match production behavior (W4.3).
- [ ] Listing assets complete for all form factors; screenshots genuine (W4.4).
- [ ] Closed test satisfied (12+ testers / 14 days) or documented not-required (W4.5).
- [ ] Developer verification complete or documented not-yet-required (W4.6).
- [ ] Rollout/rollback/support/incident/backup/recovery runbook written (W4.7).
- [ ] Final policy re-check passed at submission time (W4.8).
- [ ] Staged production live; vitals below thresholds before each expansion (W4.9).

---

## 📋 Reporting requirement (repeat)

Keep `plans/progress/phase-4-progress.md` current after every session and every completed item — with Play Console evidence (links/screenshots, track names, tester counts + dates, pre-launch status, rollout %, vitals numbers). No claim without evidence; report blockers (e.g. awaiting console access, tester recruitment) honestly.
