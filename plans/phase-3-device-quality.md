# Phase 3 — Prove quality on real devices

> **Source:** [Google Play Deep Audit 2026-08-31](../GOOGLE_PLAY_DEEP_AUDIT_2026-08-31.md) · **Phase objective (verbatim):** "Add crash/ANR observability, release integration tests, performance traces, accessibility work, 16 KB verification, network-failure testing, and a representative device matrix."

Phases 0–2 make the app *correct and fast in principle*. This phase **proves it on real hardware** and instruments production so regressions surface before they harm users. It closes the observability, accessibility, localization, 16 KB, and testing-coverage gates, and runs the audit's performance acceptance matrix.

## 📋 Mandatory reporting requirement — read first

After **every** work session and immediately after completing any single work item, create/update **`plans/progress/phase-3-progress.md`** (copy from [`progress/_TEMPLATE.md`](progress/_TEMPLATE.md)). A reader who sees only that file must know what's done, verified (with real evidence — device/model list, trace numbers vs. targets, TalkBack notes, 16 KB inspection output, coverage report), remaining, blocked. No claim without evidence. State skips/partials; report failures with output. **Device evidence must name the actual device + Android version tested.**

## Findings covered

| Finding | Title |
|---|---|
| P1-07 | No production crash, ANR, or performance observability |
| P2-08 | Accessibility coverage inadequate |
| P2-09 | Localization is structural, not real |
| P2-12 | 16 KB page-size compatibility unverified |
| — | ProGuard broad keeps; deterministic test SDK access; no Baseline Profile/Macrobenchmark (hygiene) |
| Testing gaps 3–8 | E2E four-device, release-artifact, performance, accessibility, resilience, coverage gate |
| Acceptance plan | Full performance/crash/ANR device matrix |

> **Depends on:** Phases 1–2 stable (you measure the real architecture, not the old one). **Feeds:** [Phase 4](phase-4-controlled-rollout.md) (pre-launch report, vitals monitoring rely on this instrumentation).

---

## Device matrix (from the acceptance plan)

Capture a repeatable matrix on **at least**:

- One low-end **Android Go / 4 GB** device.
- One mid-range **API 34–36** device.
- One **Samsung** device.
- One **tablet / foldable**.
- One **16 KB-page** emulator/device.

Record exact model + Android version for every result in the progress report.

---

## Work items

### W3.1 — Crash / ANR / performance observability (P1-07)

**Why:** No Crashlytics/Sentry-equivalent, no global Flutter error handlers, no native crash upload, no ANR tracking, no perf traces. Regressions would only show up in reviews or Play Console after harming users.

**Tasks**
1. Add a privacy-reviewed crash/ANR reporting SDK (coordinate with [Phase 0](phase-0-play-safe-artifact.md) W0.4 Data Safety + privacy policy — adding an SDK changes disclosures).
2. Wire `FlutterError.onError` and `PlatformDispatcher.instance.onError`.
3. Add release/version/session tags; redact PII; add opt-out/consent where legally appropriate.
4. Upload **R8 mappings + native symbols** for every release (ties to [Phase 0](phase-0-play-safe-artifact.md) W0.3 archival).
5. Add performance traces for critical flows; plan to monitor Play vitals by device + version ([Phase 4](phase-4-controlled-rollout.md)).

**Validation:** A forced test crash appears **deobfuscated** in the dashboard with correct version/session tags. Data Safety + privacy policy updated to reflect the diagnostics SDK **before** release.

Vitals thresholds (visibility): user-perceived crash **1.09%**, ANR **0.47%** — target materially below. Ref: <https://developer.android.com/topic/performance/vitals>

---

### W3.2 — Accessibility (P2-08)

**Why:** No meaningful `Semantics`/`MergeSemantics`/`ExcludeSemantics` coverage despite many custom gestures/icons/cards. No TalkBack, large-text, contrast, 48 dp, color-blind, reduced-motion, switch-access, tablet/foldable evidence.

**Tasks**
1. Add semantic labels/actions for cards, bids, players, scores, connectivity, dialogs, game outcome.
2. Never rely on suit **color alone** (add a non-color cue).
3. Support **200% text** where practical; add reduced motion (aligns with [Phase 2](phase-2-scaling-bottlenecks.md) W2.6).
4. Run **Accessibility Scanner** + manual **TalkBack** tests.

**Validation:** TalkBack reads a full round in a sensible order with correct labels; Accessibility Scanner passes key screens; 200% text doesn't break core layouts; color-blind cue present. Record device + findings.

---

### W3.3 — Real localization (P2-09)

**Why:** The app forces RTL globally but lacks standard localization delegates/supported locales and has hardcoded Arabic/English strings.

**Tasks**
1. Move strings to **ARB / gen-l10n**; declare `supportedLocales` + `localizationsDelegates`.
2. Select text **direction from locale** (stop forcing global RTL).
3. Test Arabic + English, pluralization, long strings, and numerals.

**Validation:** Switching locale switches strings + direction correctly; no hardcoded UI strings remain in core screens; long-string + numeral cases render.

---

### W3.4 — 16 KB page-size verification (P2-12)

**Why:** Apps targeting API 35+ must support 16 KB pages; update enforcement is stated for 2027-02-01. AGP is recent, but final AAB/native libs weren't inspected or device-tested.

**Tasks**
1. Build the final AAB ([Phase 0](phase-0-play-safe-artifact.md) W0.3).
2. Inspect alignment + native libraries with Android tooling.
3. Test on a **16 KB emulator/device**; repeat whenever Flutter or a native plugin changes.

**Validation:** Native libs are 16 KB-aligned; app runs correctly on a 16 KB device. Record tooling output + device.

Ref: <https://developer.android.com/guide/practices/page-sizes>

---

### W3.5 — Release-artifact tests (Testing gap 4)

**Tasks**
1. Automated checks on the signed AAB: merged manifest (no forbidden permission — ties to [Phase 0](phase-0-play-safe-artifact.md) W0.1), version, target API 36, 64-bit ABI, 16 KB alignment, symbols, mapping.
2. Install/upgrade test **from an older Play build** to the new one.

**Validation:** All artifact assertions pass in CI; upgrade from a prior build preserves user state without data loss/silent re-auth (aligns with [Phase 1](phase-1-trust-boundaries.md) W1.9).

---

### W3.6 — End-to-end four-device tests (Testing gap 3)

**Tasks**
1. Every mode: invite/join, background/resume, network transition, host loss, OAuth, deletion, and update from an older Play build — across four real devices.

**Validation:** Each scenario passes on the device matrix; reconnect **p95 < 5 s** with **no private-state leak** or duplicated action (acceptance plan; leak check reuses [Phase 1](phase-1-trust-boundaries.md) W1.2 capture method).

---

### W3.7 — Performance tests + acceptance matrix (Testing gap 5, acceptance plan)

**Tasks**
Capture DevTools CPU/frame/memory/allocation/network/rebuild/repaint traces for:
1. Cold/warm startup; worst-case final-round state; custom photos; low-spec motion; memory across repeated games; battery/network use.

**Validation — hit the acceptance targets and record each:**

| Metric | Target |
|---|---|
| Time to first interactive | p95 < 2.5 s warm / < 4.0 s cold (offline + Wi-Fi) |
| UI/raster frame time | p95 < 16.7 ms @ 60 Hz; no repeated > 100 ms stalls |
| Janky frames | < 1% in a 20-min match (low-end/warm) |
| Memory | no sustained growth across 3 games; no OOM |
| Realtime public payload | < 10 KB/action (document exceptions) |
| DB writes | ≤ 1 transactional checkpoint / authoritative boundary |
| Reconnect | p95 < 5 s; no leak/dup |
| Crash / ANR | far below Play thresholds |
| Delivered size | measured; budget set |
| Battery/network | no runaway radio/ticker while backgrounded |

Save trace artifacts with the release candidate.

---

### W3.8 — Resilience tests (Testing gap 7)

**Tasks**
1. Supabase unavailable/slow, expired token, revoked user, malformed DB rows, duplicate realtime events, clock skew, disk full, process death.

**Validation:** App degrades gracefully (no crash, no data corruption, no silent auth) in each case; record behavior per scenario.

---

### W3.9 — Coverage gate + deterministic test infra (Testing gap 8, hygiene)

**Tasks**
1. Report line/branch coverage **by subsystem**; do not hide untested security code behind a global %.
2. Replace global Supabase SDK access with injected interfaces/fakes so failures are deterministic and quiet (fix tests that swallow "not initialized" assertions).

**Validation:** Coverage report is per-subsystem; security subsystems (RLS/protocol from [Phase 1](phase-1-trust-boundaries.md)) show real coverage; no test relies on swallowed SDK assertions.

---

### W3.10 — ProGuard + Baseline Profile (hygiene)

**Tasks**
1. Replace broad ProGuard keeps (Flutter/plugin/Google sign-in) with **evidence-based** rules after release tests; verify no runtime breakage.
2. Add an app-specific **Macrobenchmark / Baseline Profile** module for startup + critical flows (after the architecture is stable).

**Validation:** Release build with tightened keeps passes E2E (W3.6); Baseline Profile measurably improves startup/critical-flow jank (record before/after).

---

## Phase 3 exit criteria

Close only with device-named evidence in `plans/progress/phase-3-progress.md`:

- [ ] Crash/ANR/perf reporting live; forced crash appears deobfuscated with tags; disclosures updated (W3.1).
- [ ] Semantics coverage + non-color cues + 200% text + reduced motion; Accessibility Scanner + TalkBack pass (W3.2).
- [ ] Real gen-l10n localization; locale drives strings + direction; AR/EN + plurals/long/numerals tested (W3.3).
- [ ] Native libs 16 KB-aligned; runs on a 16 KB device (W3.4).
- [ ] Release-artifact assertions pass; upgrade-from-older-build works (W3.5).
- [ ] Four-device E2E passes every scenario; reconnect p95 < 5 s, no leak/dup (W3.6).
- [ ] Acceptance matrix captured and targets met on the device matrix; traces saved (W3.7).
- [ ] Resilience scenarios degrade gracefully (W3.8).
- [ ] Per-subsystem coverage; deterministic test infra (W3.9).
- [ ] Evidence-based ProGuard keeps; Baseline Profile added (W3.10).

---

## 📋 Reporting requirement (repeat)

Keep `plans/progress/phase-3-progress.md` current after every session and every completed item — every result must name the **actual device + Android version**, cite the trace number vs. its target, and link saved artifacts. No claim without device-named evidence; report failures and skips honestly.
