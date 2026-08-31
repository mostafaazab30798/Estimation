# Progress — Phase 1: Repair trust boundaries

> Update after every work session and immediately after completing any work item.

---

## At a glance

- **Phase:** 1 — Repair trust boundaries
- **Plan file:** `plans/phase-1-trust-boundaries.md`
- **Overall status:** In progress
- **Last updated:** 2026-08-31 13:15 (UTC+3)
- **Updated by:** Auto (Cursor agent) + user confirmation
- **Branch(es):** (working tree, uncommitted)
- **% exit criteria met:** 0 of 10 (migrations applied; live validation pending)

## Decisions & assumptions

- **Authority substrate (W1.1):** **Supabase Edge Functions + Postgres RPC reducer.** Rationale: project already runs on Supabase (Realtime, RPCs, auth); no edge functions existed yet; avoids operating a separate relay VM. Edge Function `game-action` validates JWT + membership; `apply_game_action` RPC (not wired yet) will own state transitions. Interim: host-authoritative client with sanitized transport + owner-only hand table until reducer lands.
- **Private hands storage (W1.2):** New `player_private_hands` table with owner-only SELECT RLS; legacy `room_players.hand_cards` column revoked from SELECT and masked on write.
- **Depends on Phase 0 W0.9:** Env/flavor separation not done; proceeding with RLS/migrations that are environment-agnostic. Staging/prod isolation (W1.10) blocked until W0.9.
- **Migration apply:** User applied `202608310001_ugc_moderation_and_deletion.sql` and `202608310002_trust_boundaries_rls_hardening.sql` to project `eqmkbfxerxqihforsgvx` (2026-08-31). MCP-connected project differs — live smoke tests needed to confirm.

## Work-item status

| Item | Finding(s) | Status | Evidence | Notes |
|------|-----------|--------|----------|-------|
| W1.1 | P0-04, P0-05 | In progress | `supabase/functions/game-action/index.ts` scaffold | Reducer RPC + client wiring not done |
| W1.2 | P0-04 | In progress | Sanitized broadcast + RPC hand merge in client | Migration applied; **smoke test online game + frame capture still needed** |
| W1.3 | P0-05, P0-06 | In progress | Migration applied: competitive trigger + service_role-only stats RPC | Match-end XP now no-ops from client until server authority ships |
| W1.4 | P0-06 | In progress | Migrations applied; **`202608310003` fixes leaderboard view** | User to apply 003 |
| W1.5 | P1-08 | In progress | `202608270000_base_schema.sql` for local CI | Root ad-hoc SQL not fully reconciled |
| W1.6 | Testing gaps | In progress | `supabase/tests/database/rls_matrix.test.sql` + CI job | 17 pgTAP cases; needs Docker/CI run for evidence |
| W1.7 | P1-05 | Not started | — | |
| W1.8 | P1-09 | Not started | — | |
| W1.9 | P1-10 | Not started | — | |
| W1.10 | — | Not started | — | Blocked on W0.9 |

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
| Trusted authority validates all actions (W1.1) | No | Scaffold only |
| Public/private separation; no opponent cards on wire (W1.2) | Partial | Code uses `toSanitizedJson`; **no captured Realtime frames yet** |
| Stats server-derived; clients cannot write XP (W1.3) | Partial | Trigger + service_role RPC; no match-outcome authority yet |
| No `USING (true)` select policies (W1.4) | Partial | Migration applied; RLS matrix (W1.6) not run yet |
| Reproducible migrations + CI (W1.5) | No | |
| RLS + protocol test suites in CI (W1.6) | Partial | pgTAP matrix + `rls-security` CI job added; pending CI green run |
| Authenticated LAN transport (W1.7) | No | |
| OAuth App Links (W1.8) | No | |
| Android backup rules (W1.9) | No | |
| Env isolation; no client service role (W1.10) | No | |

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
4. **W0.9** env/flavor separation needed before W1.10 validation.
5. **Host-authoritative interim risk** until W1.1 reducer ships.
6. **Match XP** silent no-op until server authority (W1.1/W1.3).

## What's left / next steps

1. Push to GitHub and confirm `rls-security` job passes (evidence for W1.6).
2. Wire `apply_game_action` Postgres RPC + Edge Function reducer (W1.1).
3. Capture 4-player Realtime frames (W1.2 validation).
4. Protocol abuse suite (W1.6 part 2).
5. Finish root SQL reconciliation (W1.5).

### Post-migration smoke checklist

- [ ] **Create/join room** — lobby still works with member-only RLS
- [ ] **Deal + play (Estimation)** — you see your real cards; opponents show masked dummies
- [ ] **Reconnect** — `get_my_hand_cards` restores your hand after rejoin
- [ ] **Leaderboard** — reads `public_profiles` (no email column)
- [ ] **Report/block** — long-press safety sheet works (Phase 0 W0.8)
- [ ] **Account deletion** — Profile → Settings → Delete (throwaway account)
- [ ] **Match XP** — expected to **not** increment until server authority (W1.1/W1.3 complete)

## Changelog

- **2026-08-31 PM** — Auto — W1.6 RLS pgTAP matrix, base schema migration, CI `rls-security` job.
- **2026-08-31 PM** — Auto — Fix `public_profiles` registered-users-only (004); leaderboard fixes.
- **2026-08-31 AM** — Auto — Phase 1 kickoff: authority decision, RLS migration, sanitized online transport, edge function scaffold, progress report.
