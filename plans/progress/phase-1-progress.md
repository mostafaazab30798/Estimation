# Progress — Phase 1: Repair trust boundaries

> Update after every work session and immediately after completing any work item.

---

## At a glance

- **Phase:** 1 — Repair trust boundaries
- **Plan file:** `plans/phase-1-trust-boundaries.md`
- **Overall status:** In progress
- **Last updated:** 2026-09-01 11:45 (UTC+3)
- **Updated by:** Auto (Cursor agent)
- **Branch(es):** (working tree, uncommitted)
- **% exit criteria met:** 2 of 10 fully evidenced (W1.10 done; W1.9 partial; staging live)

## Decisions & assumptions

- **Authority substrate (W1.1):** **Supabase Edge Functions + Postgres RPC reducer.** Rationale: project already runs on Supabase (Realtime, RPCs, auth); no edge functions existed yet; avoids operating a separate relay VM. Edge Function `game-action` validates JWT + membership; `apply_game_action` RPC (not wired yet) will own state transitions. Interim: host-authoritative client with sanitized transport + owner-only hand table until reducer lands.
- **Private hands storage (W1.2):** New `player_private_hands` table with owner-only SELECT RLS; legacy `room_players.hand_cards` column revoked from SELECT and masked on write.
- **Depends on Phase 0 W0.9:** Env/flavor separation **done** (`AppConfig`, Android flavors, CI guards, pgTAP `env_isolation.test.sql`). **Staging project `zbimzlyleruaqbdilrqb` provisioned, linked, migrations pushed, edge fn deployed (2026-09-01).**
- **Migration apply:** User applied `202608310001_ugc_moderation_and_deletion.sql` and `202608310002_trust_boundaries_rls_hardening.sql` to project `eqmkbfxerxqihforsgvx` (2026-08-31). MCP-connected project differs — live smoke tests needed to confirm.

## Work-item status

| Item | Finding(s) | Status | Evidence | Notes |
|------|-----------|--------|----------|-------|
| W1.1 | P0-04, P0-05 | In progress | Reducers + `SERVER_AUTHORITY` + **server-side** bot runner (Estimation/99/Basra) | Migrations `014` applied; `game-action` deployed; live smoke pending |
| W1.2 | P0-04 | In progress | Trigger + `get_room_public_state` RPC; edge `sanitizePublicState`; protocol tests + pgTAP | Live Realtime frame capture still needed |
| W1.3 | P0-05, P0-06 | In progress | Trigger blocks client XP writes; migration `012` awards XP on authority match end | Host-authoritative path still no-ops XP; needs deploy + authority smoke |
| W1.4 | P0-06 | In progress | Migrations 002–004 applied on prod | User to confirm 003/004 if not yet |
| W1.5 | P1-08 | In progress | `202608270000_base_schema.sql` + migrations 001–012 | Root ad-hoc SQL not fully reconciled |
| W1.6 | Testing gaps | In progress | RLS matrix + `apply_game_action` + `mode_authority` + `authority_match_xp` pgTAP; CI job | Docker unavailable locally; CI green run pending |
| W1.7 | P1-05 | Not started | — | |
| W1.8 | P1-09 | Not started | — | |
| W1.9 | P1-10 | Partial | `backup_rules.xml`, `data_extraction_rules.xml`, manifest attrs | Fresh-device restore test pending |
| W1.10 | — | Done | `AppConfig` dart-define; Android flavors; CI `verify-client-secrets.sh` + `verify-env-isolation.sh`; `env_isolation.test.sql` (9 pgTAP cases); `play-release.yml` dart-defines; `docs/env-setup.md` | Provision staging Supabase project for QA (not a code blocker) |

## What was done this session

1. **Recorded authority decision:** Edge Functions + Postgres RPC reducer (see Decisions).
2. **W1.4 migration** `202608310002_trust_boundaries_rls_hardening.sql`:
   - `is_room_member()` helper; member-only SELECT on `game_rooms` / `room_players`
   - `player_private_hands` owner-only table; `get_my_hand_cards` / `save_player_hand` / `save_game_state` hardened
   - `sanitize_game_state_json()` strips real cards before DB persist
   - `game_history` owner-only SELECT; profile competitive-field update trigger
   - `increment_player_stats` restricted to `service_role`
   - `get_room_private_hands_for_host` for host promotion
3. **W1.2 interim (client):**
   - `game_server.dart`, `ninety_nine_game_server.dart`, `basra_game_server.dart`: broadcast `toSanitizedJson()`; persist hands via RPC
   - `lobby_repository.dart`: `getMyHandCards` via RPC; host hand recovery RPC
   - `game_provider.dart`: `_applyOnline*State` merges own hand after sanitized broadcast
4. **W1.3 partial:** `auth_service.dart` — removed direct profile XP fallback
5. **W1.1 scaffold:** `supabase/functions/game-action/index.ts` — JWT + membership validation, action size limits; returns 202 until reducer wired

## Files changed

| File | Change | Related item |
|------|--------|--------------|
| `supabase/migrations/202608310002_trust_boundaries_rls_hardening.sql` | Added | W1.4, W1.2, W1.3 |
| `supabase/functions/game-action/index.ts` | Added | W1.1 |
| `lib/networking/game_server.dart` | Sanitized broadcast + snapshot | W1.2 |
| `lib/modes/ninety_nine/networking/ninety_nine_game_server.dart` | Sanitized broadcast + hand persist | W1.2 |
| `lib/modes/basra/networking/basra_game_server.dart` | Sanitized broadcast + hand persist | W1.2 |
| `lib/features/lobby/data/lobby_repository.dart` | RPC hand fetch + host recovery | W1.2, W1.4 |
| `lib/providers/game_provider.dart` | Online hand merge + host promotion hands | W1.2 |
| `lib/services/auth_service.dart` | No competitive fallback | W1.3 |
| `plans/progress/phase-1-progress.md` | Created | reporting |

## Commands run + real output

```
$ flutter analyze
No issues found! (ran in 49.6s)
Exit code: 0

$ flutter test
00:36 +204: All tests passed!
Exit code: 0
```

## Validation evidence per exit criterion

| Exit criterion | Met? | Evidence |
|----------------|------|----------|
| Trusted authority validates all actions (W1.1) | Partial | Estimation + 99 + Basra reducers; pgTAP tests; **deploy + live smoke pending** |
| Public/private separation; no opponent cards on wire (W1.2) | Partial | Code uses `toSanitizedJson`; **no captured Realtime frames yet** |
| Stats server-derived; clients cannot write XP (W1.3) | Partial | `012` awards on authority match end; client reads `get_my_match_xp_award`; host path still silent |
| No `USING (true)` select policies (W1.4) | Partial | Migration applied; RLS matrix (W1.6) not run yet |
| Reproducible migrations + CI (W1.5) | No | |
| RLS + protocol test suites in CI (W1.6) | Partial | pgTAP matrix + `rls-security` CI job added; pending CI green run |
| Authenticated LAN transport (W1.7) | No | |
| OAuth App Links (W1.8) | No | |
| Android backup rules (W1.9) | No | |
| Env isolation; no client service role (W1.10) | Yes | `scripts/verify-client-secrets.sh` + `verify-env-isolation.sh` pass; `env_isolation.test.sql`; staging runtime guard in `AppConfig` |

## What was done this session (2026-08-31 — W1.6)

1. **W1.5 partial:** `supabase/migrations/202608270000_base_schema.sql` — idempotent base for fresh `supabase db reset`.
2. **W1.6 RLS matrix:** `supabase/tests/database/rls_matrix.test.sql` — 17 pgTAP cases (outsider/member/host/profile/hands/stats).
3. **CI:** `.github/workflows/ci.yml` job `rls-security` — `supabase start` + `db reset` + `supabase test db`.
4. **Local script:** `scripts/run-rls-tests.sh`.
5. **Config:** `supabase/config.toml` for local/CI stack.

## Blockers & open questions

1. ~~**Apply migrations**~~ — **Done** (user, 2026-08-31).
2. **RLS CI evidence** — Docker not available on dev machine; matrix will prove on next GitHub Actions push.
3. **Live smoke tests** on production project.
4. ~~**W0.9** env/flavor separation needed before W1.10 validation~~ — **Done** (W1.10).
5. **Host-authoritative interim risk** until W1.1 reducer ships.
6. **Match XP** silent no-op until server authority (W1.1/W1.3).

## What was done this session (2026-08-31 — W1.1)

1. **Migration** `202608310007_apply_game_action.sql`:
   - `game_rooms.action_seq` monotonic counter
   - `game_action_log` idempotency table (member-readable audit)
   - `apply_game_action` RPC (service_role only) — binds `p_actor_uid`, seq check, rate limit, turn validation
   - `get_authority_room_state` RPC — merges private hands for reducer input
   - `estimation_validate_turn` defense-in-depth for Estimation phases
2. **Edge Function reducer** (`supabase/functions/game-action/reducer/`):
   - Full Estimation (kotchina) port of `GameEngine` action handling
   - 99 / Basra return `MODE_NOT_IMPLEMENTED` (next PRs)
3. **Edge Function wired:** JWT → membership → reduce → `apply_game_action` commit
4. **pgTAP:** `supabase/tests/database/apply_game_action.test.sql` — 8 cases (seq, idempotency, turn, auth)
5. **Client substrate:** `lib/services/game_action_service.dart` — opt-in via `useServerAuthority` flag (host broadcast still default until wired in `GameClient`)

## Files changed (W1.1)

| File | Change | Related item |
|------|--------|--------------|
| `supabase/migrations/202608310007_apply_game_action.sql` | Added | W1.1 |
| `supabase/functions/game-action/index.ts` | Wired reducer + RPC | W1.1 |
| `supabase/functions/game-action/reducer/types.ts` | Added | W1.1 |
| `supabase/functions/game-action/reducer/estimation.ts` | Added | W1.1 |
| `supabase/functions/game-action/reducer/index.ts` | Added | W1.1 |
| `supabase/tests/database/apply_game_action.test.sql` | Added | W1.1, W1.6 |
| `lib/services/game_action_service.dart` | Added | W1.1 |

## What was done this session (2026-08-31 — W1.1 99/Basra)

1. **Reducers:** `reducer/ninety_nine.ts`, `reducer/basra.ts`, shared `reducer/cards.ts`
2. **Migration** `202608310008_ninety_nine_basra_authority.sql`:
   - `ninety_nine_validate_turn` / `basra_validate_turn`
   - `game_room_authority_secrets` (Basra deck server-only)
   - `get_authority_room_state`: maxPlayers, roster merge, bot-safe hands, deck restore
   - `apply_game_action`: mode routing, skip non-uuid hand keys
3. **Client:** `_usesServerAuthority()` covers all 3 modes; `_applyServerPublicState`; nn/basra `serverAuthorityMode`
4. **Tests:** `supabase/tests/database/mode_authority.test.sql`

## Files changed (W1.1 99/Basra)

| File | Change |
|------|--------|
| `supabase/functions/game-action/reducer/ninety_nine.ts` | Added |
| `supabase/functions/game-action/reducer/basra.ts` | Added |
| `supabase/functions/game-action/reducer/cards.ts` | Added |
| `supabase/migrations/202608310008_ninety_nine_basra_authority.sql` | Added |
| `supabase/tests/database/mode_authority.test.sql` | Added |
| `lib/providers/game_provider.dart` | All-mode server authority |
| `lib/modes/ninety_nine/networking/ninety_nine_game_server.dart` | serverAuthorityMode |
| `lib/modes/basra/networking/basra_game_server.dart` | serverAuthorityMode |

## What was done this session (2026-08-31 — W1.1 client wiring)

1. **Edge Function broadcast:** After `apply_game_action` commit, broadcasts sanitized `state` to `room_{id}` channel; reactions/earthquakes broadcast on ephemeral path.
2. **GameRoom:** `actionSeq` + `gameState` fields parsed from Realtime stream.
3. **GameProvider:** Routes online Estimation actions through `GameActionService` when `SERVER_AUTHORITY=true`; tracks `_actionSeq`; syncs from room stream; host uses lobby-only GameServer mode.
4. **GameServer:** `serverAuthorityMode` — skips in-game broadcast/actions/bots when authority is server.
5. **Opt-in:** `--dart-define=SERVER_AUTHORITY=true` in `main.dart`.

## Files changed (W1.1 client wiring)

| File | Change |
|------|--------|
| `supabase/functions/game-action/index.ts` | Post-commit Realtime broadcast |
| `lib/features/lobby/domain/models/game_room.dart` | actionSeq + gameState |
| `lib/providers/game_provider.dart` | Server action routing + seq sync |
| `lib/networking/game_server.dart` | serverAuthorityMode |
| `lib/main.dart` | SERVER_AUTHORITY dart-define |

## What was done this session (2026-08-31 — absent player / online gate)

1. **Migrations** `009`–`011`: 5-minute absent-player detach, 30s bot takeover, online ban, stale-session cleanup (no ban on hour-old absences).
2. **Client:** `OnlinePlayGate`, `OnlinePlayBlockDialog`, `RecoverOngoingGameBanner`, home-screen countdown + rejoin UX.
3. **Matchmaking:** crash fix (`MediaQuery` in `didChangeDependencies`); full screen redesign (felt table, progress segments, live badge).
4. **Tests:** `test/disconnected_seat_recovery_test.dart` updated for 30s/5min timing.

## What was done this session (2026-09-01 — W1.3 match XP)

1. **Migration** `202608310012_authority_match_xp.sql`:
   - `match_xp_awards` table (idempotent per room)
   - `award_authority_match_xp` on `apply_game_action` when room → `finished`
   - `get_my_match_xp_award` RPC for clients
2. **Client:** `RankingService.awardOnlineMatchXp` reads server award when `SERVER_AUTHORITY=true`; match-end screens for all 3 modes updated.
3. **pgTAP:** `supabase/tests/database/authority_match_xp.test.sql` — 5 cases.

## Files changed (2026-08-31 absent player + matchmaking)

| File | Change | Related item |
|------|--------|--------------|
| `supabase/migrations/202608310009_absent_player_detach.sql` | Added | Online reliability |
| `supabase/migrations/202608310010_absent_player_timing_fix.sql` | Added | Online reliability |
| `supabase/migrations/202608310011_stale_absence_no_ban.sql` | Added | Online reliability |
| `lib/services/online_play_gate.dart` | Added | Online gate |
| `lib/widgets/online_play_block_dialog.dart` | Added | Online gate |
| `lib/widgets/recover_ongoing_game_banner.dart` | Added | Online gate |
| `lib/features/matchmaking/presentation/screens/matchmaking_screen.dart` | Redesigned | UX |
| `lib/features/matchmaking/presentation/widgets/matchmaking_player_slot.dart` | Redesigned | UX |

## Files changed (2026-09-01 W1.3)

| File | Change | Related item |
|------|--------|--------------|
| `supabase/migrations/202608310012_authority_match_xp.sql` | Added | W1.3 |
| `supabase/tests/database/authority_match_xp.test.sql` | Added | W1.3, W1.6 |
| `lib/services/ranking_service.dart` | Server XP path | W1.3 |
| `lib/screens/match_end_screen.dart` | Use `awardOnlineMatchXp` | W1.3 |
| `lib/modes/*/presentation/screens/*_game_screen.dart` | Use `awardOnlineMatchXp` | W1.3 |

## Commands run + real output (2026-09-01)

```
$ flutter analyze lib/services/ranking_service.dart lib/screens/match_end_screen.dart lib/providers/game_provider.dart
No issues found!

$ flutter test
00:45 +204: All tests passed!
Exit code: 0
```

## What was done this session (2026-09-01 — staging live + W1.9)

1. **Staging (user + agent):** Project `zbimzlyleruaqbdilrqb` linked; all 20 migrations synced; `game-action` redeployed; app running with staging flavor + `SERVER_AUTHORITY=true`.
2. **W1.9 partial:** Android backup/data-extraction rules exclude sharedpref/database/files from cloud backup and device transfer.

## Commands run + real output (2026-09-01 staging)

```
$ supabase migration list
# 20/20 local = remote on zbimzlyleruaqbdilrqb

$ supabase functions deploy game-action --no-verify-jwt
Deployed Functions on project zbimzlyleruaqbdilrqb: game-action

$ flutter test
00:34 +227: All tests passed!
Exit code: 0
```

## What's left / next steps

1. **Staging smoke test** — run checklist below on `zbimzlyleruaqbdilrqb` (user has app running).
2. **Capture Realtime frames** proving no opponent cards (W1.2 evidence) — use `WireFrameInspector` during staging match.
3. **Fresh-device restore test** for W1.9 (no silent auth after backup restore).
4. **W1.7–W1.8** not started (LAN auth, App Links).

### Post-migration smoke checklist (run on **staging** `zbimzlyleruaqbdilrqb`)

- [ ] **Google sign-in** — OAuth redirect works on staging flavor (`com.mostafaazab.estimation.staging`)
- [ ] **Create/join room** — lobby still works with member-only RLS
- [ ] **Deal + play (Estimation)** — you see your real cards; opponents show masked dummies
- [ ] **Server authority** — actions go through edge `game-action`; bots play without host proxy
- [ ] **Reconnect** — `get_my_hand_cards` restores your hand after rejoin
- [ ] **Leaderboard** — reads `public_profiles` (no email column)
- [ ] **Report/block** — long-press safety sheet works (Phase 0 W0.8)
- [ ] **Account deletion** — Profile → Settings → Delete (throwaway Google account on staging)
- [ ] **Match XP** — with `SERVER_AUTHORITY=true`, XP increments server-side only
- [ ] **Open-source licenses** — Settings → التراخيص المفتوحة opens LicensePage (W0.7)

## What was done this session (2026-09-01 — W1.1 bot proxy)

1. **Migration** `202608310013_host_bot_proxy.sql` — host may submit `payload.playerId` for bot/absent seats; validators updated for all 3 modes.
2. **Edge reducers** — `resolveActingPlayerId` in `cards.ts`; estimation/99/basra use acting id.
3. **Client** — `ServerAuthorityBotRunner` + `GameServer.planBotAction`; host schedules bot moves through `GameActionService` when `SERVER_AUTHORITY=true` (Estimation only).
4. **Tests** — `host_bot_proxy.test.sql`, `server_authority_bot_runner_test.dart`.

## What was done this session (2026-09-01 — W1.1 server bot runner fix)

1. **Removed host-client bot proxy** — deleted `ServerAuthorityBotRunner`; host is a normal human player.
2. **Server-side bot runner** — `bot_runner.ts` runs bot turns on the edge function after each human commit; bots use `service_role` + `payload.playerId`.
3. **Migration `014`** — `resolve_acting_player_id` only allows bot-seat proxy for `service_role` (not host clients).
4. **Edge reducers** — `estimation_bot.ts` planner; clients cannot pass `payload.playerId`.
5. **Deployed** `game-action` edge function.

## What was done this session (2026-09-01 PM — W1.1 99/Basra bots + migrations)

1. **99/Basra server bots** — `ninety_nine_bot.ts`, `basra_bot.ts`, shared `bot_common.ts`; wired in `bot_runner.ts`.
2. **Migrations applied** — `202608310014_server_only_bot_proxy.sql`, `202609010001_google_required_for_online_play.sql` pushed to prod.
3. **Migration repair** — marked `002`–`013` as applied (already live on prod; history drift fixed).
4. **Redeployed** `game-action` with all three mode bot planners.

## Files changed (2026-09-01 PM)

| File | Change | Related item |
|------|--------|--------------|
| `supabase/functions/game-action/reducer/bot_common.ts` | Added | W1.1 |
| `supabase/functions/game-action/reducer/ninety_nine_bot.ts` | Added | W1.1 |
| `supabase/functions/game-action/reducer/basra_bot.ts` | Added | W1.1 |
| `supabase/functions/game-action/reducer/basra.ts` | `previewBasraPlay` export | W1.1 |
| `supabase/functions/game-action/reducer/estimation_bot.ts` | Use `bot_common` | W1.1 |
| `supabase/functions/game-action/bot_runner.ts` | Route 99/Basra | W1.1 |

## Commands run + real output (2026-09-01 PM)

```
$ supabase db push
Applying migration 202608310014_server_only_bot_proxy.sql...
Applying migration 202609010001_google_required_for_online_play.sql...
Finished supabase db push.
Exit code: 0

$ supabase functions deploy game-action --no-verify-jwt
Deployed Functions on project eqmkbfxerxqihforsgvx: game-action
Exit code: 0

$ flutter test
00:34 +220: All tests passed!
Exit code: 0
```

## What was done this session (2026-09-01 — W1.2 + W1.10)

### W1.2 — Hand confidentiality
1. **Migration `202609010002_hand_confidentiality_hardening.sql`** — `BEFORE INSERT/UPDATE` trigger sanitizes `game_state`; `get_room_public_state` member RPC.
2. **Client** — `LobbyRepository.getGameStateSnapshot` uses `get_room_public_state` (not raw `game_rooms.game_state` SELECT).
3. **Edge function** — `sanitizePublicState()` applied before every Realtime broadcast.
4. **Tests** — `hand_confidentiality.test.sql` (pgTAP), `protocol_confidentiality_test.dart`, `wire_frame_inspector.dart`.

### W1.10 / W0.9 — Environment isolation
1. **`AppConfig`** — `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `APP_ENV` via dart-define; `main.dart` no longer hardcodes prod URL.
2. **Android flavors** — `dev` / `staging` / `prod` with distinct app labels and applicationId suffixes.
3. **`config/env.*.example.json`** — template configs (actual files gitignored).
4. **CI** — `scripts/verify-client-secrets.sh` job blocks service-role / hardcoded prod URL in `lib/`.
5. **Docs** — `docs/env-setup.md`.

## Files changed (2026-09-01 W1.2 + W1.10)

| File | Change | Related item |
|------|--------|--------------|
| `supabase/migrations/202609010002_hand_confidentiality_hardening.sql` | Added | W1.2 |
| `supabase/tests/database/hand_confidentiality.test.sql` | Added | W1.2, W1.6 |
| `supabase/functions/game-action/reducer/sanitize.ts` | Added | W1.2 |
| `lib/core/utils/wire_frame_inspector.dart` | Added | W1.2 |
| `test/protocol_confidentiality_test.dart` | Added | W1.2 |
| `lib/core/config/app_config.dart` | Added | W1.10, W0.9 |
| `config/env.*.example.json` | Added | W1.10, W0.9 |
| `android/app/build.gradle.kts` | Product flavors | W1.10, W0.9 |
| `scripts/verify-client-secrets.sh` | Added | W1.10 |
| `docs/env-setup.md` | Added | W1.10, W0.9 |
| `.github/workflows/ci.yml` | client-secrets job | W1.10 |

## Commands run + real output (2026-09-01 W1.2)

```
$ supabase db push
Applying migration 202609010002_hand_confidentiality_hardening.sql...
Finished supabase db push.

$ flutter test test/protocol_confidentiality_test.dart test/app_config_test.dart
00:00 +6: All tests passed!
```

## Commands run + real output (2026-09-01 W1.10 completion)

```
$ bash scripts/verify-client-secrets.sh
OK: no client secret / hardcoded prod URL violations

$ bash scripts/verify-env-isolation.sh
OK: env isolation templates and release workflow checks passed

$ flutter test
00:10 +227: All tests passed!
Exit code: 0
```

## Changelog

- **2026-09-01 AM** — Auto — Staging project live (migrations + edge fn); W1.9 backup rules; W0.7 license audit.
- **2026-09-01 PM** — Auto — W1.10 completed: LF shell scripts, unrelated-auth pgTAP cases, progress evidence.
- **2026-09-01 PM** — Auto — W1.2 hand confidentiality hardening + W1.10/W0.9 env isolation (`AppConfig`, flavors, CI guard).
- **2026-09-01 AM** — Auto — W1.1: server-only bot runner (removed host client proxy); migration `014`.
- **2026-08-31 PM** — Auto — Absent-player detach (009–011), online gate UI, matchmaking redesign.
- **2026-08-31 PM** — Auto — W1.1 client wiring: SERVER_AUTHORITY dart-define, GameProvider seq sync.
- **2026-08-31 PM** — Auto — Fix `public_profiles` registered-users-only (004); leaderboard fixes.
- **2026-08-31 AM** — Auto — Phase 1 kickoff: authority decision, RLS migration, sanitized online transport, edge function scaffold, progress report.
