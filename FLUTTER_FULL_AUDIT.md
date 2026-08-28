# Flutter Application Full Audit

## Executive Summary

Project context established from the repository:

- App: Estimation / Kotshina multiplayer card game
- Dart constraint: `^3.5.0`
- State management: Provider with `ChangeNotifier`
- Platforms: Android, iOS, Web
- Source size: approximately 70,000 Dart lines across 100+ files
- Assets: 227 files, 19.42 MB uncompressed
- Existing tests: 23 game-domain/widget test files
- Release shrinking: R8 and resource shrinking enabled on Android

Runtime profiling could not be completed in this environment because `flutter analyze`, `flutter test`, and `dart analyze` hung without output. No frame-time, startup-time, or memory numbers below are fabricated. These remain mandatory Phase 0 measurements.

| Severity | Performance | Design | Total |
|---|---:|---:|---:|
| Critical | 0 | 0 | 0 |
| High | 4 | 0 | 4 |
| Medium | 2 | 3 | 5 |
| Low | 0 | 0 | 0 |

Top fixes by impact-to-effort ratio:

1. Move nonessential initialization after `runApp`.
2. Remove state mutation and delayed scheduling from `GameScreen.build`.
3. Narrow top-level Provider subscriptions.
4. Dispose `PlayerHand` value notifiers.
5. Exclude unused full-resolution wallpapers from the application bundle.

Expected cumulative improvement cannot be quantified before profiling. The fixes should reduce time to first frame, game-screen rebuild scope, retained widget state, and APK assets by approximately 5.78 MB uncompressed.

## Full Findings List (Performance)

### Finding PERF-001: Startup Blocks Before First Frame
- **Category:** Startup
- **Severity:** High
- **File(s):** `lib/main.dart`
- **Line(s):** `main`, lines 29-75
- **Evidence:** `runApp` executes only after hardware detection, UI-mode operations, two image decodes, `Supabase.initialize`, and `AuthService.initialize`.
- **Root Cause:** Nonessential initialization is placed on the critical first-frame path.
- **Impact:** Cold starts wait for plugin calls, storage, image decoding, and network-capable SDK setup before displaying Flutter UI.
- **Fix - Exact Steps:**
  1. Keep only `WidgetsFlutterBinding.ensureInitialized`, orientation/system UI setup, and `runApp` before the first frame.
  2. Add a `bootstrapAfterFirstFrame` function.
  3. Initialize performance detection, audio, images, Supabase, auth, and anonymous authentication from that function.
  4. Add a boot state so routes requiring Supabase cannot execute before initialization completes.
- **Before Code:**
  ```dart
  await DevicePerformanceService.instance.initialize();
  await Future.wait([
    _preloadAsset('assets/wallpapers/w1.jpg'),
    _preloadAsset('assets/wallpapers/w2.jpg'),
  ]);
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await AuthService.instance.initialize();
  runApp(const KotshinaApp());
  ```
- **After Code:**
  ```dart
  Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    runApp(const KotshinaApp());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapAfterFirstFrame());
    });
  }

  Future<void> _bootstrapAfterFirstFrame() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    await Future.wait([
      DevicePerformanceService.instance.initialize(),
      AuthService.instance.initialize(),
      _preloadAsset('assets/wallpapers/w1.jpg'),
      _preloadAsset('assets/wallpapers/w2.jpg'),
    ]);

    unawaited(AudioService.instance.initialize());

    final auth = Supabase.instance.client.auth;
    if (auth.currentUser == null) {
      unawaited(auth.signInAnonymously());
    }
  }
  ```
- **Validation Step:** Measure cold start with `flutter run --profile --trace-startup`; compare time to first Flutter frame before and after.
- **Rollback Plan:** Restore initialization to its original position before `runApp`.
- **Dependencies:** Add explicit boot-state handling before applying this change.

### Finding PERF-002: Game Screen Rebuilds on Every Provider Notification
- **Category:** State
- **Severity:** High
- **File(s):** `lib/screens/game_screen.dart`, `lib/providers/game_provider.dart`
- **Line(s):** `GameScreen.build`; all `GameProvider.notifyListeners` call sites
- **Evidence:** `context.watch<GameProvider>()` wraps the entire game screen. The provider has at least 27 notification sites, while the screen also contains several nested `Consumer<GameProvider>` widgets.
- **Root Cause:** A broad root subscription invalidates the entire game layout before nested consumers perform their own rebuilds.
- **Impact:** Timer, connection, reaction, player, bid, or trick updates can relayout the complete game board.
- **Fix - Exact Steps:**
  1. Replace the root `watch` with selectors for `state`, `status`, and `isMyTurn`.
  2. Use `context.read<GameProvider>()` for commands.
  3. Retain leaf consumers only where their selected data changes independently.
- **Before Code:**
  ```dart
  final provider = context.watch<GameProvider>();
  final state = provider.state;
  final isMyTurn = provider.isMyTurn;
  ```
- **After Code:**
  ```dart
  final provider = context.read<GameProvider>();
  final state = context.select<GameProvider, GameState?>(
    (value) => value.state,
  );
  final status = context.select<GameProvider, ConnectionStatus>(
    (value) => value.status,
  );
  final isMyTurn = context.select<GameProvider, bool>(
    (value) => value.isMyTurn,
  );

  if (state == null || status != ConnectionStatus.connected) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AppTheme.gold),
      ),
    );
  }
  ```
- **Validation Step:** Enable DevTools "Track Widget Builds," play one card, and confirm unrelated HUD/background subtrees do not rebuild.
- **Rollback Plan:** Restore the single `context.watch<GameProvider>()` subscription.
- **Dependencies:** PERF-003 should be applied immediately afterward.

### Finding PERF-003: Build Method Mutates State and Schedules Timers
- **Category:** Rendering
- **Severity:** High
- **File(s):** `lib/screens/game_screen.dart`
- **Line(s):** `GameScreen.build`, lines 117-150
- **Evidence:** `build` changes `_delayingScoring`, `_lastAnnouncedDoubleRound`, `_showDoubleRoundOverlay`, `_lastAnnouncedFixedRound`, and `_showFixedTrumpOverlay`. It also creates a `Future.delayed`.
- **Root Cause:** Transition side effects are coupled to an idempotent rendering method.
- **Impact:** Rebuild frequency controls behavior. Duplicate callbacks, stale state, or inconsistent overlays can occur when inherited widgets or orientation trigger builds.
- **Fix - Exact Steps:**
  1. Add a `GameProvider` listener in `didChangeDependencies`.
  2. Move phase-transition and overlay detection into that listener.
  3. Store and cancel the scoring-delay timer.
  4. Remove all transition mutations from `build`.
- **Before Code:**
  ```dart
  if (phase == GamePhase.scoring &&
      _lastPhase == GamePhase.trickTaking &&
      !_delayingScoring) {
    _delayingScoring = true;
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _delayingScoring = false);
      }
    });
  }
  ```
- **After Code:**
  ```dart
  GameProvider? _observedProvider;
  Timer? _scoringDelayTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<GameProvider>();

    if (identical(provider, _observedProvider)) return;
    _observedProvider?.removeListener(_handleProviderChange);
    _observedProvider = provider;
    provider.addListener(_handleProviderChange);
    _handleProviderChange();
  }

  void _handleProviderChange() {
    final state = _observedProvider?.state;
    if (!mounted || state == null) return;

    final previousPhase = _lastPhase;
    _lastPhase = state.phase;

    if (state.phase == GamePhase.scoring &&
        previousPhase == GamePhase.trickTaking) {
      _scoringDelayTimer?.cancel();
      setState(() => _delayingScoring = true);
      _scoringDelayTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _delayingScoring = false);
      });
    }

    if (state.isDoubleRound &&
        _lastAnnouncedDoubleRound != state.roundNumber) {
      setState(() {
        _lastAnnouncedDoubleRound = state.roundNumber;
        _showDoubleRoundOverlay = true;
      });
    }

    if (state.fixedTrump != null &&
        _lastAnnouncedFixedRound != state.roundNumber) {
      setState(() {
        _lastAnnouncedFixedRound = state.roundNumber;
        _showFixedTrumpOverlay = true;
      });
    }
  }

  @override
  void dispose() {
    _scoringDelayTimer?.cancel();
    _observedProvider?.removeListener(_handleProviderChange);
    super.dispose();
  }
  ```
- **Validation Step:** Add a widget test that rebuilds `GameScreen` repeatedly without changing provider state and confirms overlays/timers trigger once.
- **Rollback Plan:** Restore transition logic to `build` and remove the provider listener.
- **Dependencies:** PERF-002.

### Finding PERF-004: Player Hand Retains Value Notifiers
- **Category:** Memory
- **Severity:** High
- **File(s):** `lib/widgets/player_hand.dart`
- **Line(s):** `_selected`, `_dragOffsetNotifier`, `dispose`
- **Evidence:** Both notifiers are created by the state object. `dispose` cancels timers and the animation controller but does not dispose either notifier.
- **Root Cause:** Owned `ChangeNotifier` resources are omitted from lifecycle cleanup.
- **Impact:** Listeners and their retained widget closures may survive after hands are replaced between rounds/screens.
- **Fix - Exact Steps:**
  1. Dispose `_selected`.
  2. Dispose `_dragOffsetNotifier`.
  3. Keep timer cancellation before notifier disposal.
- **Before Code:**
  ```dart
  @override
  void dispose() {
    _hapticTimer?.cancel();
    _impactPlayTimer?.cancel();
    _chargeCtrl.dispose();
    super.dispose();
  }
  ```
- **After Code:**
  ```dart
  @override
  void dispose() {
    _hapticTimer?.cancel();
    _hapticTimer = null;
    _impactPlayTimer?.cancel();
    _impactPlayTimer = null;
    _chargeCtrl.dispose();
    _selected.dispose();
    _dragOffsetNotifier.dispose();
    super.dispose();
  }
  ```
- **Validation Step:** Run a widget test that repeatedly mounts and unmounts `PlayerHand`; verify no "used after being disposed" exception and inspect DevTools memory for retained instances.
- **Rollback Plan:** Remove the two notifier disposal calls.
- **Dependencies:** None.

### Finding PERF-005: Unused Full-Resolution Wallpapers Are Bundled
- **Category:** Startup
- **Severity:** Medium
- **File(s):** `pubspec.yaml`
- **Line(s):** `flutter.assets`
- **Evidence:** `assets/wallpapers/` includes `w1_1.jpg` at 4000x6000/3.33 MB and `w2_1.jpg` at 3168x4752/2.45 MB. No Dart references to these files were found. Directory inclusion places them in the bundle.
- **Root Cause:** The whole wallpaper directory is declared instead of enumerating runtime assets.
- **Impact:** Approximately 5.78 MB of uncompressed source imagery is shipped unnecessarily.
- **Fix - Exact Steps:**
  1. Replace the wallpaper directory declaration with explicit runtime files.
  2. Do not delete source originals until release artifacts are verified.
- **Before Code:**
  ```yaml
  assets:
    - assets/wallpapers/
  ```
- **After Code:**
  ```yaml
  assets:
    - assets/wallpapers/w1.jpg
    - assets/wallpapers/w2.jpg
  ```
- **Validation Step:** Run `flutter build apk --analyze-size` before and after; confirm `w1_1.jpg` and `w2_1.jpg` disappear from asset analysis.
- **Rollback Plan:** Restore `- assets/wallpapers/`.
- **Dependencies:** None.

### Finding PERF-006: Home Screen Uses an Over-Broad Provider Subscription
- **Category:** State
- **Severity:** Medium
- **File(s):** `lib/screens/home_screen.dart`
- **Line(s):** `HomeScreen.build`
- **Evidence:** The complete home screen watches `GameProvider`, although command handlers elsewhere correctly use `context.read`.
- **Root Cause:** Connection/loading/error fields are consumed through the full notifier rather than individually selected.
- **Impact:** Background connection and room changes rebuild wallpaper, app bar, navigation, and static home content.
- **Fix - Exact Steps:**
  1. Replace the root watch with selectors for every field actually rendered.
  2. Pass those primitive values to leaf builders.
  3. Continue using `read` for create/join/reset actions.
- **Before Code:**
  ```dart
  final provider = context.watch<GameProvider>();
  ```
- **After Code:**
  ```dart
  final status = context.select<GameProvider, ConnectionStatus>(
    (value) => value.status,
  );
  final errorMessage = context.select<GameProvider, String?>(
    (value) => value.errorMessage,
  );
  final availableThemes = context.select<GameProvider, List<String>>(
    (value) => value.availableThemes,
  );
  final provider = context.read<GameProvider>();
  ```
- **Validation Step:** Track widget builds while room discovery updates; confirm static home header and wallpaper no longer rebuild.
- **Rollback Plan:** Restore `context.watch<GameProvider>()`.
- **Dependencies:** None.

## Full Findings List (Design)

### Finding DESIGN-001: Design Tokens Are Incomplete and Mixed With Component Styling
- **Category:** Design-Visual
- **Severity:** Medium
- **File(s):** `lib/theme/app_theme.dart`
- **Line(s):** `AppTheme`
- **Evidence:** Colors and component themes exist, but there is no semantic spacing scale, radius scale, motion scale, elevation scale, or separate dark/light token model. Screens repeatedly hardcode radii from 4 through 28.
- **Root Cause:** Theme configuration doubles as both tokens and component implementation.
- **Impact:** Visual decisions drift across large screens and cannot be changed systematically.
- **Fix - Exact Steps:**
  1. Create `lib/core/design_system/tokens.dart`.
  2. Move semantic constants there without changing rendered values.
  3. Make `AppTheme` consume the tokens.
- **Before Code:**
  ```dart
  borderRadius: BorderRadius.circular(14)
  ```
- **After Code:**
  ```dart
  abstract final class AppSpacing {
    static const double xxs = 4;
    static const double xs = 8;
    static const double sm = 12;
    static const double md = 16;
    static const double lg = 24;
    static const double xl = 32;
    static const double xxl = 48;
  }

  abstract final class AppRadii {
    static const BorderRadius control =
        BorderRadius.all(Radius.circular(10));
    static const BorderRadius panel =
        BorderRadius.all(Radius.circular(16));
    static const BorderRadius feature =
        BorderRadius.all(Radius.circular(22));
  }

  abstract final class AppMotion {
    static const Duration fast = Duration(milliseconds: 120);
    static const Duration standard = Duration(milliseconds: 220);
    static const Duration emphasized = Duration(milliseconds: 420);
    static const Curve standardCurve = Curves.easeOutCubic;
  }
  ```
- **Validation Step:** Run `rg "BorderRadius.circular|Duration\\(milliseconds" lib/screens`; migrated screens must use tokens except documented one-off geometry.
- **Rollback Plan:** Restore literal values and remove `tokens.dart`.
- **Dependencies:** None.

### Finding DESIGN-002: Home Information Architecture Is a Long Uniform Card Feed
- **Category:** Design-Layout
- **Severity:** Medium
- **File(s):** `lib/screens/home_screen.dart`
- **Line(s):** `HomeScreen.build`, `_build*Card` methods
- **Evidence:** The screen is a nested scroll layout containing many similarly rounded containers and repeated card treatments. Primary play actions compete with secondary profile, online, and informational content.
- **Root Cause:** Features are presented as sequential independent panels instead of an importance-led dashboard.
- **Impact:** The first action is harder to scan and the screen reads as component-generated rather than product-directed.
- **Fix - Exact Steps:**
  1. Keep "create game" as the dominant 2x2 feature.
  2. Place "join by code" and "local rooms" as 1x1 actions.
  3. Place profile/progression as a 2x1 strip.
  4. Move update/settings/help into the app bar or bottom sheet.
- **Before Code:**
  ```text
  [Header]
  [Create Card]
  [Join Card]
  [Local Card]
  [Profile Card]
  [Additional Cards]
  ```
- **After Code:**
  ```text
  +----------------------+----------+
  |                      | Join code|
  |     Create game      +----------+
  |        2 x 2         | Local LAN|
  +----------------------+----------+
  | Profile, rank and weekly progress|
  +----------------------------------+
  ```
  Use `LayoutBuilder`, `Row`, and `Column` to implement this geometry without adding a package.
- **Validation Step:** Capture 360x800 and 1440x900 screenshots; the primary play action must appear above the fold and no tile may overflow.
- **Rollback Plan:** Restore the current sequential screen body.
- **Dependencies:** DESIGN-001.

### Finding DESIGN-003: Loading and Error Treatments Lack a Unified Product Language
- **Category:** Design-Motion
- **Severity:** Medium
- **File(s):** `lib/screens/game_screen.dart`, `lib/screens/puzzles/puzzles_home_screen.dart`, `lib/screens/academy/academy_home_screen.dart`
- **Line(s):** Initial/loading/error branches
- **Evidence:** The game uses a centered `CircularProgressIndicator`; other screens define independent image/error containers. No shared skeleton, empty-state, or retry component exists.
- **Root Cause:** Async states are implemented screen by screen.
- **Impact:** Transitions feel inconsistent and content-heavy screens shift abruptly when data appears.
- **Fix - Exact Steps:**
  1. Create shared `AppSkeleton`, `AppEmptyState`, and `AppErrorState` widgets.
  2. Match skeleton geometry to final screen content.
  3. Provide a retry callback and contextual Arabic copy.
- **Before Code:**
  ```dart
  return const Scaffold(
    body: Center(
      child: CircularProgressIndicator(color: AppTheme.gold),
    ),
  );
  ```
- **After Code:**
  ```dart
  return const Scaffold(
    body: SafeArea(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSkeleton(height: 72, radius: AppRadii.panel),
            SizedBox(height: AppSpacing.md),
            Expanded(
              child: AppSkeleton(radius: AppRadii.feature),
            ),
            SizedBox(height: AppSpacing.md),
            AppSkeleton(height: 96, radius: AppRadii.panel),
          ],
        ),
      ),
    ),
  );
  ```
- **Validation Step:** Throttle initialization and network access; confirm stable geometry, accessible labels, retry behavior, and no spinner-only content state.
- **Rollback Plan:** Restore each screen's original loading/error branch.
- **Dependencies:** DESIGN-001.

## Prioritization Matrix

| Finding ID | Severity | Effort | User Impact | Priority |
|---|---|---:|---|---:|
| PERF-001 | High | M | Faster first visible frame | 1 |
| PERF-003 | High | M | Deterministic game transitions | 2 |
| PERF-002 | High | M | Lower game-frame rebuild cost | 3 |
| PERF-004 | High | S | Prevent retained hand state | 4 |
| PERF-005 | Medium | S | Smaller installation/download | 5 |
| PERF-006 | Medium | M | Smoother home updates | 6 |
| DESIGN-001 | Medium | M | Consistent redesign foundation | 7 |
| DESIGN-002 | Medium | L | Clearer primary workflow | 8 |
| DESIGN-003 | Medium | M | Stable, coherent async states | 9 |

## Phased Execution Plan

### Phase 0 - Safety Net

Findings: none.

Order: repair the Flutter toolchain hang; run `flutter analyze`, `dart fix --dry-run`, `flutter test`; capture profile-mode frame, startup, memory, and APK-size baselines.

Definition of Done: all command outputs are archived; device and refresh rate are recorded; Home and Game flows have rebuild/frame traces.

Do not touch: production Dart behavior or visual styling.

### Phase 1 - Critical Performance Fixes

Order: PERF-004, PERF-003.

Definition of Done: lifecycle tests pass; repeated `GameScreen.build` calls produce no new timer or overlay transition; DevTools shows no retained `PlayerHand`.

Do not touch: game rules, scoring, networking protocol, provider public APIs.

### Phase 2 - Rendering and Rebuild Optimization

Order: PERF-002, PERF-006.

Definition of Done: Track Widget Builds confirms only selected subtrees rebuild; gameplay behavior remains identical.

Do not touch: visual styling or widget geometry.

### Phase 3 - List, Network, and Async Optimization

No evidence-backed defect was confirmed in this category. Profile room discovery and profile history before creating additional findings.

Do not touch: pagination or serialization without measured evidence.

### Phase 4 - Startup and Size Optimization

Order: PERF-005, then PERF-001.

Definition of Done: unused originals are absent from bundle analysis; first-frame time improves; offline startup still reaches a usable screen.

Do not touch: authentication semantics, Supabase RLS, signing configuration.

### Phase 5 - Design System Foundation

Order: DESIGN-001.

Definition of Done: semantic tokens compile; existing screens render unchanged; dark palette contrast passes WCAG AA for body text.

Do not touch: screen layouts.

### Phase 6 - Screen-by-Screen Redesign

Order: DESIGN-002, followed by the same token-led review of mode selection, Academy, Puzzles, Profile, Lobby, and Match End.

Definition of Done: each screen has phone/tablet screenshots, overflow tests, RTL validation, and unchanged navigation behavior.

Do not touch: domain models, providers, game engines, networking.

### Phase 7 - Motion and Polish

Order: DESIGN-003, then shared-element transitions and press feedback.

Definition of Done: animations respect reduced-motion settings; no profile frame exceeds budget due to decorative motion.

Do not touch: scoring timing or network-event timing.

### Phase 8 - Final Regression Pass

Run the full tests and repeat every Phase 0 measurement on the same device and flow. Produce the comparison table below.

## Agent Execution Rules

```text
RULES FOR THE EXECUTING AGENT:
1. Execute findings strictly in the phase and order given. Do not skip ahead.
2. Never modify a file beyond what the specific Finding's "Fix - Exact Steps" describes.
3. After each finding is applied, run its Validation Step before moving to the next.
4. If a Validation Step fails, execute the Rollback Plan immediately and flag the finding as BLOCKED - do not attempt improvisation.
5. Do not introduce new packages/dependencies unless explicitly listed in the fix.
6. Preserve all existing public APIs/widget constructors unless the finding explicitly instructs a signature change - if it does, update every call site (list them).
7. Commit after each completed finding with message format: `fix(FindingID): short description`.
8. Do not reformat/refactor code outside the scope of the current finding, even if it "looks messy."
9. If any instruction is ambiguous, STOP and request clarification rather than guessing.
```

## Final Metrics Report Template

| Metric | Before | After | Target |
|---|---:|---:|---:|
| Avg frame build time (ms) | | | <8 ms |
| Avg frame raster time (ms) | | | <8 ms |
| Janky frames per session | | | <2% |
| Cold start time (ms) | | | Baseline -20% |
| APK/IPA size (MB) | | | Remove unused 5.78 MB source assets |
| Memory footprint, idle (MB) | | | No regression |
| Memory footprint, peak (MB) | | | Baseline -10% |
| Widget rebuild count, Home | | | Static shell unchanged during room updates |
| Widget rebuild count, Game | | | Only state-dependent leaves rebuild |

Open measurements: real-device frame data, cold-start timing, release artifact size, memory snapshots, and analyzer/test results must be collected after resolving the local Flutter command hang.
