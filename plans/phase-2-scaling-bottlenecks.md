# Phase 2 — Remove scaling bottlenecks

> **Source:** [Google Play Deep Audit 2026-08-31](../GOOGLE_PLAY_DEEP_AUDIT_2026-08-31.md) · **Phase objective (verbatim):** "Replace whole snapshots with deltas/checkpoints; batch writes; move images out of JSON; split providers and subscriptions; stop offstage/reduced-motion animations; fix unnecessary repaints; bundle fonts."

The audit's headline: the primary performance bottleneck is **not** card rendering — it's the network/state architecture (large whole-game snapshots broadcast + persisted often, private/image data duplicated inside them, multiple DB calls per move, broad provider rebuilds). This phase makes the game scale to four players, long games, custom photos, weak networks, and low-memory devices.

## 📋 Mandatory reporting requirement — read first

After **every** work session and immediately after completing any single work item, create/update **`plans/progress/phase-2-progress.md`** (copy from [`progress/_TEMPLATE.md`](progress/_TEMPLATE.md)). A reader who sees only that file must know what's done, verified (with real evidence — payload-byte measurements, DevTools rebuild/repaint counts, DB-write counts per move), remaining, blocked. No claim without evidence. State skips/partials; report failures with output.

## Findings covered

| Finding | Title |
|---|---|
| P1-01 | Whole-state broadcasts are the dominant network bottleneck |
| P1-02 | A single move triggers excessive/duplicate DB writes |
| P1-03 | Base64 profile photos multiply payload + memory |
| P1-04 | Broad provider subscriptions rebuild large game screens |
| P1-06 | Startup blocked by network-dependent auth |
| P2-01 | Animation/blur budget not adaptive enough |
| P2-02 | Always-repainting custom painter |
| P2-03 | Side effects scheduled from a build method |
| P2-04 | Runtime Google Fonts create first-run network dependency |
| P2-05 | Asset/download size needs current AAB measurement |
| P2-06 | Audio timeouts don't cancel underlying operations |
| P2-07 | Large "god" classes increase regression risk |

> **Depends on:** [Phase 1](phase-1-trust-boundaries.md) — the authoritative public/private model is the substrate for deltas and per-recipient private updates. Do not optimize the broadcast before the authority exists, or you'll optimize the wrong shape.
> **Measurement note:** static inspection identifies risk; it does not replace profiling. Every item here needs a **before/after measurement** captured with DevTools (CPU, frame, memory, allocation, network payload, rebuild, repaint). Save trace artifacts alongside the progress report.

---

## Work items

### W2.1 — Deltas/checkpoints instead of whole-state broadcasts (P1-01)

**Why:** Servers broadcast full JSON after many actions (incl. invalid-action resyncs). The model grows with players, hands, tricks, scores, histories, embedded photos — serialize/transmit/parse/rebuild costs hit host and every client.

**Tasks**
1. Replace whole-state broadcasts with **small versioned action/event payloads**.
2. Send periodic **compact public snapshots** + **per-recipient private deltas** (uses Phase 1 public/private split).
3. Use monotonically increasing state versions; add an **explicit resync request** with rate limits (no auto full-state on every invalid action).
4. Apply across Estimation (`game_server.dart:587`), Ninety-Nine (`:302`), Basra (`:249`).

**Validation:** Measure **payload bytes + messages per completed trick** before/after. Target (from the acceptance plan): public payload preferably **< 10 KB/action**; document exceptions. Four players, final rounds/history at maximum size.

---

### W2.2 — One transactional checkpoint per authoritative boundary (P1-02)

**Why:** `_broadcastState` can persist on phase changes while action paths also persist a snapshot and save hands individually — up to one state RPC + four hand RPCs per move, sometimes plus phase persistence. Latency, battery, cost, write races, bad reconnect behavior.

**Tasks**
1. Commit **one authorized, transactional match checkpoint** at meaningful boundaries (not per side effect).
2. Batch private hand updates inside that transaction.
3. Debounce non-critical presence data.
4. Never block visual feedback on persistence (persist async after the UI updates).

**Validation:** Instrument and count DB writes per move: target **at most one transactional checkpoint per authoritative action/boundary** (acceptance plan). Four-player online game.

---

### W2.3 — Move images out of JSON to storage (P1-03)

**Why:** Custom images are resized but base64-encoded, stored in prefs/profile, copied into `Player`, and serialized with game state (~⅓ overhead before JSON overhead) — repeated copies/decodes.

**Tasks**
1. Upload a bounded **WebP/AVIF thumbnail** to a dedicated storage bucket; store only an **opaque path + version** in state.
2. Enforce owner write policies on the bucket; expose only intended thumbnails.
3. Cache decoded images client-side.
4. Remove **email** and **original image data** from public player objects (ties to [Phase 1](phase-1-trust-boundaries.md) W1.2 / [Phase 0](phase-0-play-safe-artifact.md) W0.8).

> If [Phase 0](phase-0-play-safe-artifact.md) W0.8 chose **Path A (preset avatars, no uploads)**, this item shrinks to "store a preset avatar id" — most of the base64 cost disappears. Record which path applies.

**Validation:** Player/state payloads contain no base64 image bytes and no email; only a path/version. Measure payload + memory before/after.

---

### W2.4 — Split providers + subscriptions to cut rebuilds (P1-04)

**Why:** The main Estimation screen has multiple `Consumer<GameProvider>` sections; Ninety-Nine and Basra watch full providers. Frequent `notifyListeners()` rebuilds HUDs, hands, player areas, animations, overlays for unrelated changes.

**Tasks**
1. Split state into immutable slices; use `Selector` / `context.select` for exact fields.
2. Isolate hands, trick, timers, reactions, connection state behind **`RepaintBoundary`**.
3. Keep animation controllers **below** stable subtrees.
4. Use DevTools' rebuild tracker to confirm reductions.

**Validation:** DevTools rebuild counts drop materially for an unrelated state change (e.g. a reaction shouldn't rebuild the hand). Record before/after counts.

---

### W2.5 — Non-blocking startup (P1-06)

**Why:** Bootstrap waits for device settings + auth init before entering the app; a returning Google user triggers profile refresh/network work without a bounded timeout; offline users are delayed or shown retry UI before reaching local modes.

**Tasks**
1. Render the shell from **cached state immediately**.
2. Move profile refresh to a **cancellable background task** with explicit timeout/retry budget.
3. Expose offline mode without waiting on the network.
4. Record startup timing from process start to first interactive frame.

**Validation:** Time to first interactive screen (acceptance plan): **p95 < 2.5 s warm, < 4.0 s cold**, offline and normal Wi-Fi. Offline launch reaches local modes without a network wait.

---

### W2.6 — Adaptive motion policy (P2-01)

**Why:** Repeating pulse/particle/background controllers + blur; low-spec mode mainly disables blur, not particles/repeats; device classification (low-RAM/CPU/SDK/model list) misses GPU/thermal/battery.

**Tasks**
1. One **motion-quality policy**: full / reduced / off.
2. Respect system accessibility "reduce motion" settings.
3. Pause offstage tickers with `TickerMode`; eliminate invisible controllers.
4. Profile sustained play under thermal throttling.

**Validation:** In reduced/off modes, particles and repeat animations actually stop (not just blur). Janky frames **< 1%** in a 20-minute match on a low-end/thermally-warmed device (acceptance plan).

---

### W2.7 — Fix the always-repainting painter + build-time side effects (P2-02, P2-03)

**Why:** `lib/widgets/estimation_poster_card.dart:957` returns `true` from `shouldRepaint`. The Basra screen schedules delayed overlay/flash logic while building; rebuild-driven timers can fire after navigation/disposal.

**Tasks**
1. `shouldRepaint`: compare immutable painter inputs; return true only when visual state changes. Put expensive stable layers behind `RepaintBoundary`; verify with repaint-rainbow.
2. Move Basra transitions out of `build` into a provider listener / `didUpdateWidget` / state-machine effect handler; track and cancel timers in `dispose`.

**Files:** `lib/widgets/estimation_poster_card.dart`, Basra screen(s) under `lib/modes/basra/`.

**Validation:** Repaint-rainbow shows the card no longer repaints every frame. No timer fires after navigation/disposal (add a disposal guard test).

---

### W2.8 — Bundle fonts; disable runtime fetch (P2-04)

**Why:** `google_fonts` with no bundled assets and no runtime-fetch disable → first use may fetch fonts (font swap, offline inconsistency, network disclosure, layout timing). This may also explain the audit's stalled AAB build ([Phase 0](phase-0-play-safe-artifact.md) W0.3).

**Tasks**
1. Bundle licensed Cairo/Cinzel (or the actual fonts used) assets; declare in `pubspec.yaml`.
2. Set `GoogleFonts.config.allowRuntimeFetching = false`.
3. Verify licenses (feeds [Phase 0](phase-0-play-safe-artifact.md) W0.7 provenance).

**Validation:** Cold **offline** launch renders correct fonts with no swap and no network call for fonts.

---

### W2.9 — Asset/download size (P2-05)

**Why:** Declared card themes ≈ 12.3 MB; on-disk assets ≈ 22.2 MB (incl. undeclared wallpaper/card files); stale universal APK ≈ 76.3 MB — none are current Play delivery sizes.

**Tasks**
1. Build a current AAB (from [Phase 0](phase-0-play-safe-artifact.md) W0.3) and run Play size analysis.
2. Remove unused assets; compress large PNG/JPEG or convert suitable artwork to WebP.
3. Avoid packaging all optional themes if they can be delivered on demand safely.

**Validation:** Record current AAB + delivered size; set a size budget from Play Console (finalized in [Phase 4](phase-4-controlled-rollout.md)). Undeclared assets are removed or declared.

---

### W2.10 — Audio lifecycle (P2-06)

**Why:** Audio stop/play futures are wrapped in very short timeouts; timeout completion doesn't cancel the native op, so rapid effects overlap or finish late.

**Tasks**
1. Use a small **effect-player pool** with explicit lifecycle/state.
2. Coalesce repeated sounds; cancel delayed haptics where possible.
3. Measure audio-thread/device behavior on low-end hardware.

**Validation:** Rapid repeated effects don't overlap/leak; measured on a low-end device.

---

### W2.11 — Decompose god classes (P2-07)

**Why:** `GameProvider` and profile/game screens combine networking, persistence, transitions, timers, matchmaking, mode logic, UI — subtle reconnect/perf defects are hard to isolate/test.

**Tasks**
1. Separate transport, authoritative reducer, persistence, matchmaking, presence, profile storage, and presentation controllers.
2. Keep reducers **pure**; property-test legal transitions.

> This is the natural landing zone for the Phase 1 authority refactor on the client side — coordinate so you decompose once, not twice.

**Validation:** Reducer is pure and property-tested; provider no longer owns transport + persistence + UI in one class.

---

## Phase 2 exit criteria

Close only with before/after measurements in `plans/progress/phase-2-progress.md`:

- [ ] Whole-state broadcasts replaced by versioned actions + compact public snapshots + per-recipient private deltas; public payload measured (target < 10 KB/action) (W2.1).
- [ ] ≤ one transactional checkpoint per authoritative boundary; hand writes batched; feedback not blocked on persistence (W2.2).
- [ ] No base64 image bytes / email in state; images in storage referenced by path/version; decoded images cached (W2.3).
- [ ] Selector/RepaintBoundary split; DevTools shows reduced rebuilds for unrelated changes (W2.4).
- [ ] Shell renders from cache immediately; profile refresh backgrounded/bounded; offline reaches local modes; startup p95 targets met (W2.5).
- [ ] Motion policy full/reduced/off honored incl. system reduce-motion; offstage tickers paused; jank < 1% in a 20-min match (W2.6).
- [ ] Poster-card `shouldRepaint` visual-state-gated; Basra side effects out of build with disposal-safe timers (W2.7).
- [ ] Fonts bundled; runtime fetch disabled; cold offline fonts correct (W2.8).
- [ ] Current AAB size measured; unused assets removed/compressed; size budget set (W2.9).
- [ ] Audio effect-player pool with lifecycle; no overlap/leak on rapid effects (W2.10).
- [ ] God classes decomposed; pure property-tested reducer (W2.11).

---

## 📋 Reporting requirement (repeat)

Keep `plans/progress/phase-2-progress.md` current after every session and every completed item — with **before/after measurements** (payload bytes, DB writes/move, rebuild/repaint counts, startup timing, jank %) and saved DevTools trace artifacts. No claim without a measurement; report regressions and skips honestly.
