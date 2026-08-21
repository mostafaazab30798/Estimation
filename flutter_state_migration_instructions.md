# Instructions: Migrate Flutter Poker-Style Card Game Off `setState`

## Role
You are refactoring an existing Flutter card game (poker-like). Your ONLY job is to change **how state is stored and propagated to the UI**. You must NOT change game rules, card logic, scoring, dealing order, win conditions, animations, or any other behavior. If you are unsure whether something is "logic" or "state plumbing," treat it as logic and leave it untouched.

## Non-negotiable constraints
1. **Zero functional changes.** Every existing feature must behave identically before and after the migration (same outputs for same inputs, same UI, same edge cases).
2. **No `setState` anywhere** in the final code.
3. **No rewriting of game rules/algorithms.** Card comparison, hand evaluation, shuffling, dealing, turn order, betting logic, etc. must be moved, not rewritten. Copy-paste the logic into the new layer; do not "improve" or "simplify" it as a side effect.
4. **Incremental, verifiable steps.** Never do a big-bang rewrite of the whole app in one shot. Migrate one screen/feature at a time and confirm it still works before moving to the next.
5. **Preserve public behavior of existing classes** (method names/signatures used elsewhere) unless the refactor explicitly requires a rename — and if it does, update every call site.

## Recommended state management: Provider (already in the project)
The app already depends on `provider`, so **stay on Provider** — do not introduce Riverpod, Bloc, or any other package. Provider is fully capable of clean, `setState`-free state management for a game this size, and adding a second state-management library would mean rewriting working screens for no functional benefit and would violate the "don't mess with the logic" constraint by increasing the blast radius of the migration.

Use the standard Provider pattern:
- **`ChangeNotifier`** subclasses as the source of truth for game state (e.g., `GameNotifier extends ChangeNotifier`), calling `notifyListeners()` after each mutation instead of `setState`.
- **`ChangeNotifierProvider`** (or `MultiProvider` if you split state into more than one notifier, e.g. `GameNotifier` + a separate `SettingsNotifier`) registered above the widget tree that needs it.
- **`context.watch<GameNotifier>()`** or `Consumer<GameNotifier>` in widgets that need to rebuild on state changes.
- **`context.read<GameNotifier>()`** for one-off calls in callbacks (button presses, etc.) that don't need the widget to rebuild.
- **`Selector<GameNotifier, T>`** where you want to rebuild only when a specific derived value changes (e.g., only when the winner is determined, not on every card animation tick) — this is Provider's equivalent of Riverpod's fine-grained `select`.

This keeps the same package, the same mental model your team already uses, and still gets you to zero `setState` calls with clean separation between game logic and UI.

## Target architecture
```
lib/
  models/            # Pure data classes (Card, Player, Hand, GameState, etc.) — unchanged logic, moved as-is
  logic/             # Pure game-rule functions/classes (dealing, hand evaluation, win checks) — unchanged, moved as-is
  state/
    game_notifier.dart      # ChangeNotifier — owns mutable game state, calls notifyListeners()
  ui/
    screens/         # StatelessWidget using context.watch / Consumer / Selector
    widgets/
```

Note: A `StatefulWidget` + `State` is allowed ONLY for purely visual, non-game state (e.g. `AnimationController`, scroll position). It must never hold game state and must never call `setState` to reflect game state changes — that goes through the `ChangeNotifier` + Provider.

## Step-by-step process for the agent

### Phase 0 — Inventory (do this first, produce a report, do not edit code yet)
1. Find every `setState` call in the project. List file, line, and what data it mutates.
2. Find every class extending `State<...>` and list which fields are game state vs. pure UI state (e.g., animation, scroll, focus).
3. Identify the "source of truth" objects for the game (e.g., deck, players, current turn, pot, hand rankings, game phase). List them with their current type/location.
4. Map data flow: which widgets read this state, which widgets/callbacks mutate it.
5. Output this inventory as a checklist before writing any new code. This is your migration map — every item must be checked off by the end.

### Phase 1 — Confirm current Provider setup, no behavior change yet
1. Check the `provider` version in `pubspec.yaml` (bump only if it's very outdated, and note that separately — don't bundle a package upgrade into this refactor unless required).
2. Confirm there is (or will be) a `MultiProvider`/`ChangeNotifierProvider` near the app root in `main.dart` where the new `GameNotifier` can be registered. If one already exists for other state, plan to add `GameNotifier` alongside it rather than creating a second, competing provider tree.
3. Confirm the app still builds and runs exactly as before — no code changes yet in this phase.

### Phase 2 — Extract state model (pure data, no logic changes)
1. If game state is currently scattered across multiple `State` fields, define a single immutable `GameState` class (or a small set of related classes) in `models/` that holds exactly the same fields, same types, same values as before. Do not add/remove/rename fields unless strictly necessary for immutability (e.g., converting a mutable `List` to be copied on change) — note any such change explicitly.
2. Add a `copyWith` method for immutable updates.
3. Do not touch game-rule logic in this phase — only data containers.

### Phase 3 — Move logic, unchanged, into a ChangeNotifier
1. Create `game_notifier.dart` with a class `GameNotifier extends ChangeNotifier`. It can either hold the `GameState` fields directly, or hold a single `GameState state` field internally — pick whichever requires the smaller diff from the current code layout.
2. For every method that used to live in a `State` class and call `setState(() { ... })`:
   - Copy the method body verbatim into `GameNotifier`.
   - Replace the `setState(() { <mutations> })` wrapper with: perform the same mutations (either directly on the notifier's fields, or via `state = state.copyWith(...)`), then call `notifyListeners()` as the last step.
   - **Do not alter the order of operations or the conditions inside the mutation.** Only change *how* the UI gets told to rebuild.
3. Register it in `main.dart` (or wherever the existing provider tree lives): `ChangeNotifierProvider(create: (_) => GameNotifier())`, added into the existing `MultiProvider` if one is already there.

### Phase 4 — Convert widgets
1. Change `StatefulWidget`/`State` screens that only read/display game state into `StatelessWidget`, reading state via `context.watch<GameNotifier>()` or wrapping just the relevant subtree in a `Consumer<GameNotifier>` (preferred when only part of the widget tree needs to rebuild).
2. Use `Selector<GameNotifier, T>` for widgets that only care about one derived value (e.g. current winner, pot total) so they don't rebuild on unrelated state changes.
3. Replace calls like `setState(() => somethingLocal)` used to trigger game actions with `context.read<GameNotifier>().theSameMethodName(...)` inside callbacks (`onPressed`, etc.) — `read`, not `watch`, since these are one-off calls, not places that need to rebuild.
4. Keep purely visual local state (animation controllers, hover/focus, scroll) in a lightweight `StatefulWidget` if truly needed — but it must never hold or mutate game data.
5. Do this **one screen/widget at a time**. After each widget, run the app and manually re-test that feature before moving to the next.

### Phase 5 — Cleanup
1. Search the whole project again for `setState` — there should be zero remaining occurrences of it affecting game logic (a stray one for a pure UI animation, if unavoidable, must be explicitly flagged to the user, not silently left in).
2. Remove now-unused old state classes/fields.
3. Run `flutter analyze` and fix only issues introduced by the refactor — do not "fix" pre-existing unrelated warnings.

### Phase 6 — Verification
1. For every item in the Phase 0 inventory, confirm it's been migrated and behaves identically.
2. If tests exist, run them. If no tests exist, write a short manual test checklist covering: dealing, turn progression, hand evaluation/winner determination, betting/scoring (if present), game reset/new round, and any edge cases you noticed in Phase 0 (e.g., tie-breaking, empty deck, all-in).
3. Report back: what changed structurally, what stayed identical logically, and any spot where you had to make a judgment call (flag these explicitly for human review rather than deciding silently).

## Guardrails to repeat to the agent at every phase
- "Moving" code means copy the logic as-is; "refactoring state" does not mean "cleaning up" the algorithm.
- If a game-rule function has a bug or odd edge case, **do not fix it** — leave it as-is and note it separately as an observation, not part of this task.
- If unsure whether a piece of code is state-plumbing or game logic, stop and ask rather than guessing.
- After each phase, do a diff review: the only changes should be *where* state lives and *how* it's updated, not *what* it computes.
