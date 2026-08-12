# Night Arena Visual System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` or `executing-plans` to implement this plan task-by-task with review checkpoints.

**Goal:** Migrate the existing Flutter app to the approved Night Arena visual system while preserving the four-user competition, health-data boundaries, offline states, and existing feature repositories.

**Architecture:** Extend the existing `AppTheme` instead of introducing a second theme. Add small, feature-agnostic presentation primitives under `lib/shared/ui`, map feature data into immutable view models at each feature boundary, and migrate one product tab at a time. Data loading and domain behavior remain in the current feature modules.

**Tech Stack:** Flutter/Dart SDK `^3.12.2`, Material 3, Supabase Flutter `^2.17.1`, `flutter_test`, physical iOS and Android devices, Figma for foundations/prototyping, optional Rive only for a justified non-routine celebration.

## Global Constraints

- Exactly four allowlisted users; no public registration, discovery, followers, or payments.
- No manual step-entry UI anywhere.
- Detectable manual health records remain excluded from rankings, streaks, achievements, missions, and points.
- The database remains authoritative; realtime only delivers invalidation/refetch signals.
- Private media remains private and explicit location remains post-scoped.
- Product-facing labels remain Spanish at the UI boundary; Dart types, tests, logs, and domain identifiers remain English.
- Use the existing 4/8/16/24/32 spacing scale and existing `DESIGN.md` neutral/lime/orange contract.
- Use 48 logical pixels as the minimum new interactive target and pair color with text, number, or icon.
- Reserve glass for navigation, compact filter rails, and transient overlays; never use glass-on-glass.
- Respect reduced motion, reduced transparency, increased contrast, text scaling, VoiceOver, TalkBack, grayscale, and color-vision needs.
- Target smooth profile-mode rendering at 60 fps and verify on physical devices, not only Windows, emulators, or debug mode.
- Do not add a dependency for ordinary Flutter transitions or progress effects.
- Do not commit changes unless the product owner explicitly requests a commit.

## Source Contract

The implementation must follow these approved references:

- Design decision: `docs/superpowers/specs/2026-08-11-night-arena-visual-design-roadmap.md`
- Existing token source: `DESIGN.md`
- Product constraints: `PRODUCT.md`
- Project rules: `CODESTYLE.md`
- Apple material guidance: https://developer.apple.com/videos/play/wwdc2025/219/
- Material 3 Expressive: https://m3.material.io/blog/building-with-m3-expressive
- Material motion: https://m3.material.io/styles/motion/overview
- Flutter animation guidance: https://docs.flutter.dev/ui/animations
- Flutter accessibility guidance: https://docs.flutter.dev/ui/accessibility
- Flutter performance guidance: https://docs.flutter.dev/perf/ui-performance
- Figma prototyping guidance: https://help.figma.com/hc/en-us/articles/360040314193-Create-prototypes-with-interactions-and-animations

## File Map

Create these focused presentation files:

- `lib/shared/ui/arena_tokens.dart`: spacing, radii, motion durations, player identity colors, and feature-agnostic view models.
- `lib/shared/ui/arena_app_header.dart`: semantically standard app header styled for Night Arena.
- `lib/shared/ui/arena_navigation_bar.dart`: five-destination navigation wrapper that keeps Material `NavigationBar` semantics.
- `lib/shared/ui/arena_status_pill.dart`: icon plus label treatment for freshness, offline, permission, and error states.
- `lib/shared/ui/arena_progress_track.dart`: goal/mission progress with reduced-motion behavior.
- `lib/shared/ui/arena_score_hero.dart`: one dominant score and supporting state.
- `lib/shared/ui/player_ranking_lane.dart`: four-player lane with stable row identity and rank movement.
- `lib/shared/ui/arena_result_stamp.dart`: deterministic round, achievement, trophy, or season result treatment.
- `lib/features/activity/presentation/home_dashboard_view.dart`: render-only `HOY` composition.
- `lib/features/ranking/presentation/ranking_dashboard_view.dart`: render-only ranking composition.
- `lib/features/profiles/presentation/club_roster_view.dart`: render-only `NOSOTROS` composition.
- `lib/features/nutrition/presentation/register_action_launcher.dart`: render-only `REGISTRAR` action surface.


- `DESIGN.md`: reconcile the source token contract with Night Arena.
- `lib/shared/ui/app_theme.dart`: extend the current theme with the approved tokens.
- `lib/shared/ui/async_view_status.dart`: add the explicit source-unavailable state.
- `lib/shared/ui/async_state_view.dart`: render the expanded state taxonomy consistently.
- `lib/features/app/presentation/app_shell.dart`: use `ArenaNavigationBar`.
- `lib/features/activity/presentation/home_tab.dart`: retain loading/repository/realtime behavior and delegate rendering.
- `lib/features/app/data/dashboard_repository.dart`: expose the existing current-user daily step target needed by the score hero.
- `lib/features/ranking/presentation/ranking_tab.dart`: retain loading behavior and delegate rendering.
- `lib/features/game/presentation/game_tab.dart`: retain repository behavior and use the shared arena primitives.
- `lib/features/nutrition/presentation/register_tab.dart`: retain action callbacks and use `RegisterActionLauncher`.
- `lib/features/profiles/presentation/about_tab.dart`: retain repository behavior and use `ClubRosterView`.

Create or extend these tests:

- `test/arena_tokens_test.dart`
- `test/arena_navigation_bar_test.dart`
- `test/arena_components_test.dart`
- `test/async_state_view_test.dart`
- `test/home_dashboard_view_test.dart`
- `test/ranking_tab_test.dart`
- `test/game_arena_view_test.dart`
- `test/register_action_launcher_test.dart`
- `test/club_roster_view_test.dart`
- `test/app_shell_test.dart`

Create the device review evidence template:

- `docs/design/night-arena-device-qa.md`

The Figma file is an external design artifact and must contain the pages
`00 Research`, `01 Foundations`, `02 Components`, `03 Golden Flows`,
`04 Motion`, and `05 Device Review`. Its final URL is recorded in
`docs/design/night-arena-device-qa.md` after the file exists.

---

### Task 1: Establish The Baseline And Reconcile Documentation

**Files:**

- Modify: `DESIGN.md`
- Read: `docs/superpowers/specs/2026-08-11-night-arena-visual-design-roadmap.md`
- Read: `PRODUCT.md`
- Read: `CODESTYLE.md`
- Test: no code test; run the repository baseline commands

**Interfaces:**

- Consumes: the approved Night Arena specification and existing design tokens.
- Produces: one consistent documentation contract for later implementation tasks.

- [ ] **Step 1: Capture the dirty-worktree baseline without reverting anything**

Run:

```powershell
git status --short
& "C:\src\flutter\bin\flutter.bat" analyze
& "C:\src\flutter\bin\flutter.bat" test
```

Expected: record whether `analyze` and `test` pass. If an existing failure is
present, copy its file and error into the implementation notes and do not fix
it in this documentation task.

- [ ] **Step 2: Reconcile `DESIGN.md` with the approved system**

Keep the existing `scoreboard-lime`, `heat-orange`, `night-canvas`,
`training-surface`, `raised-surface`, and `graphite-border` values. Add the
four player identity marker values from the spec, the rule that identity color
does not communicate rank, the glass-only-on-navigation rule, the five motion
families, and the five-tab composition order.

Remove wording that says the design has only one color in a way that would
contradict the four identity markers. Preserve the rule that lime and orange
have semantic jobs and are not decorative gradients.

- [ ] **Step 3: Verify documentation consistency**

Run:

```powershell
rg -n "C7FF00|FF5A26|player-cyan|player-amber|player-coral|player-violet|glass|Pulse|Charge|Slide|Stamp|Burst" DESIGN.md docs/superpowers/specs/2026-08-11-night-arena-visual-design-roadmap.md
```

Expected: both documents describe the same palette, glass boundary, and motion
families. Leave the worktree uncommitted.

### Task 2: Add Night Arena Tokens And Theme Roles

**Files:**

- Create: `lib/shared/ui/arena_tokens.dart`
- Modify: `lib/shared/ui/app_theme.dart`
- Test: `test/arena_tokens_test.dart`

**Interfaces:**

- Consumes: existing `AppColors` and `ThemeData` usage throughout the app.
- Produces: `PlayerAccent`, `PlayerLaneEntry`, `ArenaSpacing`, `ArenaRadii`, and `ArenaMotion` for shared presentation components.

- [ ] **Step 1: Write token tests first**

Create `test/arena_tokens_test.dart` with these behavior checks:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enfermicambio/shared/ui/arena_tokens.dart';
import 'package:enfermicambio/shared/ui/app_theme.dart';

void main() {
  test('player accents are stable and distinct', () {
    final colors = PlayerAccent.values.map((accent) => accent.color).toSet();

    expect(colors, hasLength(4));
    expect(PlayerAccent.cyan.color, const Color(0xFF56D9FF));
    expect(PlayerAccent.amber.color, const Color(0xFFFFC857));
    expect(PlayerAccent.coral.color, const Color(0xFFFF766E));
    expect(PlayerAccent.violet.color, const Color(0xFFB88CFF));
  });

  test('motion durations match the approved budget', () {
    expect(ArenaMotion.micro, const Duration(milliseconds: 160));
    expect(ArenaMotion.navigation, const Duration(milliseconds: 300));
    expect(ArenaMotion.competition, const Duration(milliseconds: 550));
  });

  testWidgets('dark theme exposes Night Arena surfaces', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) => ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const SizedBox(width: 1, height: 1),
          ),
        ),
      ),
    );

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.scaffoldBackgroundColor, const Color(0xFF111211));
  });
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```powershell
& "C:\src\flutter\bin\flutter.bat" test test/arena_tokens_test.dart
```

Expected: FAIL because `arena_tokens.dart` and the Night Arena theme values do
not exist yet.

- [ ] **Step 3: Implement the token file**

Create the following public API in `lib/shared/ui/arena_tokens.dart`:

```dart
import 'package:flutter/material.dart';

enum PlayerAccent { cyan, amber, coral, violet }

extension PlayerAccentColor on PlayerAccent {
  Color get color => switch (this) {
        PlayerAccent.cyan => const Color(0xFF56D9FF),
        PlayerAccent.amber => const Color(0xFFFFC857),
        PlayerAccent.coral => const Color(0xFFFF766E),
        PlayerAccent.violet => const Color(0xFFB88CFF),
      };
}

class ArenaSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  const ArenaSpacing._();
}

class ArenaRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;

  const ArenaRadii._();
}

class ArenaMotion {
  static const micro = Duration(milliseconds: 160);
  static const navigation = Duration(milliseconds: 300);
  static const competition = Duration(milliseconds: 550);

  const ArenaMotion._();
}

class PlayerLaneEntry {
  const PlayerLaneEntry({
    required this.userId,
    required this.displayName,
    required this.rank,
    required this.valueLabel,
    required this.statusLabel,
    required this.statusIcon,
    required this.accent,
    this.isCurrent = false,
    this.deltaLabel,
  });

  final String userId;
  final String displayName;
  final int rank;
  final String valueLabel;
  final String statusLabel;
  final IconData statusIcon;
  final PlayerAccent accent;
  final bool isCurrent;
  final String? deltaLabel;
}
```

- [ ] **Step 4: Extend the existing theme without changing feature imports**

In `app_theme.dart`:

- Add named Night Arena colors while retaining current names until all feature
  consumers migrate.
- Set dark scaffold/background to `#111211`, content surface to `#1C1D1C`,
  raised controls to `#292A28`, border to `#343632`, primary to `#C7FF00`,
  secondary to `#FF5A26`, primary text to `#F4F5EE`, and muted text to
  `#A9ABA3`.
- Set `CardThemeData.elevation` to zero and use a one-pixel graphite border.
- Configure `NavigationBarThemeData`, not only
  `BottomNavigationBarThemeData`, because `AppShell` uses `NavigationBar`.
- Keep the light theme readable and semantically equivalent; do not create a
  second light-only brand palette.

- [ ] **Step 5: Run focused tests and analyzer**

Run:

```powershell
& "C:\src\flutter\bin\flutter.bat" test test/arena_tokens_test.dart
& "C:\src\flutter\bin\flutter.bat" analyze
```

Expected: focused tests pass and analyzer reports zero warnings introduced by
the token/theme task.

### Task 3: Build Shared Header, Navigation, And Status Primitives

**Files:**

- Create: `lib/shared/ui/arena_app_header.dart`
- Create: `lib/shared/ui/arena_navigation_bar.dart`
- Create: `lib/shared/ui/arena_status_pill.dart`
- Modify: `lib/features/app/presentation/app_shell.dart`
- Test: `test/arena_navigation_bar_test.dart`
- Test: `test/app_shell_test.dart`

**Interfaces:**

- Consumes: `AppTheme`, the existing five tab labels, and `ArenaMotion`.
- Produces: `ArenaAppHeader`, `ArenaNavigationBar`, and `ArenaStatusPill` with Material semantics and stable widget keys.

- [ ] **Step 1: Add the shared widget APIs**

Use these signatures:

```dart
class ArenaAppHeader extends StatelessWidget implements PreferredSizeWidget {
  const ArenaAppHeader({
    super.key,
    required this.title,
    this.actions = const [],
  });

  final String title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);
}

class ArenaNavigationBar extends StatelessWidget {
  const ArenaNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
}

enum ArenaStatusTone { neutral, positive, warning, danger }

class ArenaStatusPill extends StatelessWidget {
  const ArenaStatusPill({
    super.key,
    required this.label,
    required this.icon,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final ArenaStatusTone tone;
}
```

`ArenaNavigationBar` must return a Material `NavigationBar` with the existing
five destinations and labels `HOY`, `RANKING`, `REGISTRAR`, `JUEGO`, and
`NOSOTROS`. Give each destination a `ValueKey` based on its label so tests and
automation can target it. `ArenaAppHeader` must delegate to `AppBar` so native
back behavior, accessibility semantics, and platform system-bar behavior stay
intact.

- [ ] **Step 2: Update `AppShell` to use the wrapper**

Replace only the `bottomNavigationBar: NavigationBar(...)` construction with:

```dart
bottomNavigationBar: ArenaNavigationBar(
  selectedIndex: _selectedIndex,
  onDestinationSelected: (index) {
    setState(() => _selectedIndex = index);
  },
),
```

Keep `IndexedStack`, lifecycle resume, tab order, and test injection unchanged.

- [ ] **Step 3: Add navigation and status tests**

Extend `test/app_shell_test.dart` to verify that the wrapper still exposes a
Material `NavigationBar`, all five Spanish labels, and tab switching. Add
`test/arena_navigation_bar_test.dart` to verify that tapping the destination
with key `navigation-RANKING` calls `onDestinationSelected(1)`.

Add status-pill assertions in `test/arena_components_test.dart` later; do not
duplicate visual color assertions in feature tests.

- [ ] **Step 4: Run the focused tests**

Run:

```powershell
& "C:\src\flutter\bin\flutter.bat" test test/app_shell_test.dart test/arena_navigation_bar_test.dart
```

Expected: all navigation tests pass and the existing five-tab behavior remains
unchanged.

### Task 4: Build Score, Progress, Ranking, And Result Primitives

**Files:**

- Create: `lib/shared/ui/arena_progress_track.dart`
- Create: `lib/shared/ui/arena_score_hero.dart`
- Create: `lib/shared/ui/player_ranking_lane.dart`
- Create: `lib/shared/ui/arena_result_stamp.dart`
- Test: `test/arena_components_test.dart`

**Interfaces:**

- Consumes: `PlayerLaneEntry`, `PlayerAccent`, `ArenaMotion`, and a `BuildContext`.
- Produces: reusable render-only widgets with no Supabase, health, or feature-domain imports.

- [ ] **Step 1: Write component behavior tests**

The test fixture must contain exactly four entries:

```dart
const entries = [
  PlayerLaneEntry(
    userId: 'a',
    displayName: 'Freddy',
    rank: 1,
    valueLabel: '11.4k pasos',
    statusLabel: 'Sincronizado',
    statusIcon: Icons.check_circle_outline,
    accent: PlayerAccent.cyan,
    isCurrent: true,
  ),
  PlayerLaneEntry(
    userId: 'b',
    displayName: 'Cristian',
    rank: 2,
    valueLabel: '10.2k pasos',
    statusLabel: 'Sincronizado',
    statusIcon: Icons.check_circle_outline,
    accent: PlayerAccent.amber,
  ),
  PlayerLaneEntry(
    userId: 'c',
    displayName: 'Felipe',
    rank: 3,
    valueLabel: '8.9k pasos',
    statusLabel: 'Desactualizado',
    statusIcon: Icons.schedule,
    accent: PlayerAccent.coral,
  ),
  PlayerLaneEntry(
    userId: 'd',
    displayName: 'Samir',
    rank: 4,
    valueLabel: 'Sin datos',
    statusLabel: 'Sin datos',
    statusIcon: Icons.hourglass_empty,
    accent: PlayerAccent.violet,
  ),
];
```

Assert that all four names, rank numbers, values, status labels, and the current
player label are rendered. Assert that `ScoreHero` exposes a semantic label
containing its value and that `ArenaProgressTrack` renders a non-color text
label for its percentage.

- [ ] **Step 2: Implement the shared APIs**

Use these public signatures:

```dart
class ArenaProgressTrack extends StatelessWidget {
  const ArenaProgressTrack({
    super.key,
    required this.value,
    required this.label,
    this.accent = AppColors.primary,
  });

  final double value;
  final String label;
  final Color accent;
}

class ScoreHero extends StatelessWidget {
  const ScoreHero({
    super.key,
    required this.label,
    required this.value,
    this.supportingText,
    this.progress,
    this.accent = AppColors.primary,
  });

  final String label;
  final String value;
  final String? supportingText;
  final double? progress;
  final Color accent;
}

class PlayerRankingLane extends StatelessWidget {
  const PlayerRankingLane({
    super.key,
    required this.entries,
  });

  final List<PlayerLaneEntry> entries;
}

class ArenaResultStamp extends StatelessWidget {
  const ArenaResultStamp({
    super.key,
    required this.title,
    required this.detail,
    required this.icon,
  });

  final String title;
  final String detail;
  final IconData icon;
}
```

`PlayerRankingLane` must reject or visibly handle lists that are not exactly
four entries. Use a calm empty state for zero entries and render an explicit
status for an unexpected count; never silently hide a player. Each row must
have a stable key `player-lane-<userId>`.

For rank movement, render the four rows inside a fixed-height `Stack` and use
`AnimatedPositioned` with `ArenaMotion.competition` to calculate the vertical
position from `(rank - 1) * rowHeight`. Keep the row's key tied to `userId`, not
to its rank, so an overtake moves the same visual identity.

- [ ] **Step 3: Add reduced-motion behavior**

Use the platform accessibility setting at the point where a duration is chosen:

```dart
final duration = MediaQuery.of(context).disableAnimations
    ? Duration.zero
    : ArenaMotion.competition;
```

When animations are disabled, keep the final rank/value state and remove
elastic movement, particles, and count-up effects. Do not remove status labels
or semantic announcements.

- [ ] **Step 4: Run the focused component tests**

Run:

```powershell
& "C:\src\flutter\bin\flutter.bat" test test/arena_components_test.dart
```

Expected: four-player rendering, semantic labels, progress labels, and
reduced-motion assertions pass.

### Task 5: Expand Shared Async State Recovery

**Files:**

- Modify: `lib/shared/ui/async_view_status.dart`
- Modify: `lib/shared/ui/async_state_view.dart`
- Create: `test/async_state_view_test.dart`
- Modify: `test/app_shell_test.dart`

**Interfaces:**

- Consumes: existing `AsyncStateView` callers and `HealthReadStatus` vocabulary.
- Produces: explicit `sourceUnavailable` support without breaking existing constructors or states.

- [ ] **Step 1: Add the failing state test**

Add a widget test that pumps:

```dart
AsyncStateView(
  status: const AsyncViewStatus.sourceUnavailable(
    'Health Connect no está disponible en este dispositivo.',
  ),
  onRetry: () {},
)
```

Assert `Fuente no disponible`, the supplied message, and a `Reintentar` action.
Also test `offline`, `permissionDenied`, `stale`, and `retryableFailure` with
their icon and text, not only their color.

- [ ] **Step 2: Add the enum value and constructor**

In `async_view_status.dart`, add `sourceUnavailable` to `AsyncState` and:

```dart
const AsyncViewStatus.sourceUnavailable([String? message])
    : this._(AsyncState.sourceUnavailable, message: message);
```

Keep `hasError` limited to states that represent an error requiring recovery;
`sourceUnavailable` is included because it must expose a recovery action.

- [ ] **Step 3: Render the state through the shared visual language**

In `async_state_view.dart`, map `sourceUnavailable` to
`Icons.health_and_safety_outlined`, title `Fuente no disponible`, the supplied
Spanish message, and the existing retry button. Replace the current generic
message styling with `ArenaStatusPill` or its same icon/text contract without
introducing a feature import.

- [ ] **Step 4: Run state tests and analyzer**

Run:

```powershell
& "C:\src\flutter\bin\flutter.bat" test test/async_state_view_test.dart test/app_shell_test.dart
& "C:\src\flutter\bin\flutter.bat" analyze
```

Expected: all existing async-state expectations remain valid and the new
source-unavailable state is covered.

### Task 6: Migrate `HOY` To The Scoreboard Composition

**Files:**

- Create: `lib/features/activity/presentation/home_dashboard_view.dart`
- Modify: `lib/features/activity/presentation/home_tab.dart`
- Test: `test/home_dashboard_view_test.dart`

**Interfaces:**

- Consumes: `AppDashboardData`, `AsyncViewStatus`, `FeedPost` callbacks, current user ID, cache state, and health setup callback.
- Produces: a render-only `HomeDashboardView` with hero score, four-player lane, health recovery, and feed composition.

- [ ] **Step 1: Extract a testable render-only view**

Create:

```dart
class HomeDashboardView extends StatelessWidget {
  const HomeDashboardView({
    super.key,
    required this.data,
    required this.currentUserId,
    required this.onRefresh,
    required this.onConnectHealth,
    required this.onReact,
    required this.onComment,
    this.status,
    this.showingCache = false,
  });

  final AppDashboardData data;
  final String? currentUserId;
  final Future<void> Function() onRefresh;
  final VoidCallback onConnectHealth;
  final Future<void> Function(FeedPost post) onReact;
  final Future<void> Function(FeedPost post) onComment;
  final AsyncViewStatus? status;
  final bool showingCache;
}
```

Move only presentation code from `_HomeTabState` into this view. Keep
repository construction, cache reads, realtime subscription, `_load`,
`_react`, and `_comment` in `home_tab.dart`.

- [ ] **Step 2: Expose the existing daily target without adding a new data source**

The current `DashboardRepository` does not select the already-persisted
`daily_step_target`, so the score hero cannot calculate honest progress. Extend
`AppDashboardData` with:

```dart
final int? dailyStepTarget;
```

Add `daily_step_target` to the existing `profiles` select and populate the
field only for the authenticated current user. Keep it nullable when the
profile row does not provide a target. Do not substitute a hard-coded target or
derive progress from a guessed calorie value. Update the cached constructor in
`home_tab.dart` with `dailyStepTarget: null`.

- [ ] **Step 3: Compose the screen in the required order**

Render in this order:

1. Cache/offline status using `ArenaStatusPill` and a `Reintentar` action.
2. `ScoreHero` for the current user's steps and goal progress.
3. `MetricRail`-style rows for active calories, distance, and exercise minutes.
4. `PlayerRankingLane` with all `data.ranking` rows and deterministic player
   accents based on list position.
5. `FeedList` with the existing reaction and comment callbacks.

When `data.me` is null, replace the score hero with a health connection card
that says why automatic health data is needed and calls `onConnectHealth`. Do
not offer a numeric step input.

- [ ] **Step 4: Wire health recovery without duplicating sync logic**

In `home_tab.dart`, implement `onConnectHealth` by navigating to the existing
`HealthSetupScreen(repository: HealthPluginRepository())`. Do not call the
health repository directly from `HomeDashboardView`.

- [ ] **Step 5: Add deterministic widget coverage**

Build an `AppDashboardData` fixture with `UserMocks.mockStepRankings`, a
`DailyActivityAggregate` with `dailySteps: 8420`, `dailyStepTarget: 10000`, and
an empty `FeedPage`. Pump
`HomeDashboardView` with `currentUserId: UserMocks.idFreddy` and assert:

- `8,420` or the configured formatted value is the dominant score.
- All four user names render.
- A cache status renders with `Mostrando datos en caché` when enabled.
- Null `data.me` renders `Conectar salud` and no numeric step field.
- The feed remains below the ranking.

- [ ] **Step 6: Run focused tests**

Run:

```powershell
& "C:\src\flutter\bin\flutter.bat" test test/home_dashboard_view_test.dart test/ranking_tab_test.dart
```

Expected: `HOY` render tests pass without creating a Supabase client.

### Task 7: Migrate `RANKING` To The Four-Player Lane

**Files:**

- Create: `lib/features/ranking/presentation/ranking_dashboard_view.dart`
- Modify: `lib/features/ranking/presentation/ranking_tab.dart`
- Modify: `test/ranking_tab_test.dart`

**Interfaces:**

- Consumes: `List<RankingRow>`, selected period/category state, and refresh callback.
- Produces: styled period/category controls, four-player ranking lane, status labels, and stable animation keys.

- [ ] **Step 1: Preserve the existing data boundary**

Keep `DashboardRepository.load` and the current `RankingTab` constructor
(`rows`, `loadFromBackend`) unchanged. Extract only the `Scaffold` body into a
render-only `RankingDashboardView` so existing tests can still inject rows
without a backend.

- [ ] **Step 2: Map feature rows to shared entries**

Map each `RankingRow` as follows:

```dart
PlayerLaneEntry(
  userId: row.userId,
  displayName: row.displayName,
  rank: row.rank,
  valueLabel: _formatValue(row.value),
  statusLabel: freshnessText,
  statusIcon: freshnessIcon,
  accent: PlayerAccent.values[index % PlayerAccent.values.length],
  deltaLabel: null,
)
```

Use rank number, status icon, and status text in addition to any color. Keep
`Sin datos aún`, `Desactualizado`, `Permiso denegado`, and `No disponible`
explicit.

- [ ] **Step 3: Style existing selectors without fabricating metrics**

Style the current `Hoy`, `Semana`, `Temporada`, and category controls using the
raised surface and lime selected state. Keep category selection local until the
backend query contract exists. If a selected category has no data, render the
shared empty state rather than reusing step values under another label.

- [ ] **Step 4: Add overtake and state tests**

Extend `test/ranking_tab_test.dart` to assert four player identities, current
freshness labels, and the selected control. Add a widget test that pumps the
lane with Freddy at rank 2, changes the list to Freddy at rank 1, calls
`pump(const Duration(milliseconds: 550))`, and asserts the same key
`player-lane-user-freddy-001` remains present.

- [ ] **Step 5: Run focused ranking tests**

Run:

```powershell
& "C:\src\flutter\bin\flutter.bat" test test/ranking_tab_test.dart test/arena_components_test.dart
```

Expected: all four rows, selected controls, freshness states, and stable rank
identity pass.

### Task 8: Migrate `JUEGO` To The Arena And Result Language

**Files:**

- Create: `lib/features/game/presentation/game_arena_view.dart`
- Modify: `lib/features/game/presentation/game_tab.dart`
- Create: `test/game_arena_view_test.dart`

**Interfaces:**

- Consumes: `Season?`, `List<SeasonStanding>`, `AsyncViewStatus?`, and refresh callback.
- Produces: season header, four-player standings lane, mission progress, and non-random trophy/achievement presentation.

- [ ] **Step 1: Extract the render-only game view**

Create:

```dart
class GameArenaView extends StatelessWidget {
  const GameArenaView({
    super.key,
    required this.season,
    required this.standings,
    required this.onRefresh,
    this.status,
  });

  final Season season;
  final List<SeasonStanding> standings;
  final Future<void> Function() onRefresh;
  final AsyncViewStatus? status;
}
```

Keep `SupabaseGameRepository`, `_load`, and offline behavior in `game_tab.dart`.

- [ ] **Step 2: Replace the repeated card grid**

Use `ArenaResultStamp` for the season header when a result is available, a
`PlayerRankingLane` for standings, `ArenaProgressTrack` inside mission rows,
and a horizontally scrollable trophy cabinet or compact list for achievements.
Do not use the current equal three-column badge grid as the primary visual
grammar. Keep secret/unlocked labels explicit and do not add random rewards.

- [ ] **Step 3: Add game view tests**

Use `UserMocks.mockSeasonStandings` and:

```dart
const season = Season(
  id: 'season-001',
  name: 'Agosto',
  startsAt: DateTime.utc(2026, 8, 1),
  endsAt: DateTime.utc(2026, 9, 1),
  status: 'active',
);
```

Assert season name, all four standings, mission labels, a progress label, and
the absence of `Ruleta`, `Monedas`, or random reward copy.

- [ ] **Step 4: Run focused game tests**

Run:

```powershell
& "C:\src\flutter\bin\flutter.bat" test test/game_arena_view_test.dart
```

Expected: season and standings content renders from injected data without a
Supabase connection.

### Task 9: Migrate `REGISTRAR` To A Fast Action Launcher

**Files:**

- Create: `lib/features/nutrition/presentation/register_action_launcher.dart`
- Modify: `lib/features/nutrition/presentation/register_tab.dart`
- Create: `test/register_action_launcher_test.dart`

**Interfaces:**

- Consumes: callbacks already owned by `_RegisterTabState`.
- Produces: one dominant primary action, compact secondary actions, and the no-manual-steps explanation.

- [ ] **Step 1: Add the render-only launcher API**

Use:

```dart
class RegisterActionLauncher extends StatelessWidget {
  const RegisterActionLauncher({
    super.key,
    required this.onScanBarcode,
    required this.onCreateFood,
    required this.onPhotoMeal,
    required this.onCreatePost,
  });

  final VoidCallback onScanBarcode;
  final VoidCallback onCreateFood;
  final VoidCallback onPhotoMeal;
  final VoidCallback onCreatePost;
}
```

- [ ] **Step 2: Compose actions by hierarchy**

Make `Escanear código de barras` the primary lime action. Render `Crear
alimento`, `Foto de comida`, and `Publicar` as secondary actions in a compact
arrangement. Keep the informational message that steps are automatic, but
render it as a calm explanatory banner, never as a game reward.

- [ ] **Step 3: Keep behavior in the existing state object**

Pass `_scanBarcode`, `_showCustomFoodModal`, the photo callback, and
`_createTextPost` into the launcher. Do not move barcode resolution, food
lookup, post creation, or Supabase calls into the new view.

- [ ] **Step 4: Test actions and forbidden behavior**

Pump `RegisterActionLauncher` with callbacks that increment counters. Tap each
label and assert its callback count is one. Assert `Escanear código de barras`
is present and no button has a label matching `Ingresar pasos`, `Añadir pasos`,
or `Pasos manuales`.

- [ ] **Step 5: Run focused tests**

Run:

```powershell
& "C:\src\flutter\bin\flutter.bat" test test/register_action_launcher_test.dart
```

Expected: all four actions and the no-manual-steps guard pass.

### Task 10: Migrate `NOSOTROS` To The Private Club Roster

**Files:**

- Create: `lib/features/profiles/presentation/club_roster_view.dart`
- Modify: `lib/features/profiles/presentation/about_tab.dart`
- Create: `test/club_roster_view_test.dart`

**Interfaces:**

- Consumes: profiles, profile history stats, recent workouts, health setup callback, and workout detail callback.
- Produces: four stable player identities, profile metrics, workout history, and health settings access.

- [ ] **Step 1: Add the render-only roster API**

Use:

```dart
class ClubRosterView extends StatelessWidget {
  const ClubRosterView({
    super.key,
    required this.profiles,
    required this.stats,
    required this.recentWorkouts,
    required this.onOpenHealth,
    required this.onOpenWorkout,
  });

  final List<UserProfile> profiles;
  final Map<String, ProfileHistoryStats> stats;
  final List<Workout> recentWorkouts;
  final VoidCallback onOpenHealth;
  final ValueChanged<Workout> onOpenWorkout;
}
```

- [ ] **Step 2: Render roster identity without rank-color ambiguity**

Assign identity accents by stable profile list order, display the first letter
and name, and show rank/metrics as text. Use `PlayerAccent` only for the stripe,
avatar ring, or small identity marker. Keep health settings as an icon plus
tooltip/label and preserve the existing route to `HealthSetupScreen`.

- [ ] **Step 3: Test exactly four profiles**

Pump `ClubRosterView` with `UserMocks.fourProfiles`, an empty stats map, and an
empty workout list. Assert all four names, the `Los 4 Amigos` heading, the health
settings action, and no public profile/follower labels. Add a second fixture with
one recent workout and assert the workout callback fires.

- [ ] **Step 4: Run focused tests**

Run:

```powershell
& "C:\src\flutter\bin\flutter.bat" test test/club_roster_view_test.dart
```

Expected: four profiles and workout navigation render without a Supabase client.

### Task 11: Add Motion, Semantics, And Accessibility Coverage

**Files:**

- Modify: `lib/shared/ui/arena_progress_track.dart`
- Modify: `lib/shared/ui/arena_score_hero.dart`
- Modify: `lib/shared/ui/player_ranking_lane.dart`
- Modify: `lib/shared/ui/arena_result_stamp.dart`
- Modify: `test/arena_components_test.dart`
- Modify: `test/app_shell_test.dart`

**Interfaces:**

- Consumes: `MediaQueryData.disableAnimations`, semantic labels, and the approved `ArenaMotion` durations.
- Produces: accessible motion that can be disabled without losing meaning.

- [ ] **Step 1: Add semantics before animation polish**

Every interactive or stateful shared component must expose:

- A label containing the metric or state.
- A value or status that does not depend on color.
- A tooltip for icon-only actions.
- A stable key for ranking rows and navigation destinations.

Use `Semantics(label: 'Freddy, posición 1, 11.4k pasos, sincronizado')` for a
ranking row and `Semantics(label: 'Progreso de pasos: 84 por ciento')` for a
progress track. Keep the visible Spanish copy consistent with the semantic
copy.

- [ ] **Step 2: Add reduced-motion tests**

Wrap `PlayerRankingLane` in:

```dart
MediaQuery(
  data: const MediaQueryData(disableAnimations: true),
  child: PlayerRankingLane(entries: entries),
)
```

Pump the widget and assert the final rank is immediately visible after a zero
duration pump. Repeat for `ArenaProgressTrack` and `ArenaResultStamp`.

- [ ] **Step 3: Test text scaling and minimum targets**

Pump the navigation and primary action widgets with text scale factor `2.0`.
Assert no overflow exception is reported and use `tester.getSize` to verify new
buttons and destinations are at least 48 logical pixels in both dimensions.

- [ ] **Step 4: Run accessibility and component tests**

Run:

```powershell
& "C:\src\flutter\bin\flutter.bat" test test/arena_components_test.dart test/app_shell_test.dart
& "C:\src\flutter\bin\flutter.bat" analyze
```

Expected: no analyzer warnings, no overflow errors, and all semantic assertions
pass.

### Task 12: Validate Motion And Rendering On Physical Devices

**Files:**

- Create: `docs/design/night-arena-device-qa.md`
- Read: `docs/superpowers/specs/2026-08-11-night-arena-visual-design-roadmap.md`
- Test: physical iPhone and Android profile builds

**Interfaces:**

- Consumes: the migrated shared components and the Figma `05 Device Review` page.
- Produces: reproducible evidence for visual, motion, accessibility, and performance gates.

- [ ] **Step 1: Create the device matrix**

Create a Markdown table with these columns:

```text
Device | OS | Build | Flow | Expected result | Actual result | Motion mode | Accessibility mode | Evidence | Owner
```

Include rows for two iPhones and two Android phones covering `HOY` load,
ranking overtake, offline cache, permission denied, source unavailable, meal
action launcher, round result, reduced motion, text scale, and grayscale.

- [ ] **Step 2: Run profile builds on physical hardware**

Use the Flutter profile workflow:

```powershell
& "C:\src\flutter\bin\flutter.bat" run --profile
```

Inspect navigation, ranking movement, feed scroll, and result stamp in Flutter
DevTools. Record any jank, texture cost, or glass fallback in the device matrix.

- [ ] **Step 3: Verify accessibility settings**

On iOS test VoiceOver, Reduce Motion, Reduce Transparency, Increase Contrast,
and larger text. On Android test TalkBack, Remove Animations, increased font
size, grayscale, and color-vision simulation. Confirm rank, freshness,
permission, and errors remain understandable without color.

- [ ] **Step 4: Record the release gate**

Only after evidence exists, update the relevant visual/device checkpoint in
`ROADMAP.md`. Do not mark a platform acceptance bullet complete from a widget
test or Windows build alone.

## Self-Review Checklist

- [ ] Every spec section maps to at least one task above.
- [ ] No task changes Supabase schemas, point rules, health aggregation, or RLS.
- [ ] Shared components do not import feature repositories.
- [ ] Existing test injection paths remain available.
- [ ] All four users remain visible in ranking states.
- [ ] No manual step-entry path is introduced.
- [ ] Source-unavailable, stale, denied, offline, and retryable states have copy and recovery actions.
- [ ] Motion has explicit durations and a reduced-motion path.
- [ ] No task depends on an unspecified package or undocumented API.
- [ ] No incomplete instruction or unowned decision remains in the plan.
- [ ] The plan leaves existing unrelated worktree changes untouched.
