# Instructions: Migrate Flutter Poker-Style Card Game Off `setState`

## Role
You are refactoring an existing Flutter card game (poker-like). Your ONLY job is to change **how state is stored and propagated to the UI**. You must NOT change game rules, card logic, scoring, dealing order, win conditions, animations, or any other behavior. If you are unsure whether something is "logic" or "state plumbing," treat it as logic and leave it untouched.

## Non-negotiable constraints
1. **Zero functional changes.** Every existing feature must behave identically before and after the migration (same outputs for same inputs, same UI, same edge cases).
2. **No `setState` anywhere** in the final code.
3. **No rewriting of game rules/algorithms.** Card comparison, hand evaluation, shuffling, dealing, turn order, betting logic, etc. must be moved, not rewritten. Copy-paste the logic into the new layer; do not "improve" or "simplify" it as a side effect.
4. **Incremental, verifiable steps.** Never do a big-bang rewrite of the whole app in one shot. Migrate one screen/feature at a time and confirm it still works before moving to the next.
5. **Preserve public behavior of existing classes** (method names/signatures used elsewhere) unless the refactor explicitly requires a rename — and if it does, update every call site.

## Recommended state management: Riverpod
For a game of this size and complexity (a single/few-screen card game with clear, mostly self-contained game state), use **Riverpod** with `Notifier` / `AsyncNotifier` classes.

Why Riverpod over the alternatives:
- **Provider**: simpler, but weaker at handling derived/computed state (e.g., "current hand ranking," "valid moves") without extra boilerplate, and it's easy to accidentally rebuild too much of the widget tree.
- **Bloc/Cubit**: excellent separation of concerns but adds event/state-class boilerplate that's overkill for a game this size. Reasonable alternative if you strongly prefer explicit event-driven architecture — see fallback section below.
- **Riverpod**: compile-safe, testable outside widgets (important for verifying game logic didn't change), supports fine-grained rebuilds via `ref.watch(provider.select(...))`, and cleanly separates game logic (`Notifier`) from UI (`ConsumerWidget`). This keeps game logic in plain, easily-diffable Dart classes — good for a "don't touch the logic" migration.

**Fallback option:** If the codebase already has strong opinions (e.g., an existing Bloc dependency, or the team's convention), use **Bloc/Cubit** instead, following the same phased process below with Cubits replacing Notifiers. Do not mix Riverpod and Bloc in the same codebase.

## Target architecture
```
lib/
  models/            # Pure data classes (Card, Player, Hand, GameState, etc.) — unchanged logic, moved as-is
  logic/             # Pure game-rule functions/classes (dealing, hand evaluation, win checks) — unchanged, moved as-is
  state/
    game_notifier.dart      # Riverpod Notifier<GameState> — owns mutable game state
    game_providers.dart     # Provider declarations
  ui/
    screens/         # ConsumerWidget / ConsumerStatefulWidget (only for local UI-only state like animation controllers)
    widgets/
```

Note: `ConsumerStatefulWidget` + `State` is allowed ONLY for purely visual, non-game state (e.g. `AnimationController`, scroll position). It must never hold game state and must never call `setState` to reflect game state changes — that goes through Riverpod.

## Step-by-step process for the agent

### Phase 0 — Inventory (do this first, produce a report, do not edit code yet)
1. Find every `setState` call in the project. List file, line, and what data it mutates.
2. Find every class extending `State<...>` and list which fields are game state vs. pure UI state (e.g., animation, scroll, focus).
3. Identify the "source of truth" objects for the game (e.g., deck, players, current turn, pot, hand rankings, game phase). List them with their current type/location.
4. Map data flow: which widgets read this state, which widgets/callbacks mutate it.
5. Output this inventory as a checklist before writing any new code. This is your migration map — every item must be checked off by the end.

### Phase 1 — Add Riverpod, no behavior change yet
1. Add `flutter_riverpod` to `pubspec.yaml`.
2. Wrap the app's root widget in `ProviderScope` in `main.dart`. Nothing else changes yet.
3. Confirm the app still builds and runs exactly as before.

### Phase 2 — Extract state model (pure data, no logic changes)
1. If game state is currently scattered across multiple `State` fields, define a single immutable `GameState` class (or a small set of related classes) in `models/` that holds exactly the same fields, same types, same values as before. Do not add/remove/rename fields unless strictly necessary for immutability (e.g., converting a mutable `List` to be copied on change) — note any such change explicitly.
2. Add a `copyWith` method for immutable updates.
3. Do not touch game-rule logic in this phase — only data containers.

### Phase 3 — Move logic, unchanged, into a Notifier
1. Create `game_notifier.dart` with a class `GameNotifier extends Notifier<GameState>` (or `AsyncNotifier` if any async work like animations/delays/network is involved).
2. For every method that used to live in a `State` class and call `setState(() { ... })`:
   - Copy the method body verbatim into the Notifier.
   - Replace the `setState(() { <mutations> })` wrapper with: compute the new `GameState` via `copyWith`, then `state = newState`.
   - **Do not alter the order of operations or the conditions inside the mutation.** Only change *how* the result gets assigned.
3. Register the notifier: `final gameProvider = NotifierProvider<GameNotifier, GameState>(GameNotifier.new);`

### Phase 4 — Convert widgets
1. Change `StatefulWidget`/`State` screens that only read/display game state into `ConsumerWidget`, using `ref.watch(gameProvider)` (or `ref.watch(gameProvider.select((s) => s.someField))` for narrow rebuilds).
2. Replace calls like `setState(() => somethingLocal)` used to trigger game actions with `ref.read(gameProvider.notifier).theSameMethodName(...)`.
3. Keep purely visual local state (animation controllers, hover/focus, scroll) in a lightweight `ConsumerStatefulWidget` if truly needed — but it must never hold or mutate game data.
4. Do this **one screen/widget at a time**. After each widget, run the app and manually re-test that feature before moving to the next.

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
