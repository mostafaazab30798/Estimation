# Progress — Phase <N>: <phase title>

> Copy this file to `phase-<N>-progress.md` before you start work on the phase.
> Update it **at the end of every work session** and **immediately after completing any work item**.
> Goal: a reader who sees only this file should know exactly what is done, verified, remaining, and blocked.
> Rules: record real command output, not summaries. Never mark a task done without an evidence line. State skips/partials explicitly. Report failures with their output.

---

## At a glance

- **Phase:** <N> — <title>
- **Plan file:** `plans/phase-<N>-<slug>.md`
- **Overall status:** Not started | In progress | Blocked | Complete
- **Last updated:** YYYY-MM-DD HH:MM (timezone)
- **Updated by:** <agent/model or person>
- **Branch(es):** <branch names>
- **% exit criteria met:** X of Y

## Work-item status

One row per work item in the plan. Keep IDs identical to the plan so they line up.

| Item | Finding(s) | Status | Evidence (commit / file / command output ref) | Notes |
|------|-----------|--------|-----------------------------------------------|-------|
| W0.1 | P0-01 | Done / In progress / Blocked / Not started / Skipped | e.g. commit `abc1234`; manifest diff | |
| …    |            |        |                                               | |

Status legend: **Done** = implemented AND validated with evidence. **In progress** = started, not validated. **Blocked** = cannot proceed (say why in Blockers). **Skipped** = deliberately not done (say why).

## What was done this session

Chronological, specific. Name the files and symbols you changed, the decisions you made, and why.

- 

## Files changed

| File | Change | Related item |
|------|--------|--------------|
| | | |

## Commands run + real output

Paste the actual output (trimmed to the relevant lines). Include the command and its exit status.

```
$ flutter test
... (real output: e.g. "All tests passed! 00:42 +212")

$ flutter analyze
... (real output: e.g. "17 issues found." or "No issues found!")

$ <build / signer / migration / other verification command>
...
```

## Validation evidence per exit criterion

Copy each exit criterion from the plan and mark whether it is met, with the proof.

| Exit criterion | Met? | Evidence |
|----------------|------|----------|
| | Yes / No / Partial | |

## Blockers & open questions (needs user/owner decision)

Anything you cannot resolve yourself — missing secrets, Play Console access, product decisions (e.g. keep vs. remove UGC), backend hosting choices.

- 

## Decisions & assumptions

Record choices you made so they can be reviewed. Note any assumption that, if wrong, changes the work.

- 

## What's left / next steps

Concrete next actions, ordered.

- 

## Changelog

Append a dated entry every session so progress is legible over time. Newest first.

- **YYYY-MM-DD** — <who> — <what changed in this report / what advanced>
