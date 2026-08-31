# Phase 1 — Repair trust boundaries

> **Source:** [Google Play Deep Audit 2026-08-31](../GOOGLE_PLAY_DEEP_AUDIT_2026-08-31.md) · **Phase objective (verbatim):** "Redesign multiplayer around a trusted authority; bind actions to authenticated users; separate public/private state; eliminate raw hand broadcasts; harden RLS/RPCs; make stats server-derived; add adversarial database/protocol tests."

This phase fixes the fairness and confidentiality core of the game. Today a modified or curious client can read opponents' hands and forge competitive results, because authoritative state lives on a player's device and is broadcast/persisted raw, and Supabase policies use `USING (true)`. This is the largest engineering effort of the five phases.

## 📋 Mandatory reporting requirement — read first

After **every** work session and immediately after completing any single work item, create/update **`plans/progress/phase-1-progress.md`** (copy from [`progress/_TEMPLATE.md`](progress/_TEMPLATE.md)). A reader who sees only that file must know what is done, verified (with real evidence — RLS test-matrix results, captured realtime frames, adversarial test output), remaining, and blocked. No claim without evidence. State skips/partials; report failures with output. This is how the user keeps up.

## Findings covered

| Finding | Title | Gate |
|---|---|---|
| P0-04 | Private hands and full state are exposed | Multiplayer confidentiality |
| P0-05 | Clients can impersonate players / manipulate results | Multiplayer integrity |
| P0-06 | Supabase RLS exposes personal + game data too broadly | RLS |
| P1-05 | Client-hosted LAN server has no authenticated transport | (high) |
| P1-08 | Production DB state not reproducible from migrations | (high) |
| P1-09 | OAuth redirect uses a claimable custom scheme | (high) |
| P1-10 | Android backup behavior not explicitly controlled | (high) |
| — | Hardcoded keys / env safety (data-trust half); sanitization tests overstate real confidentiality | (hygiene) |
| Testing gaps 1–2 | RLS security suite; protocol abuse suite | (tests) |

> **Depends on:** [Phase 0](phase-0-play-safe-artifact.md) W0.9 (environment/flavor selection). **Feeds:** [Phase 2](phase-2-scaling-bottlenecks.md) (the authoritative model this phase creates is what Phase 2 optimizes) and [Phase 0](phase-0-play-safe-artifact.md) W0.4 (account-deletion backend).

---

## Architectural direction (read before the items)

The audit's required fix is to **move authoritative state transitions to a trusted backend** and stop trusting client-supplied identity. Concretely:

- A **trusted authority** (Supabase Edge Function / server-side reducer, or a dedicated relay) validates every action against `auth.uid()`, room membership, and turn legality — then computes the new state.
- **Public state** (whose turn, played cards, scores) is stored/broadcast to the room. **Private per-user hands** are stored separately and delivered only on a **user-specific authenticated channel**. No payload ever contains an opponent's hand.
- **Stats/XP** are written only by the server from server-recorded match outcomes; clients cannot write competitive fields.

The existing `toSanitizedJson` on the game model (audit notes it exists but transport paths bypass it) is the seed for public/private separation — but sanitization at the client is not sufficient once the model already contains every hand. The authority must never hand a client data it shouldn't see in the first place.

Pick and record the authority substrate in the progress report (Edge Functions vs. relay service) before large code changes — it shapes everything downstream.

---

## Work items

### W1.1 — Move authoritative game state to a trusted authority (P0-04, P0-05)

**Why:** `lib/networking/game_server.dart` runs on a player device, accepts `playerId` + action fields from clients (audit: lines ~327–538), and holds/advances authoritative state. The host is just another player.

**Tasks**
1. Stand up the trusted authority (decision from "Architectural direction"). Define the action protocol: small, versioned action messages (not whole-state).
2. Bind **every** action to `auth.uid()` server-side. Reject actions whose claimed `playerId` ≠ the authenticated user.
3. Validate membership + turn legality server-side before applying an action.
4. Use **idempotent action IDs** and **monotonic sequence numbers**; reject replays and out-of-order actions.
5. **Rate-limit** actions and resyncs per user; strictly bound reaction/metadata length and frequency server-side.
6. Apply to all three modes: Estimation (`lib/networking/game_server.dart:587`, `:751-758`), Ninety-Nine (`lib/modes/ninety_nine/networking/ninety_nine_game_server.dart:302`), Basra (`lib/modes/basra/networking/basra_game_server.dart:249`).

**Files:** trusted-authority code (new), `lib/networking/game_server.dart`, `lib/networking/game_client.dart`, `lib/networking/messages.dart`, the two mode servers, the game model(s).

**Validation:** See W1.6 adversarial suite. A client submitting another user's `playerId`, a replayed action, or an out-of-order action is rejected server-side.

---

### W1.2 — Separate public state from private hands; deliver hands per-user (P0-04)

**Why:** Servers broadcast `_state.toJson()` (full state incl. every hand) and persist it as `game_state`; reconnection storage keeps full `game_state` + per-player `hand_cards`.

**Tasks**
1. Split the persisted/broadcast model: **public state** (turn, table, scores, phase) vs. **private per-user hand** (owner-only).
2. Broadcast only public state to the room. Deliver each private hand only on that user's authenticated channel.
3. Store private hands in an owner-only table (RLS: `auth.uid() = user_id`), never inside a broadly readable room row. Consider encrypting private hands at rest.
4. Ensure resync/reconnect (`supabase_reconnection_migration.sql`) rebuilds a user from public state + only their own hand.

**Files:** game model(s), the three servers, `supabase_reconnection_migration.sql` → convert to an ordered migration (W1.5).

**Validation:** Capture realtime frames for a 4-player game and confirm **no opponent cards appear anywhere** in any payload any client receives. With 4 test identities, each token retrieves only public state + its own hand.

---

### W1.3 — Server-derived stats / XP; users cannot write competitive fields (P0-05, P0-06 overlap)

**Why:** `supabase_profiles.sql:79` exposes `increment_player_stats`, and profile update policy lets users update their own row including competitive fields — so XP/wins are client-authoritative.

**Tasks**
1. Compute match outcomes + XP **only** from server-recorded match results (the authority from W1.1).
2. Revoke client ability to update XP, wins, level, games-played. Split the profile into non-competitive (user-editable: display name within limits, avatar choice) vs. competitive (server-only) columns, or gate competitive writes behind a `SECURITY DEFINER` function that only the authority can call.
3. Harden `increment_player_stats` and any other definer function (see W1.4).

**Files:** `supabase_profiles.sql` → migration, authority code.

**Validation:** A client attempting to update XP/wins/level/games-played directly is rejected by RLS. Forged wins, negative/huge XP submissions are rejected (W1.6).

---

### W1.4 — Harden RLS and `SECURITY DEFINER` functions (P0-06)

**Why:** `supabase_profiles.sql:27` selects all profile rows (table includes email at line 8); `game_history_migration.sql:20` uses `USING (true)`; `supabase_migration.sql:45,58` allow all users to select rooms + room players; `supabase_security_patch.sql:22` still uses `USING (true)`. Definer functions don't consistently pin `search_path`, validate callers, cap values, or revoke from `PUBLIC`. Anonymous sign-in makes "authenticated" a weak boundary.

**Tasks**
1. Replace every `USING (true)` select policy with owner/member/recipient predicates.
2. Remove email from any publicly selectable profile view; use a separate public profile table/view (public columns only) vs. a private one (email etc.).
3. Harden **every** `SECURITY DEFINER` function: `SET search_path`, validate the caller (`auth.uid()`), bound inputs, `REVOKE EXECUTE ... FROM PUBLIC` then `GRANT` to intended roles only, transaction-safe authorization.
4. Treat "authenticated" as insufficient: scope policies to membership/ownership, not merely a logged-in role.

**Files:** `supabase_profiles.sql`, `game_history_migration.sql`, `supabase_migration.sql`, `supabase_security_patch.sql`, `supabase_fix.sql`, `supabase_99_mode_migration.sql` — all reconciled into ordered migrations (W1.5).

**Validation:** The RLS matrix (W1.6) shows email is not selectable by non-owners, history is owner-only, rooms/room-players are member-only, and no definer function is callable by `PUBLIC`.

---

### W1.5 — Reproducible migrations; reconcile drift (P1-08)

**Why:** Schema/policy changes are scattered across root-level SQL files plus a small `supabase/migrations` set (three files confirmed present). It's unclear which were applied, in what order; comments and actual policies conflict.

**Tasks**
1. Generate a reviewed **production schema dump** and reconcile drift against the repo SQL.
2. Convert every change (all root `supabase_*.sql`, `game_history_migration.sql`, `supabase_99_mode_migration.sql`, `supabase_reconnection_migration.sql`) into **ordered, idempotent** migrations under `supabase/migrations/`.
3. Add **local Supabase CI** that applies migrations from scratch and runs the RLS suite (W1.6).
4. Prohibit dashboard-only production changes (document the policy).

**Files:** `supabase/migrations/` (canonical set), CI.

**Validation:** A clean database built only from `supabase/migrations/` reproduces the intended schema + policies; CI proves it. Root-level ad-hoc SQL files are removed or clearly marked historical.

---

### W1.6 — Adversarial DB + protocol test suites (Testing gaps 1–2)

**Why:** Existing anti-cheat/sanitization tests exercise model methods, but live transport bypasses them — tests **overstate** real online confidentiality.

**Tasks**
1. **RLS security matrix:** for every table and role (anonymous, unrelated authenticated, room member, room host, service role) test read/insert/update/delete/RPC **and realtime visibility**. Include cross-player hand reads (must fail).
2. **Protocol abuse suite:** spoofed IDs, replay, reordering, oversized payloads, reaction spam, unauthorized join, forged score, host takeover, disconnect storms — all must be rejected.
3. Wire both suites into CI (local Supabase for RLS).
4. Fix tests that currently swallow "Supabase not initialized" assertions by injecting interfaces/fakes (also see [Phase 3](phase-3-device-quality.md)).

**Files:** `test/` (new security + protocol suites), CI.

**Validation:** Both suites run green in CI and demonstrably fail if a policy is loosened to `USING (true)` or identity binding is removed (add a canary test that flips one and expects failure).

---

### W1.7 — Authenticated LAN transport (P1-05)

**Why:** The local server binds `InternetAddress.anyIPv4:7890` over `ws://`; any device on the network can connect, spoof messages, enumerate, or flood. `NEARBY_WIFI_DEVICES` runtime handling wasn't found in Dart and needs device validation.

**Tasks**
1. Add an ephemeral room secret + handshake; authenticate messages with MACs.
2. Enforce strict message schema + size limits; add connection/action rate limits and idle timeouts.
3. Add local-network permission UX; validate `NEARBY_WIFI_DEVICES` behavior on physical devices across API 24–36 (device work coordinates with [Phase 3](phase-3-device-quality.md)).
4. Prefer a trusted relay for competitive play (aligns with W1.1); keep LAN for casual/offline only, clearly scoped.

**Files:** `lib/networking/game_server.dart`, `lib/networking/game_client.dart`, `lib/networking/messages.dart`, Android manifest/permission UX.

**Validation:** An unauthenticated peer on the LAN cannot join or inject actions; oversized/malformed frames are rejected; rate limits and idle timeout fire. Cleartext policy verified on API 24–36 devices (Phase 3 records device evidence).

---

### W1.8 — OAuth redirect hardening (P1-09)

**Why:** `io.supabase.kotshina://login-callback` is a claimable custom scheme; another app could register it and intercept the redirect.

**Tasks**
1. Prefer verified **HTTPS App Links** with Digital Asset Links (`assetlinks.json`).
2. Retain PKCE + state + nonce validation; strictly validate redirect host/path.
3. If the custom scheme stays as fallback, document residual risk and test malicious-handler behavior.

**Files:** Android manifest (intent filters + `assetlinks`), Supabase auth redirect config, auth handling in `lib/`.

**Validation:** App Link opens the app for the verified domain; a second app registering the old scheme cannot intercept the primary flow; PKCE/state/nonce rejection paths tested.

---

### W1.9 — Control Android backup (P1-10)

**Why:** No `dataExtractionRules`/backup policy found; preferences can hold session/profile/avatar data; default backup may move data the auth design didn't intend.

**Tasks**
1. Define Android 12+ `dataExtractionRules` and legacy `fullBackupContent` rules.
2. Exclude auth tokens, session caches, room state, and sensitive user data from cloud/device-transfer backup.
3. Test restore onto a fresh device — the user must **not** be silently authenticated with stale credentials.

**Files:** `android/app/src/main/AndroidManifest.xml`, new backup-rules XML resources.

**Validation:** Restore-to-fresh-device test shows no silent auth and no sensitive data carried over.

---

### W1.10 — Close the env/data-trust half (from Phase 0 W0.9)

**Why:** Phase 0 made environments selectable; the data-trust consequence is that RLS is the *only* real confidentiality boundary and anonymous sign-in is cheap.

**Tasks**
1. Confirm no code path depends on "authenticated" as a security boundary (W1.4 must scope by ownership/membership).
2. Verify staging and prod are fully isolated (no shared tables, no dev writes to prod).
3. Confirm no service-role key is reachable from the client.

**Files:** migrations, client init, CI.

**Validation:** Anonymous and unrelated-authenticated roles fail every confidentiality assertion in the RLS matrix (W1.6).

---

## Phase 1 exit criteria

Close only when each has evidence in `plans/progress/phase-1-progress.md`:

- [ ] A trusted authority validates every action against `auth.uid()`, membership, turn legality; replays/reorders/rate-abuse rejected — across all three modes (W1.1).
- [ ] Public state and private hands are separated; captured realtime frames contain **no** opponent cards; each identity retrieves only public state + its own hand (W1.2).
- [ ] Stats/XP are server-derived; clients cannot write competitive fields; forged/negative/huge submissions rejected (W1.3).
- [ ] No `USING (true)` select policies remain; email not selectable by non-owners; every definer function hardened (search_path, caller check, bounds, revoke/grant) (W1.4).
- [ ] The database is reproducible from ordered migrations; local Supabase CI proves it (W1.5).
- [ ] RLS matrix + protocol abuse suites run in CI and fail closed on canary regressions (W1.6).
- [ ] LAN transport is authenticated, schema/size/rate limited (W1.7).
- [ ] OAuth uses verified App Links; interception mitigated; PKCE/state/nonce validated (W1.8).
- [ ] Backup rules exclude tokens/sessions/sensitive data; fresh-device restore shows no silent auth (W1.9).
- [ ] "Authenticated" is nowhere used as the confidentiality boundary; staging/prod isolated; no client service-role key (W1.10).

---

## 📋 Reporting requirement (repeat)

Keep `plans/progress/phase-1-progress.md` current after every session and every completed item — thorough enough to stand alone, with real evidence (RLS matrix output, captured frames proving no opponent cards, adversarial test results). No claim without evidence; report failures and skips honestly.
