# Google Play Readiness, Security, and Performance Audit

**Application:** Estimation (`com.mostafaazab.estimation`)  
**Audit date:** 2026-08-31  
**Source version:** `1.10.0+21`  
**Scope:** Flutter/Dart source, Android configuration, Supabase SQL and realtime architecture, assets, CI/release workflow, automated tests, static analysis, and current Google Play requirements.

## Executive verdict

**Status: NOT READY FOR GOOGLE PLAY PRODUCTION.**

The game has a meaningful automated unit/widget test suite and a modern Android toolchain, but it has multiple release blockers. The most serious are the APK self-update mechanism and restricted install permission, fail-open release signing, missing privacy/account-deletion obligations, public or over-broad Supabase data access, transmission/persistence of unsanitized hands, and a client-authoritative multiplayer design that permits impersonation and competitive-stat manipulation.

The primary performance bottleneck is not card rendering. It is the network/state architecture: large whole-game snapshots are broadcast and persisted frequently, private/player image data is duplicated inside them, several database calls can occur for one move, and broad provider subscriptions trigger large UI rebuilds. These issues will become more visible with four players, long games, custom photos, weak networks, and low-memory devices.

### Release gate summary

| Gate | Status | Summary |
|---|---:|---|
| Package identity | Pass | Final-looking ID: `com.mostafaazab.estimation`; ownership/uniqueness still needs Play Console confirmation. |
| Target API | Pass | `compileSdk = 36`, `targetSdk = 36`, compliant with the requirement effective 2026-08-31. |
| Android App Bundle | Fail | CI only builds split APKs; no current `.aab` was produced during this audit. |
| Release signing | Fail | Release builds silently fall back to the debug key when signing material is absent. |
| Restricted permissions | Fail | `REQUEST_INSTALL_PACKAGES` is used for an in-game APK updater, which is outside the accepted core purposes for a game. |
| Privacy policy / Data Safety | Fail | No publishable policy or completed data inventory was found. |
| Account deletion | Fail | Google sign-in/profile creation exists, but only sign-out was found; no in-app and web deletion path. |
| Multiplayer confidentiality | Fail | Full state, including private hands, is broadcast/persisted through paths that are not recipient-sanitized. |
| Multiplayer integrity | Fail | Host/client messages trust client-supplied player identity; stats and XP are client-authoritative. |
| UGC safeguards | Fail/conditional | Names and custom profile photos are user-generated content, with no report/block/moderation/terms flow found. |
| Automated tests | Partial pass | 204 tests passed, but security, RLS, release, integration, reconnect, and physical-device coverage are absent. |
| Static analysis | Partial pass | No errors/warnings; 17 info-level findings and a non-zero analyzer exit. CI does not run it. |
| Release build verification | Unverified | The release AAB command stalled in this environment and was interrupted; this is inconclusive, not proof of a code build failure. |
| 16 KB page size | Unverified | Toolchain is recent, but the final AAB/native libraries were not inspected or tested on a 16 KB device. |
| Accessibility | Fail | No meaningful semantics coverage and no TalkBack/reduced-motion/device-matrix evidence. |
| Observability | Fail | No production crash/ANR reporting or performance telemetry was found. |

## What is already in good shape

- Android package ID is no longer a template ID.
- Android uses Java 17, AGP 8.11.1, `compileSdk 36`, and `targetSdk 36`.
- Release minification and resource shrinking are enabled.
- The application has a sizeable automated suite: **204 tests passed** in this audit.
- Card images are generally decoded with bounded cache dimensions rather than always at source size.
- The primary game model contains recipient-sanitization support (`toSanitizedJson`), showing that private-state separation was considered, even though online transport paths do not currently use it.
- Performance settings include a low-spec mode and blur reduction, though detection and coverage need improvement.
- No advertising, billing, real-money wagering, or gambling SDK was identified in the dependency list.

## Critical release blockers

### P0-01 — APK self-update flow conflicts with Google Play policy

**Evidence**

- `android/app/src/main/AndroidManifest.xml:7` requests `android.permission.REQUEST_INSTALL_PACKAGES`.
- `lib/widgets/update_check_tile.dart:236` downloads an APK and line 255 opens it with the platform installer.
- `android/app/src/main/res/xml/file_paths.xml` exposes the download location through `FileProvider`.
- `.github/workflows/release.yml` publishes split APKs to GitHub and stores a direct download URL in Supabase.

**Impact:** A card game does not have package installation as a core purpose. Google Play restricts this permission to narrow categories. This is a likely policy rejection. It also creates a dangerous supply-chain path: the client accepts an update URL from Supabase and installs the downloaded file without a SHA-256 check, package-name check, signer-certificate check, version check, or strict origin allowlist.

**Required fix**

1. Remove `REQUEST_INSTALL_PACKAGES`, the APK download/install UI, and the APK `FileProvider` from the Play flavor.
2. Distribute Play builds exclusively through Google Play; use Play in-app updates or a store-listing link.
3. If a non-Play enterprise flavor must retain sideloading, isolate it with product flavors, a separate application ID, explicit integrity checks, and a separate distribution channel.

**Validation:** Inspect the merged release manifest and confirm the permission/provider are absent; upload the AAB to an internal test track and run Play pre-launch checks.

Policy reference: [Google Play — Use of the REQUEST_INSTALL_PACKAGES permission](https://support.google.com/googleplay/android-developer/answer/12085295?hl=en)

### P0-02 — Release signing fails open to the debug key

**Evidence**

- `android/app/build.gradle.kts:58-61` selects the release signing config only when `key.properties` exists and otherwise selects `debug`.
- `.github/workflows/release.yml:144` explicitly continues with “default signing” when the keystore secret is missing.

**Impact:** A production artifact can be built with the wrong certificate. That can block upload, make future updates impossible under the expected identity, or publish an unverifiable GitHub artifact.

**Required fix:** Make release configuration throw a Gradle error when any keystore property is absent. Store only an upload key in CI secrets, enroll in Play App Signing, restrict secret access to a protected production environment, and document key recovery/rotation.

**Validation:** In CI, prove that a build without signing secrets fails; run `apksigner verify --print-certs` on the universal APK generated from the signed AAB and compare the SHA-256 signer digest with the registered upload certificate.

Reference: [Android Developers — Prepare and roll out a release](https://developer.android.com/studio/publish/preparing)

### P0-03 — No Play AAB release path

**Evidence:** `.github/workflows/release.yml:151` runs `flutter build apk --release --split-per-abi`; it does not build an app bundle. Existing release APKs are stale: generated metadata reports `1.5.0+1016`, while `pubspec.yaml` is `1.10.0+21`.

**Impact:** New Google Play applications are published with Android App Bundles. The repository cannot currently demonstrate a reproducible, signed, current-version Play artifact.

**Required fix:** Add a protected workflow that pins an exact Flutter version, runs all gates, executes `flutter build appbundle --release`, signs with the upload key, archives mapping/native symbols, and uploads to an internal Play track. Keep GitHub APK distribution out of the Play workflow.

**Validation:** Play Console accepts `app-release.aab`; generated APKs have the correct application ID, version code 21 or a newer monotonic code, target API 36, signer, and no forbidden permission.

Reference: [Google Play — Use Play App Signing](https://support.google.com/googleplay/android-developer/answer/9844279?hl=en-EN)

### P0-04 — Private hands and full state are exposed

**Evidence**

- `lib/networking/game_server.dart:587` broadcasts `_state.toJson()` rather than a recipient-sanitized state.
- `lib/networking/game_server.dart:751-758` persists `_state.toJson()` as `game_state`.
- The Ninety-Nine and Basra servers also broadcast raw state at `lib/modes/ninety_nine/networking/ninety_nine_game_server.dart:302` and `lib/modes/basra/networking/basra_game_server.dart:249`.
- `supabase_migration.sql:45` permits all room reads; `supabase_security_patch.sql:22` still uses `USING (true)` despite its “secure” intent.
- `supabase_reconnection_migration.sql` stores full `game_state` and per-player `hand_cards`.

**Impact:** Opponents or modified clients can inspect private cards. Stored snapshots can expose the same data through permissive row access. This breaks the central fairness property of the game and creates a privacy/security incident surface.

**Required fix:** Move authoritative state transitions to a trusted backend. Store public state separately from encrypted/private per-user hands. Deliver each private hand only on a user-specific authenticated channel. Never put every hand into a shared broadcast or broadly readable room row. Add database tests that attempt cross-player reads.

**Validation:** With four test identities, assert that each token can retrieve only public state plus its own hand; capture realtime frames and confirm no opponent cards exist anywhere in the payload.

### P0-05 — Clients can impersonate players and manipulate competitive results

**Evidence**

- `lib/networking/game_server.dart:327-538` accepts `playerId` and action fields supplied by a client; no verified transport identity is bound to the action.
- Reactions and other metadata are client supplied and are not rate-limited or strictly length-limited server-side.
- `supabase_profiles.sql:79` defines `increment_player_stats`; the client can submit XP/win changes without an independently verified match result.
- Profile update policy permits users to update their own profile row, including competitive fields.
- The host is another player device and holds/advances authoritative game state.

**Impact:** A modified client can act as another player, spam expensive resyncs, forge XP/wins, tamper with a hosted match, or exploit host migration. Leaderboards and progression cannot be trusted.

**Required fix:** Bind every action to `auth.uid()` on a trusted server/Edge Function, validate membership and turn legality there, use idempotent action IDs and monotonic sequence numbers, rate-limit actions, and calculate match outcomes/XP only from server-recorded results. Users must not update XP, wins, level, or games played directly.

**Validation:** Adversarial integration tests must reject another player's ID, replayed actions, out-of-order actions, forged wins, negative/huge XP, non-members, and concurrent host changes.

### P0-06 — Supabase RLS exposes personal and game data too broadly

**Evidence**

- `supabase_profiles.sql:27` allows all profile rows to be selected; the table includes email at line 8.
- `game_history_migration.sql:20` uses `USING (true)`, despite a comment implying owner-only history.
- `supabase_migration.sql:45` and line 58 allow all users to select rooms and room players.
- Several `SECURITY DEFINER` functions do not consistently pin `search_path`, validate callers, cap values, or explicitly revoke execution from `PUBLIC` before granting intended roles.
- Anonymous sign-in means obtaining an authenticated role is inexpensive; “authenticated” alone is not a meaningful confidentiality boundary.

**Impact:** Email addresses, profile images, history, room membership, private snapshots, and identifiers may be enumerable. Incomplete function hardening increases privilege-escalation risk.

**Required fix:** Replace public-select policies with owner/member/recipient predicates, remove email from public profile views, use separate public/private profile tables or views, harden every definer function with `SET search_path`, caller validation, explicit revoke/grant, input bounds, and transaction-safe authorization. Apply changes through ordered migrations, not ad-hoc root SQL files.

**Validation:** Run an automated RLS matrix for anonymous, unrelated authenticated, room member, room host, and service role. Include read, insert, update, delete, RPC, and realtime visibility.

### P0-07 — Privacy policy, Data Safety, and account deletion are incomplete

**Evidence:** Google authentication/profile creation and Supabase account data exist. The app stores or processes email, user ID, display name, avatar, XP, game statistics/history, room activity, and local network information. No production privacy-policy URL, in-app privacy entry, account-deletion method, or deletion web endpoint was found.

**Impact:** Apps that allow account creation must provide an in-app deletion path and an external web deletion route. Play also requires an accurate Data Safety declaration and privacy policy. Missing these prevents publication or risks enforcement after release.

**Required fix:** Implement authenticated deletion covering the auth user and associated profile/history/rooms/storage, document retention exceptions, add in-app deletion with confirmation and reauthentication, host an accessible deletion web page, link the privacy policy in the app and Play listing, and complete Data Safety from an audited data map including all SDKs.

References: [Google Play User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en), [account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en-EN), and [Data Safety form guidance](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)

### P0-08 — User-generated content safeguards are missing

**Evidence:** Users can set names and gallery-selected profile images, and those values are shown to other players. No terms acceptance, report flow, block function, moderation process, or abuse escalation mechanism was found.

**Impact:** If these fields are distributed to other users, they are UGC. An unrestricted photo/name feature without reporting and blocking can fail Play review and creates safety/legal exposure.

**Required fix:** Either remove arbitrary UGC for the first release (preset avatars and constrained names) or implement terms acceptance, server validation, report/block controls, moderation operations, retention rules, and enforcement. Do not broadcast email or original photo data.

Reference: [Google Play — User Generated Content policy](https://support.google.com/googleplay/android-developer/answer/9876937?hl=en)

## High-severity engineering and performance findings

### P1-01 — Whole-state broadcasts are the dominant network bottleneck

The servers broadcast full JSON state after many actions, including invalid-action resyncs. The model grows with players, hands, tricks, scores, histories, and embedded photos. Serializing, transmitting, parsing, allocating, and rebuilding from this state affects the host and every client.

**Fix:** Use small versioned action/event payloads, periodic compact public snapshots, per-recipient private deltas, monotonically increasing state versions, and an explicit resync request with rate limits. Measure payload bytes and messages per completed trick.

### P1-02 — A single move can trigger excessive and duplicate database writes

`_broadcastState` can persist on phase changes, while action paths also persist a snapshot and save hands individually. A move can therefore cause one state RPC plus up to four hand RPCs, sometimes in addition to phase persistence.

**Impact:** Added move latency, battery/radio use, Supabase cost, write races, and poor behavior on mobile loss/reconnect.

**Fix:** Commit one authorized, transactional match checkpoint at meaningful boundaries. Batch private hand updates in that transaction, debounce noncritical presence data, and never block visual feedback on persistence.

### P1-03 — Base64 profile photos multiply payload and memory costs

Custom images are resized but converted to base64, stored in preferences/profile data, copied into `Player`, and serialized with game state. Base64 adds roughly one-third overhead before JSON overhead and forces repeated copies/decodes.

**Fix:** Upload a bounded WebP/AVIF thumbnail to a dedicated storage bucket, store only an opaque path/version in state, enforce owner write policies, expose only intended thumbnails, and cache decoded images. Remove email and original image data from public player objects.

### P1-04 — Broad provider subscriptions rebuild large game screens

The main Estimation screen contains multiple `Consumer<GameProvider>` sections, while Ninety-Nine and Basra watch their full providers. Frequent `notifyListeners()` calls can rebuild HUDs, hands, player areas, animations, and overlays for unrelated state changes.

**Fix:** Split state into immutable slices; use `Selector`/`context.select` for exact fields; isolate hands, trick, timers, reactions, and connection state behind repaint boundaries; keep animation controllers below stable subtrees. Use Flutter DevTools' rebuild tracker to confirm reductions.

### P1-05 — Client-hosted LAN server has no authenticated transport

The local server binds `InternetAddress.anyIPv4` on port 7890 and uses `ws://`. A device on the same network can connect, spoof protocol messages, enumerate behavior, or flood the host. Discovery/runtime handling for `NEARBY_WIFI_DEVICES` was not found in Dart and needs physical-device validation.

**Fix:** Add an ephemeral room secret/handshake, authenticated message MACs, strict schema and size limits, connection/action rate limits, idle timeouts, and local-network permission UX. Prefer a trusted relay for competitive play. Test current Android cleartext/network policies across API 24–36.

### P1-06 — Startup can be blocked by network-dependent authentication

The bootstrap waits for device settings and auth initialization before entering the main application. A returning Google user can trigger profile refresh/network work without a clear bounded timeout. Offline users may be delayed or shown retry UI before reaching local modes.

**Fix:** Render the shell from cached state immediately, move profile refresh to a cancellable background task, set explicit timeouts/retry budgets, expose offline mode, and record startup timing from process start to first interactive frame.

### P1-07 — No production crash, ANR, or performance observability

No Crashlytics/Sentry-equivalent service, global Flutter error handlers, native crash upload, ANR tracking, or performance traces were found.

**Impact:** Regressions will only appear in reviews or Play Console after harming users, and multiplayer failures will be hard to diagnose.

**Fix:** Add privacy-reviewed crash/ANR reporting, `FlutterError.onError`, `PlatformDispatcher.instance.onError`, release/version/session tags, redaction, and opt-out/consent as legally appropriate. Upload R8 mappings and native symbols for every release. Monitor Play vitals by device and version.

Google Play visibility thresholds currently include a **1.09% user-perceived crash rate** and **0.47% user-perceived ANR rate** overall; target materially below them. Reference: [Android vitals](https://developer.android.com/topic/performance/vitals)

### P1-08 — Production database state is not reproducible from migrations

Schema and policy changes are spread across root-level SQL files and only a small ordered `supabase/migrations` set. It is unclear which files were applied and in what order. Comments and actual policies conflict.

**Fix:** Generate a reviewed production schema dump, reconcile drift, convert every change to ordered idempotent migrations, add local Supabase CI, and prohibit dashboard-only production changes.

### P1-09 — OAuth redirect uses a claimable custom scheme

`io.supabase.kotshina://login-callback` is a custom scheme. Another installed app can register the same scheme, creating redirect interception risk.

**Fix:** Prefer verified HTTPS App Links with Digital Asset Links, retain PKCE/state/nonce validation, and strictly validate redirect host/path. If the custom scheme remains as fallback, document the residual risk and test malicious-handler behavior.

### P1-10 — Android backup behavior is not explicitly controlled

No `dataExtractionRules`/backup policy was found. Preferences can contain session-related and profile/avatar data. Default platform backup behavior may move data in ways the authentication design did not intend.

**Fix:** Define Android 12+ data extraction and legacy backup rules; exclude tokens, session caches, room state, and sensitive user data. Test restore onto a fresh device and confirm the user is not silently authenticated with stale credentials.

## Medium-severity performance, quality, and maintainability findings

### P2-01 — Animation and blur budget is not adaptive enough

Multiple screens use repeating pulse/particle/background controllers and blur. Low-spec mode mainly disables blur; it does not consistently stop particles or repeat animations. Device classification based on Android low-RAM, CPU count, old SDK, and a small model list misses GPU/thermal/battery constraints.

**Fix:** Add one motion-quality policy (full/reduced/off), respect system accessibility animation settings, pause offstage tickers with `TickerMode`, eliminate invisible controllers, and profile sustained play under thermal throttling.

### P2-02 — An always-repainting custom painter wastes frame budget

`lib/widgets/estimation_poster_card.dart:957` returns `true` from `shouldRepaint`, forcing repaint whenever considered.

**Fix:** Compare immutable painter inputs and return true only when visual state changes. Place expensive stable layers behind `RepaintBoundary` and verify with repaint-rainbow tooling.

### P2-03 — Side effects are scheduled from a build method

The Basra screen calls delayed overlay/flash logic while building. Guards reduce duplication but rebuild-driven timers remain brittle and can fire after navigation/disposal.

**Fix:** Move transitions to a provider listener, `didUpdateWidget`, or state-machine effect handler. Track and cancel timers in `dispose`.

### P2-04 — Runtime Google Fonts create a first-run network dependency

Fonts are used through `google_fonts`, no bundled font assets or global runtime-fetch disable was found. First use may fetch fonts, causing font swap, offline inconsistency, additional network disclosure, and unpredictable layout timing.

**Fix:** Bundle licensed Cairo/Cinzel assets, declare them in `pubspec.yaml`, set `GoogleFonts.config.allowRuntimeFetching = false`, and test cold offline launch.

### P2-05 — Asset and download size need a current AAB measurement

Declared card themes total roughly **12.3 MB**. Assets on disk total about **22.2 MB**, including undeclared wallpaper/card files. A stale universal release APK is about **76.3 MB**, while stale split APKs are roughly **36.9–40.7 MB**. These are not current Play delivery sizes.

**Fix:** Build a current AAB, run Play size analysis, remove unused assets, compress large PNG/JPEG files or convert suitable artwork to WebP, and avoid packaging all optional themes if they can be downloaded safely on demand.

### P2-06 — Audio timeouts do not cancel underlying operations

Audio stop/play futures are wrapped in very short timeouts. Timeout completion does not cancel the native operation, so rapid effects can overlap or finish late.

**Fix:** Use a small effect-player pool with explicit lifecycle/state, coalesce repeated sounds, cancel delayed haptics where possible, and measure audio-thread/device behavior on low-end hardware.

### P2-07 — Large “god” classes increase regression risk

`GameProvider` and the profile/game screens combine networking, persistence, transitions, timers, matchmaking, mode logic, and UI concerns. This makes subtle reconnect/performance defects harder to isolate and test.

**Fix:** Separate transport, authoritative reducer, persistence, matchmaking, presence, profile storage, and presentation controllers. Keep reducers pure and property-test legal transitions.

### P2-08 — Accessibility coverage is inadequate

No meaningful `Semantics`, `MergeSemantics`, or `ExcludeSemantics` coverage was found, while many custom gestures/icons/cards exist. There is no evidence for TalkBack order/labels, large text, contrast, 48 dp targets, color-blind cues, reduced motion, switch access, tablets, or foldables.

**Fix:** Add semantic labels/actions for cards, bids, players, scores, connectivity, dialogs, and game outcome; never rely on suit color alone; support 200% text where practical; add reduced motion; run Accessibility Scanner and manual TalkBack tests.

### P2-09 — Localization is structural rather than real

The app forces RTL globally but lacks standard localization delegates/supported locales and contains hardcoded Arabic/English strings.

**Fix:** Move strings to ARB/gen-l10n, declare locales/delegates, select direction from locale, and test Arabic/English, pluralization, long strings, and numerals.

### P2-10 — Version is duplicated and update parsing is fragile

`pubspec.yaml` defines `1.10.0+21`, while `lib/services/update_checker_service.dart:7` independently defines `1.10.0`. The custom comparison assumes numeric three-part versions and can drift or fail on prerelease/build metadata.

**Fix:** Read installed version/build from package metadata, compare with a standards-compliant semantic-version parser, and make CI assert monotonic Play version codes. Removing the sideload updater also removes most of this surface.

### P2-11 — Dependency, license, and content-rights review is absent

There is no CI vulnerability/license audit or documented commercial provenance for card art, wallpapers, audio, fonts, and other assets.

**Fix:** Produce an SBOM and license inventory, review transitive Android manifests/SDK data behavior, retain source/license receipts for every asset, and generate required open-source notices. Reject dependencies with incompatible or unknown terms.

### P2-12 — Near-term 16 KB compatibility is unverified

Apps targeting API 35+ must support 16 KB page sizes under current Android requirements; enforcement for updates is stated for 2027-02-01. The AGP version is sufficiently recent, but Flutter/plugin native libraries in the final AAB still need inspection and device testing.

**Fix:** Build the final AAB, inspect alignment/native libraries with Android tooling, test on a 16 KB emulator/device, and repeat whenever Flutter or a native plugin changes.

Reference: [Android Developers — Support 16 KB page sizes](https://developer.android.com/guide/practices/page-sizes)

## Lower-severity and hygiene findings

- `flutter analyze` reports 17 info-level issues, including deprecated Supabase `anonKey`, deprecated matrix transforms, missing braces, an unnecessary import, and `print` calls in tooling/tests. Clear them and treat analyzer output as a CI failure.
- The Supabase project URL and publishable anonymous key are hardcoded. An anon key is designed to be public, but the app has no environment separation and its safety depends completely on correct RLS. Use `--dart-define`/flavors for environment selection; never ship a service-role key.
- ProGuard rules broadly keep Flutter/plugin/Google sign-in classes, potentially reducing R8 optimization. Replace broad keeps with evidence-based rules after release tests.
- Already-tracked archives and operational logs (`estimation.rar`, multiple `lib*.zip`, `android.zip`, Supabase logs, JVM crash/replay logs) bloat clone/CI operations and may expose internal details. Remove them from version control in a deliberate cleanup commit and keep distributable archives outside Git.
- The workflow uses floating Flutter `stable` and tag-pinned third-party actions. Pin an exact Flutter SDK and action commit SHAs for reproducibility/supply-chain safety.
- The release workflow runs on every main push with broad write permissions and creates releases by version, making accidental/rerun behavior risky. Use a protected manual/tag workflow, least-privilege job permissions, concurrency control, and an immutable provenance record.
- The app has no staging/prod flavor separation, so development and testing can touch production Supabase state.
- Existing anti-cheat/sanitization tests exercise model methods, but the live transport paths bypass those sanitized methods. Tests currently overstate real online confidentiality.
- Some tests intentionally encounter uninitialized Supabase assertions and swallow/log them. Replace global SDK access with injected interfaces/fakes so failures are deterministic and quiet.
- No app-specific Macrobenchmark/Baseline Profile module was found. Add startup and critical-flow benchmarks after the architecture is stable.

## Performance acceptance plan

Static inspection identifies risk; it does not substitute for profiling. Before production, capture a repeatable matrix on at least one low-end Android Go/4 GB device, one mid-range API 34–36 device, one Samsung device, a tablet/foldable, and a 16 KB-page emulator/device.

| Metric | Proposed release target | Scenario |
|---|---:|---|
| Time to first interactive screen | p95 under 2.5 s warm, under 4.0 s cold | Offline and normal Wi-Fi |
| UI/raster frame time | p95 under 16.7 ms on 60 Hz; no repeated >100 ms stalls | Dealing, bidding, card play, dialogs, earthquake effect |
| Janky frames | Under 1% in a 20-minute representative match | Low-end and thermally warmed device |
| Memory | No sustained growth across 3 complete games; no OOM | All themes and custom avatars |
| Realtime public payload | Prefer under 10 KB/action; document any exception | Four players, final rounds/history at maximum size |
| Database writes | At most one transactional checkpoint per authoritative action/boundary | Four-player online game |
| Reconnect | p95 under 5 s; no private-state leak or duplicated action | Wi-Fi/mobile handoff, 30 s disconnect, host loss |
| Crash / ANR | Far below Play bad-behavior thresholds | Internal/closed tracks segmented by device/version |
| Delivered size | Measure and set a budget from Play Console | Fresh install and update |
| Battery/network | No runaway radio/ticker activity while backgrounded | 30-minute match plus 10-minute background |

Capture DevTools CPU, frame, memory, allocation, network payload, rebuild, and repaint traces. Save the profile artifacts with the release candidate so results are comparable across versions.

## Testing gaps that must be closed

1. **RLS security suite:** cross-user reads/writes/RPC/realtime for every table and role.
2. **Protocol abuse suite:** spoofed IDs, replay, reordering, oversized payloads, reaction spam, unauthorized join, forged score, host takeover, and disconnect storms.
3. **End-to-end four-device tests:** every mode, invite/join, background/resume, network transition, host loss, OAuth, deletion, and update from an older Play build.
4. **Release artifact tests:** signed AAB, merged manifest, version, API, 64-bit ABI, 16 KB alignment, symbols, mapping, install/upgrade, and Play pre-launch report.
5. **Performance tests:** cold/warm startup, worst-case final-round state, custom photos, low-spec motion, memory across repeated games, and battery/network use.
6. **Accessibility tests:** TalkBack, large fonts/display size, contrast, reduced motion, touch targets, hardware keyboard/switch access, RTL, tablet/foldable.
7. **Resilience tests:** Supabase unavailable/slow, expired token, revoked user, malformed database rows, duplicate realtime events, clock skew, disk full, and process death.
8. **Coverage gate:** report line/branch coverage by subsystem; do not use a global percentage to hide untested security code.

## Data Safety and privacy inventory to confirm

This is an engineering inventory, not a legal conclusion. The Play Console owner must verify collection, sharing, purpose, retention, encryption, optionality, and deletion against actual production behavior and every third-party SDK.

| Data class | Evidence/use | Required action |
|---|---|---|
| Email address | Supabase profile/auth | Keep private; disclose collection; delete/retain per policy. |
| User ID | Auth, room membership, stats | Disclose; prevent enumeration; document account deletion. |
| Display name | Profile and multiplayer display | Treat as UGC/personal info; validate/report/block or constrain. |
| Profile photo | Gallery selection, base64 profile/player state | Minimize, move to protected storage, moderate, disclose. |
| Gameplay/app activity | XP, wins, history, rooms, actions | Disclose purpose/retention; owner-only policies where appropriate. |
| Local network data | Discovery/network plugins and LAN play | Confirm whether collected or only processed ephemerally; disclose accurately. |
| Diagnostics | Not currently instrumented | If crash/performance SDK is added, update policy and Data Safety before release. |
| Authentication tokens | Supabase/Google SDK storage | Exclude from backups/logs; never expose; document security practice. |

## Store and operational checklist

- Create the app in Play Console with the exact final package ID and enroll in Play App Signing.
- Upload a signed AAB to internal testing; resolve every pre-launch, policy, SDK, and device-catalog issue.
- Supply privacy-policy and account-deletion URLs, Data Safety answers, content rating/IARC answers, target-audience declaration, ads declaration, app-access/reviewer instructions, and contact details.
- Prepare high-resolution icon, feature graphic, screenshots for supported form factors, descriptions, and localized listing text; ensure screenshots reflect actual functionality.
- Document that the game has no real-money gambling if that remains true; answer card-game/content-rating questions accurately.
- If the developer account is a personal account created after 2023-11-13, complete a closed test with at least 12 opted-in testers continuously for 14 days before applying for production access. Reference: [Google Play testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en-GB)
- Complete developer identity/device verification when applicable. Android developer verification enforcement begins in selected regions on 2026-09-30 and expands later. References: [developer verification](https://support.google.com/android-developer-console/answer/16561738?hl=en) and [Play Console requirements](https://support.google.com/googleplay/android-developer/answer/10788890?hl=en)
- Set internal → closed → staged production rollout gates, rollback criteria, support ownership, incident response, database backup/restore, and key/account recovery.
- Review Play's current target API policy immediately before submission. As of this audit date, new apps and updates must target Android 16/API 36. Reference: [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)

## Recommended remediation order

### Phase 0 — Make a Play-safe artifact

Remove the sideload updater and restricted permission; implement fail-closed upload signing; build a current AAB; add test/analyze/artifact verification gates; establish privacy policy, Data Safety inventory, and account deletion.

### Phase 1 — Repair trust boundaries

Redesign multiplayer around a trusted authority; bind actions to authenticated users; separate public/private state; eliminate raw hand broadcasts; harden RLS/RPCs; make stats server-derived; add adversarial database/protocol tests.

### Phase 2 — Remove scaling bottlenecks

Replace whole snapshots with deltas/checkpoints; batch writes; move images out of JSON; split providers and subscriptions; stop offstage/reduced-motion animations; fix unnecessary repaints; bundle fonts.

### Phase 3 — Prove quality on real devices

Add crash/ANR observability, release integration tests, performance traces, accessibility work, 16 KB verification, network-failure testing, and a representative device matrix.

### Phase 4 — Controlled Play rollout

Complete store declarations/assets, internal and closed testing, resolve pre-launch reports, stage production gradually, and monitor vitals/support before expanding.

## Definition of ready

The game should not be submitted to production until all P0 findings are closed with evidence, all P1 security findings are closed, a signed API-36 AAB passes Play internal testing, private cards cannot be obtained by any other identity, competitive results cannot be client-forged, account deletion works end-to-end, policy disclosures match production behavior, and the measured device matrix meets agreed performance/crash/ANR budgets.

## Audit evidence and limitations

- `flutter test`: **204 tests passed**.
- `flutter analyze`: **17 info-level findings**, no warnings/errors; command exits non-zero because findings exist.
- `flutter build appbundle --release`: produced no output for several minutes in this environment and was interrupted. Treat current AAB status as **unverified**, not as a confirmed source-code build defect.
- Existing build intermediates are older than the current source version and were used only as clues, not release proof.
- Play Console configuration, live Supabase policies/data, signing certificates, developer-account type, privacy URLs, asset licenses, and physical-device behavior were not available locally. Each remains an explicit verification item.
- Findings are based on the repository state on 2026-08-31. This report supersedes older repository audits where they conflict with the current application ID, target SDK, or implemented features.

