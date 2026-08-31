# Phase 0 — Make a Play-safe artifact

> **Source:** [Google Play Deep Audit 2026-08-31](../GOOGLE_PLAY_DEEP_AUDIT_2026-08-31.md) · **Phase objective (verbatim):** "Remove the sideload updater and restricted permission; implement fail-closed upload signing; build a current AAB; add test/analyze/artifact verification gates; establish privacy policy, Data Safety inventory, and account deletion."

**This phase blocks submission. Do it first.** It removes the two hard policy rejections (restricted install permission + fail-open signing), produces a real signed App Bundle, wires the CI gates that keep the artifact clean, and stands up the privacy/deletion/UGC obligations Play requires before an app that has accounts can ship.

## 📋 Mandatory reporting requirement — read first

After **every** work session, and immediately after completing any single work item below, create/update **`plans/progress/phase-0-progress.md`** (copy from [`progress/_TEMPLATE.md`](progress/_TEMPLATE.md)). It must let a reader who sees only that file know what is done, verified (with real command output — signer digests, `flutter analyze` results, build results), remaining, and blocked. Never mark a task done without an evidence line. State skips/partials explicitly; report failures with their output. This is how the user keeps up — treat it as part of "done", not paperwork.

## Findings covered

| Finding | Title | Gate |
|---|---|---|
| P0-01 | APK self-update flow conflicts with Play policy | Restricted permissions |
| P0-02 | Release signing fails open to the debug key | Release signing |
| P0-03 | No Play AAB release path | Android App Bundle |
| P0-07 | Privacy policy, Data Safety, account deletion incomplete | Privacy / Data Safety / Account deletion |
| P0-08 | UGC safeguards missing | UGC |
| P2-10 | Version duplicated; update parsing fragile | (hygiene) |
| P2-11 | Dependency / license / content-rights review absent | (hygiene) |
| — | Analyzer treated as pass despite non-zero exit; archives/logs in VCS; floating Flutter + unpinned actions; over-broad workflow; no env/flavor separation | (hygiene) |

> **Overlap note:** environment/flavor separation and hardcoded-key handling are *started* here (build config) and *completed* in [Phase 1](phase-1-trust-boundaries.md) (data-trust). Account-deletion **backend** correctness depends on [Phase 1](phase-1-trust-boundaries.md) RLS; deletion **UX + web endpoint** land here.

---

## Work items

### W0.1 — Remove the APK self-update flow and `REQUEST_INSTALL_PACKAGES` (P0-01)

**Why:** A card game has no core purpose that justifies `REQUEST_INSTALL_PACKAGES`; the in-app APK download+install is a likely rejection and a supply-chain risk (update URL taken from Supabase, installed with no SHA-256 / package-name / signer / version / origin check).

**Tasks**
1. Remove `<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />` from `android/app/src/main/AndroidManifest.xml` (audit: line 7 — confirmed present).
2. Delete the in-app updater UI and download/install logic: `lib/widgets/update_check_tile.dart` (audit: APK download at ~line 236, installer launch at ~line 255) and any callers/imports of it. Re-locate by symbol, not line number.
3. Remove the APK `FileProvider` and `android/app/src/main/res/xml/file_paths.xml` entry that exposes the download location; remove the provider declaration from the manifest if it exists.
4. Remove the Supabase-stored "direct download URL" plumbing and the `dio` / `open_filex` usage that exists *only* for APK download/open (confirm `dio`/`open_filex`/`path_provider` are not needed elsewhere before removing the dependency from `pubspec.yaml`).
5. If a sideloaded enterprise build must survive, **isolate it** behind a product flavor with its own applicationId, its own distribution channel, and explicit integrity checks (SHA-256 + package name + signer cert + version). The **Play flavor must not contain any of it.** (Prefer: drop it entirely for the Play release.)

**Files:** `android/app/src/main/AndroidManifest.xml`, `lib/widgets/update_check_tile.dart`, `android/app/src/main/res/xml/file_paths.xml`, `lib/services/update_checker_service.dart` (see W0.6), `pubspec.yaml`.

**Validation:** Build the release AAB, extract the **merged** manifest (`bundletool` or inspect `app/build/outputs/`), and confirm `REQUEST_INSTALL_PACKAGES` and the APK FileProvider are absent. Confirm the app compiles and launches with the updater UI gone. Upload to an internal test track and run Play pre-launch (later, in Phase 4) — but the permission absence must be provable now.

Policy: <https://support.google.com/googleplay/android-developer/answer/12085295?hl=en>

---

### W0.2 — Fail-closed release signing (P0-02)

**Why:** `android/app/build.gradle.kts` (audit: lines 58–61) selects release signing only when `key.properties` exists and otherwise falls back to the **debug** key; `release.yml` (audit: line 144) continues with "default signing" when the keystore secret is missing. A production artifact can be built with the wrong certificate.

**Tasks**
1. In `android/app/build.gradle.kts`, make the release build **throw a Gradle error** if any required signing property (keystore path, store password, key alias, key password) is absent — no debug fallback for `release`.
2. In `.github/workflows/release.yml`, remove the "continue with default signing" path; the job must **fail** when signing secrets are missing.
3. Store **only an upload key** in CI secrets; enroll in **Play App Signing** (the app signing key is held by Google — Phase 4 confirms enrollment).
4. Restrict signing secrets to a protected production environment (GitHub Environment with required reviewers).
5. Document key recovery/rotation in a short `android/SIGNING.md`.

**Files:** `android/app/build.gradle.kts`, `.github/workflows/release.yml`, new `android/SIGNING.md`.

**Validation:** In CI, prove a build **without** signing secrets **fails** (capture the failing run). After a signed build, run `apksigner verify --print-certs` on the universal APK generated from the AAB and record the SHA-256 signer digest; it must match the registered upload certificate.

Reference: <https://developer.android.com/studio/publish/preparing>

---

### W0.3 — Play AAB release path (P0-03)

**Why:** `release.yml` (audit: line 151) runs `flutter build apk --release --split-per-abi` and never builds an app bundle; existing release metadata is stale (`1.5.0+1016`) vs. `pubspec.yaml` (now `1.11.0+22`). New Play apps ship as AABs.

**Tasks**
1. Add a **protected** workflow (manual dispatch or tag-triggered, not every `main` push) that:
   - Pins an **exact** Flutter SDK version (not floating `stable`).
   - Runs all gates: `flutter test`, `flutter analyze` (must be zero-issue after W0.5), and artifact checks.
   - Runs `flutter build appbundle --release`.
   - Signs with the upload key (fail-closed, per W0.2).
   - Archives the R8 **mapping file** and **native debug symbols**.
   - Uploads the AAB to an internal Play track (or archives it as a release candidate; Play upload can be Phase 4).
2. Keep GitHub APK distribution **out** of the Play workflow.
3. Ensure the version code is monotonic (currently 22); add a CI assertion (see W0.6).

**Files:** `.github/workflows/` (new bundle workflow), `pubspec.yaml`.

**Validation:** Play Console accepts `app-release.aab` (Phase 4). Locally: the generated AAB's universal APK has applicationId `com.mostafaazab.estimation`, versionCode ≥ 22 (monotonic), `targetSdk 36`, correct signer, and **no forbidden permission**.

> **Audit caveat:** `flutter build appbundle --release` produced no output for several minutes in the audit environment and was interrupted — status is **unverified, not a known failure**. If the build stalls, capture logs and treat it as a work item (likely environment/network, e.g. Google Fonts fetch — see [Phase 2](phase-2-scaling-bottlenecks.md) W2.8), not proof of a code defect.

Reference: <https://support.google.com/googleplay/android-developer/answer/9844279?hl=en-EN>

---

### W0.4 — Privacy policy, Data Safety inventory, and account deletion (P0-07)

**Why:** The app authenticates with Google and stores email, user ID, display name, avatar, XP, stats/history, room activity, and local network info. Apps that allow account creation must provide **in-app** deletion **and** an external **web** deletion route, plus an accurate Data Safety declaration and a linked privacy policy. None were found.

**Tasks**
1. **Data map:** produce an engineering data inventory (start from the audit's "Data Safety and privacy inventory" table) covering every field and every SDK (Supabase, Google Sign-In, google_fonts, image_picker, device_info_plus, and any added later). Store it as `docs/privacy/data-inventory.md`.
2. **Privacy policy:** write/host a production privacy-policy page; link it in-app (settings) and in the Play listing (Phase 4). Capture the URL.
3. **Account deletion (in-app):** add an authenticated deletion flow with confirmation + reauthentication that deletes the auth user and all associated data: profile, history, room memberships, storage objects (avatars). Document any lawful retention exceptions.
   - The **backend** deletion (RPC/Edge Function with `auth.uid()` authorization + cascading deletes) is designed with [Phase 1](phase-1-trust-boundaries.md); the **UX + call site** are built here. Coordinate so deletion is genuinely complete, not just a profile-row soft delete.
4. **Account deletion (web):** host an accessible web page/endpoint that lets a user request deletion without the app installed. Capture the URL.
5. **Data Safety form:** complete answers from the audited data map (collection, sharing, purpose, retention, encryption in transit, optionality, deletion). This is filled in Play Console in Phase 4 but the **answers are authored here** from the inventory.

**Files:** `docs/privacy/data-inventory.md`, in-app settings/deletion UI (`lib/...`), backend deletion function (coordinate w/ Phase 1), hosted privacy + deletion pages (record URLs in progress report).

**Validation:** With a test account, run in-app deletion and confirm auth user + profile + history + rooms + avatar storage are gone (query Supabase as service role to prove absence). Confirm the web deletion route works without the app. Confirm privacy policy URL loads and is linked in-app.

References: [User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en) · [Account deletion](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en-EN) · [Data Safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)

---

### W0.5 — Analyzer as a hard gate + hygiene cleanup (analyzer / archives / CI pinning / workflow least-privilege)

**Why:** `flutter analyze` reports 17 info-level issues and exits non-zero, but CI does not run it. Tracked archives/logs bloat the repo. The workflow floats Flutter `stable`, pins actions by tag, runs on every `main` push with broad write permissions.

**Tasks**
1. Fix the 17 info findings: deprecated Supabase `anonKey`, deprecated matrix transforms, missing braces, an unnecessary import, `print` calls in tooling/tests. Re-run until `flutter analyze` reports **No issues found!**.
2. Make CI **fail** on any analyzer finding (treat non-zero exit as failure).
3. Remove tracked archives/operational logs from version control in a deliberate cleanup commit: `estimation.rar`, `lib*.zip`, `android.zip`, Supabase logs, JVM crash/replay logs. Add them to `.gitignore`; keep distributable archives outside Git.
4. Pin an **exact** Flutter SDK version and pin third-party actions to **commit SHAs** in every workflow.
5. Give the release workflow **least-privilege** job permissions, add concurrency control, and switch it to protected manual/tag trigger (ties into W0.3).

**Files:** various `lib/` + test files (analyzer fixes), `.gitignore`, `.github/workflows/*.yml`.

**Validation:** `flutter analyze` → No issues found (exit 0). CI run shows analyzer gate failing on a deliberately introduced warning, then passing when fixed. `git ls-files` shows no archives/logs. Workflow YAML shows SHA-pinned actions and scoped `permissions:`.

---

### W0.6 — Single source of truth for version + robust update parsing (P2-10)

**Why:** `pubspec.yaml` (`1.11.0+22`) and `lib/services/update_checker_service.dart` (audit: `1.10.0` at ~line 7) define the version independently; the custom comparison assumes numeric three-part versions and drifts. Removing the sideload updater (W0.1) removes most of this surface.

**Tasks**
1. Read installed version/build from package metadata (`package_info_plus`) rather than a hardcoded constant.
2. If any version comparison remains after W0.1, use a standards-compliant semver parser (`pub_semver`) instead of the custom three-part compare.
3. Add a CI assertion that the Play version code is **monotonic** vs. the previously released code.
4. If `update_checker_service.dart` exists only to support the removed sideload updater, delete it.

**Files:** `lib/services/update_checker_service.dart`, `pubspec.yaml`, CI.

**Validation:** No hardcoded version string remains in Dart; `grep` for the old constant returns nothing. CI fails on a non-monotonic version code.

---

### W0.7 — Dependency, license, and content-rights review + SBOM (P2-11)

**Why:** No CI vulnerability/license audit and no documented commercial provenance for card art, wallpapers, audio, fonts.

**Tasks**
1. Generate an SBOM and a license inventory for Dart/Flutter deps and transitive Android SDKs; add a CI job that runs a vulnerability/license audit and fails on incompatible/unknown terms.
2. Review transitive Android manifests / SDK data behavior (what each SDK collects) and feed it into the W0.4 data map.
3. Retain source/license receipts for **every** asset (card themes, wallpapers, audio, fonts). Store an inventory at `docs/legal/asset-provenance.md`.
4. Generate the required open-source notices screen/file for the app.

**Files:** CI job, `docs/legal/asset-provenance.md`, open-source notices asset.

**Validation:** CI audit job runs and is green (or documents accepted exceptions). Asset provenance file covers 100% of shipped assets. Open-source notices are reachable in-app.

---

### W0.8 — UGC decision and safeguards (P0-08)

**Why:** Users set display names and gallery-selected profile photos shown to other players — that is UGC. No terms acceptance, report, block, or moderation flow exists. An unrestricted photo/name feature can fail review.

**Tasks — choose ONE path (record the decision + rationale in the progress report):**

- **Path A (recommended for first release): remove arbitrary UGC.** Ship preset avatars only and constrained/validated display names (length + charset + profanity list). No gallery photo upload. This is the fastest route to a passable review and also removes the base64-photo cost ([Phase 2](phase-2-scaling-bottlenecks.md) W2.3).
- **Path B: keep UGC with full safeguards.** Terms acceptance, server-side validation, report + block controls, a moderation process, retention rules, and enforcement. Do **not** broadcast email or original photo data. Much larger scope; only if the product requires user photos at launch.

**Tasks (both paths)**
1. Ensure email and original photo bytes are never sent to other players (ties into [Phase 1](phase-1-trust-boundaries.md) sanitized state and [Phase 2](phase-2-scaling-bottlenecks.md) W2.3).
2. Add terms acceptance if any UGC remains.

**Files:** profile/avatar UI (`lib/...`), name-validation logic, (Path B) report/block UI + moderation backend.

**Validation:** If Path A: no code path lets a user upload an arbitrary image; names are validated server-side. If Path B: a tester can report and block another user, and moderation can act. In both: captured multiplayer payloads contain no email and no original photo bytes.

Reference: <https://support.google.com/googleplay/android-developer/answer/9876937?hl=en>

---

### W0.9 — Environment/flavor separation (build-config half; completed in Phase 1)

**Why:** No staging/prod separation means dev/testing can touch production Supabase; Supabase URL + anon key are hardcoded.

**Tasks (Phase 0 scope)**
1. Introduce `--dart-define` / product flavors for environment selection (dev/staging/prod) so builds target the right Supabase project.
2. Move the Supabase URL + anon key out of source into build-time config (an anon key is public by design, but env separation must exist).
3. Never ship a service-role key in the client.

> The **data-trust** consequences (RLS being the only real boundary, anonymous sign-in being cheap) are closed in [Phase 1](phase-1-trust-boundaries.md). Here we only make environments selectable and stop hardcoding.

**Files:** `lib/main.dart` / Supabase init, `android/app/build.gradle.kts` (flavors), CI.

**Validation:** A staging build points at the staging project; grep shows no hardcoded prod URL/key literal in a way that ignores the flavor; no service-role key anywhere in the client bundle.

---

## Phase 0 exit criteria

Do not close the phase until each line has evidence in `plans/progress/phase-0-progress.md`:

- [ ] Merged release manifest has **no** `REQUEST_INSTALL_PACKAGES` and no APK FileProvider (W0.1).
- [ ] In-app APK updater UI and install logic are gone (W0.1).
- [ ] Release build **fails** without signing secrets; signer SHA-256 recorded and matches the intended upload cert (W0.2).
- [ ] A protected workflow builds a **signed AAB** with pinned Flutter, all gates, mapping + symbols archived (W0.3).
- [ ] Privacy policy hosted + linked; Data Safety answers authored from a real data map; in-app **and** web account deletion work end-to-end (W0.4).
- [ ] `flutter analyze` → **No issues found**; CI fails on analyzer findings; archives/logs removed from VCS; actions SHA-pinned; workflow least-privilege (W0.5).
- [ ] Version comes from package metadata; no duplicate constant; CI asserts monotonic version code (W0.6).
- [ ] SBOM + license audit in CI; asset provenance documented; open-source notices shipped (W0.7).
- [ ] UGC decision made and implemented; no email/original-photo bytes leave the device to other players (W0.8).
- [ ] Environments are selectable via flavors/dart-define; no hardcoded prod key path; no service-role key in client (W0.9).

---

## 📋 Reporting requirement (repeat)

Keep `plans/progress/phase-0-progress.md` current after every session and every completed item. It must be thorough enough to stand alone: what's done, what's verified (with real command output — manifest diff, signer digest, analyzer result, build result), what's left, what's blocked. No claim without evidence. Report failures and skips honestly.
