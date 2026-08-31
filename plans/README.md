# Google Play Readiness — Remediation Plans

This folder breaks the [Google Play Deep Audit (2026-08-31)](../GOOGLE_PLAY_DEEP_AUDIT_2026-08-31.md) into **five sequential, executable plans**, one per remediation phase from the audit's "Recommended remediation order". Each plan is self-contained: it states its objective, lists the exact audit findings it closes, gives concrete tasks with file pointers and validation steps, and defines its exit criteria.

**Status: the app is NOT READY for Google Play production.** These plans exist to close every blocker with evidence.

## The five phases

| # | Plan | Objective | Gating |
|---|------|-----------|--------|
| 0 | [Make a Play-safe artifact](phase-0-play-safe-artifact.md) | Remove the sideload updater + restricted permission, fail-closed signing, current signed AAB, CI verification gates, privacy policy / Data Safety inventory / account deletion, UGC decision. | **Blocks submission.** Do this first. |
| 1 | [Repair trust boundaries](phase-1-trust-boundaries.md) | Move authority to a trusted backend, bind actions to authenticated users, separate public/private state, kill raw hand broadcasts, harden RLS/RPCs + migrations, make stats server-derived, add adversarial tests. | Depends on Phase 0's environment/flavor work. |
| 2 | [Remove scaling bottlenecks](phase-2-scaling-bottlenecks.md) | Deltas/checkpoints instead of whole snapshots, batch DB writes, images out of JSON, split providers/subscriptions, adaptive motion, fix repaints, bundle fonts, asset size. | Builds on Phase 1's authoritative model. |
| 3 | [Prove quality on real devices](phase-3-device-quality.md) | Crash/ANR observability, release + resilience + performance + accessibility + localization tests, 16 KB verification, device matrix, coverage gate. | Needs Phases 1–2 stable to measure. |
| 4 | [Controlled Play rollout](phase-4-controlled-rollout.md) | Store declarations/assets, App Signing, internal → closed → staged production, pre-launch reports, developer verification, vitals monitoring. | Only after Phases 0–3 close with evidence. |

## How to execute a plan

1. Open the phase plan. Read its **Findings covered** and **Exit criteria** first.
2. Work the items top-to-bottom (they are ordered by dependency where it matters).
3. **Keep a living progress report** — see the mandate below. This is not optional and is the whole point of splitting the work: the user tracks progress through these files.
4. Do not mark the phase complete until every exit criterion has a matching evidence line in the progress report.

## 📋 Mandatory reporting requirement (every plan)

Each plan ends with this same instruction, repeated here so it is impossible to miss:

> After **every** work session — and immediately after completing any single work item — the executing agent MUST create/update a thorough progress file at **`plans/progress/phase-<N>-progress.md`**, copied from [`progress/_TEMPLATE.md`](progress/_TEMPLATE.md).
>
> The progress file must be thorough enough that a reader who sees *only that file* knows exactly: what is done, what is verified (with real command output), what remains, and what is blocked. Record actual evidence — test counts, `flutter analyze` results, build outputs, signer digests, file paths, commit SHAs. Never claim a task is done without an evidence line. If something was skipped or only partially done, say so explicitly. Report failures with their output, not a summary that hides them.

Progress files live in [`progress/`](progress/). One per phase: `phase-0-progress.md` … `phase-4-progress.md`.

## Repo drift note (read before starting)

The audit was written against source version `1.10.0+21`. As of these plans, `pubspec.yaml` is **`1.11.0+22`**. Line numbers cited from the audit ("`file.dart:236`") may have shifted — **treat every line number as approximate and re-locate the code by symbol/content before editing.** File paths and the findings themselves were re-confirmed present (manifest permission, networking servers, root SQL files, single `release.yml`).

## Definition of ready (from the audit — the finish line for all five phases)

The game must not be submitted to production until:

- All **P0** findings are closed with evidence.
- All **P1 security** findings are closed.
- A signed **API-36 AAB** passes Play internal testing.
- Private cards cannot be obtained by any other identity.
- Competitive results cannot be client-forged.
- Account deletion works end-to-end (in-app + web).
- Policy disclosures match production behavior.
- The measured device matrix meets agreed performance / crash / ANR budgets.

## Finding-to-phase map

Every audit finding is assigned to exactly one owning phase (cross-references noted inside each plan).

| Finding | Owning phase |
|---|---|
| P0-01 APK self-update / `REQUEST_INSTALL_PACKAGES` | Phase 0 |
| P0-02 Release signing fails open | Phase 0 |
| P0-03 No Play AAB release path | Phase 0 |
| P0-07 Privacy policy / Data Safety / account deletion | Phase 0 |
| P0-08 UGC safeguards | Phase 0 |
| P2-10 Version duplication / update parsing | Phase 0 |
| P2-11 Dependency / license / content-rights review | Phase 0 |
| Hygiene: analyzer gate, archives/logs in VCS, CI pinning, workflow least-privilege, env/flavor separation | Phase 0 |
| P0-04 Private hands / full state exposed | Phase 1 |
| P0-05 Client impersonation / stat manipulation | Phase 1 |
| P0-06 Supabase RLS too broad | Phase 1 |
| P1-05 LAN server has no authenticated transport | Phase 1 |
| P1-08 DB state not reproducible from migrations | Phase 1 |
| P1-09 OAuth claimable custom scheme | Phase 1 |
| P1-10 Android backup not controlled | Phase 1 |
| Hygiene: hardcoded keys / env safety, sanitization tests overstate confidentiality | Phase 1 |
| P1-01 Whole-state broadcasts | Phase 2 |
| P1-02 Excessive/duplicate DB writes | Phase 2 |
| P1-03 Base64 profile photos | Phase 2 |
| P1-04 Broad provider subscriptions | Phase 2 |
| P1-06 Startup blocked by network auth | Phase 2 |
| P2-01 Adaptive animation/blur budget | Phase 2 |
| P2-02 Always-repainting painter | Phase 2 |
| P2-03 Side effects from build method | Phase 2 |
| P2-04 Runtime Google Fonts | Phase 2 |
| P2-05 Asset / download size | Phase 2 |
| P2-06 Audio timeouts | Phase 2 |
| P2-07 God classes | Phase 2 |
| P1-07 Crash / ANR / performance observability | Phase 3 |
| P2-08 Accessibility | Phase 3 |
| P2-09 Localization | Phase 3 |
| P2-12 16 KB page size verification | Phase 3 |
| Hygiene: ProGuard evidence-based keeps, deterministic test SDK access, Baseline Profile/Macrobenchmark | Phase 3 |
| Testing gaps 1–8, performance acceptance plan | Phase 1 (security suites) + Phase 3 (device/perf/a11y/resilience) |
| Store & operational checklist, rollout gates, developer verification | Phase 4 |
