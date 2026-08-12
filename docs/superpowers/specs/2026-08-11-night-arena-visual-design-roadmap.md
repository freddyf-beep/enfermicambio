# Night Arena Visual Design and Roadmap

**Status:** Approved for implementation planning
**Date:** 2026-08-11
**Scope:** Enfermicambio Flutter app, iOS and Android, private four-person competition

## Decision Summary

Enfermicambio will use **Night Arena** as its visual direction: a dark-first,
abstract sports-club scoreboard for four friends. The product will borrow the
clarity of Apple Fitness, the expressive state changes of modern Material, and
the emotional rhythm of Supercell arenas without copying any of their art,
characters, or monetization patterns.

The design must make today's competition obvious in seconds, keep health data
trustworthy, and reserve visual intensity for meaningful state changes. It must
not become a clinical dashboard, a public social network, a casino, or a generic
AI-generated dashboard made from identical rounded cards.

## Product Context

The app is a private competition for exactly four friends. Its core surfaces
are `HOY`, `RANKING`, `REGISTRAR`, `JUEGO`, and `NOSOTROS`. Health data is read
automatically from Apple Health or Health Connect, nutrition can be logged, and
the backend is authoritative for rankings, rounds, points, missions, and
seasons.

Existing product invariants remain unchanged:

- There are exactly four allowlisted users.
- There is no manual step-entry path.
- Detectable manual health records are excluded from competition data.
- The database, not the client or realtime stream, is authoritative.
- Private media and explicit location behavior remain private and recoverable.
- Product-facing Spanish labels remain at the UI boundary.

## Research Principles

### Apple Liquid Glass

Apple's WWDC25 design guidance establishes Liquid Glass as a dynamic material
for a functional floating layer. It recommends reserving glass for navigation
and controls, avoiding glass-on-glass stacking, and using tint selectively for
primary actions. The app will therefore use a restrained glass navigation rail,
not glass content cards.

Source: https://developer.apple.com/videos/play/wwdc2025/219/

### Material and Pixel

Material 3 Expressive and Material motion are useful references for expressive
states, adaptive layouts, and platform-consistent interaction behavior. The
brand palette will remain stable instead of being recolored by the user's
wallpaper; Material roles and contrast behavior will still guide component
semantics on Android.

Sources:

- https://m3.material.io/blog/building-with-m3-expressive
- https://m3.material.io/styles/motion/overview
- https://m3.material.io/styles/color/dynamic-color/overview

### Supercell Games

Brawl Stars and Clash Royale demonstrate a useful emotional grammar for this
product: quick modes, visible arenas, friends, live competition, clear outcomes,
and trophies. Enfermicambio will translate that grammar into four-player lanes,
round stamps, missions, and season results. It will not import character art,
loot boxes, random currency, or pressure mechanics.

Sources:

- https://supercell.com/en/games/brawlstars/
- https://supercell.com/en/games/clashroyale/

### Flutter and Figma

Flutter's current documentation supports implicit, explicit, and physics-based
animation approaches, adaptive layouts, accessibility testing, and physical
device performance profiling. Figma prototypes will be used to validate flows
and motion before widgets are migrated.

Sources:

- https://docs.flutter.dev/ui/animations
- https://docs.flutter.dev/ui/adaptive-responsive
- https://docs.flutter.dev/ui/accessibility
- https://docs.flutter.dev/perf/ui-performance
- https://help.figma.com/hc/en-us/articles/360040314193-Create-prototypes-with-interactions-and-animations

## Visual System

### North Star

> A living night scoreboard for four friends.

The interface has a quiet base and an energetic competition layer. The user
should understand the current position, the next available action, and the
freshness of the data before noticing decoration.

### Color Contract

The existing `DESIGN.md` palette remains the base contract. The following
extension adds player identity accents without changing the meaning of the
system colors.

| Token | Value | Job |
| --- | --- | --- |
| `scoreboard-lime` | `#C7FF00` | Primary action, selected state, progress, meaningful positive state |
| `lime-shadow` | `#8EBA00` | Pressed state, subtle active border |
| `heat-orange` | `#FF5A26` | Calories, workouts, duels, warnings |
| `night-canvas` | `#111211` | App background and visual rest |
| `training-surface` | `#1C1D1C` | Opaque content surfaces |
| `raised-surface` | `#292A28` | Controls, filters, navigation chrome |
| `graphite-border` | `#343632` | Boundaries and dividers |
| `warm-white` | `#F4F5EE` | Primary text and values |
| `quiet-ash` | `#A9ABA3` | Supporting text and stale metadata |
| `player-cyan` | `#56D9FF` | Player identity marker only |
| `player-amber` | `#FFC857` | Player identity marker only |
| `player-coral` | `#FF766E` | Player identity marker only |
| `player-violet` | `#B88CFF` | Player identity marker only |

Player accents appear in a lane stripe, avatar ring, small badge, or chart
series. They do not replace rank numbers, status icons, labels, or contrast
signals. Lime remains the competition and selection accent for the whole app.

### Glass Contract

- Use a translucent, blurred raised surface only for bottom navigation, compact
  filter rails, and transient overlays.
- Do not use glass for ranking rows, feed cards, nutrition summaries, or health
  permission explanations.
- Do not stack two glass surfaces.
- Provide an opaque `raised-surface` fallback when reduced transparency is
  enabled or when the effect is too expensive on a device.
- Use tint only for the selected destination or primary action.
- Keep text and icons legible against changing content underneath.

### Typography

The current single-family strategy remains the default for trust and scanning:

- Display and metric values use a heavy sans with tabular figures.
- Body copy uses the platform sans fallback.
- Labels are compact, high-weight, and short.
- A condensed display candidate may be tested in Figma for scoreboard values,
  but it must pass Spanish text, large text, and small-device readability tests
  before adoption.

No font choice is accepted because it looks fashionable in a mockup. It must
make `8,420`, `1.º`, `Sincronizado hace 2 min`, and long Spanish permission
copy readable at the same time.

### Geometry and Layout

- Preserve the existing 4/8/16/24/32 spacing scale.
- Use 12-16 px corners for content and 999 px pills only for compact controls.
- Keep content surfaces flat at rest; depth comes from tonal layers and borders.
- Use a single dominant visual per screen instead of a uniform grid of cards.
- Use asymmetric emphasis deliberately: one hero score, one live competition
  area, then calm supporting content.
- Keep interactive targets at least 48 logical pixels, matching Flutter's
  accessibility guidance.

## Information Architecture

### `HOY`

The screen opens on the current competition state. The top area shows the
current user's position, steps, goal progress, active calories, workout count,
and nutrition summary. The four-person ranking is a vertical track with fixed
player identity markers, rank numbers, values, lead/delta text, and freshness.
The feed follows below and uses compact event cards. A health connection card
appears when setup or recovery is needed, with one explicit action.

### `RANKING`

The screen exposes `Hoy`, `Semana`, and `Temporada`, then category and round
selectors. All four players remain visible in every state. Missing, stale,
denied, and unavailable data are distinct states. Position changes animate in
place and preserve row identity.

### `REGISTRAR`

The screen is an action launcher, not a dashboard. One primary action is
prominent and the remaining actions are compact secondary actions for barcode,
food, photo, post, workout, and route sharing. Food logging stays fast and
utilitarian; the game layer appears only in confirmation and progress feedback.

### `JUEGO`

The screen is the competition arena: season header, current standings, round
state, today's missions, active streaks, achievements, trophies, and season
history. A round result uses a strong stamp treatment. No random reward,
virtual currency, casino wheel, or endless celebratory motion is introduced.

### `NOSOTROS`

The screen is a private club roster. Each of the four members has a stable
identity marker and access to today's stats, weekly training, season points,
trophies, and lifetime history. It is not a public profile or follower feed.

### Shared Navigation

The existing five-destination `NavigationBar` remains semantically appropriate,
but its styling evolves into `ArenaNavigationBar`: a floating raised/glass rail,
lime active capsule, quiet inactive destinations, safe-area handling, and
platform-appropriate back behavior. Labels remain the existing Spanish product
labels.

## Component Contract

Shared components should remove visible inconsistency without absorbing feature
data or Supabase behavior:

- `ArenaAppHeader`: avatar, wordmark, screen context, notifications.
- `ArenaNavigationBar`: five destinations and active state.
- `ScoreHero`: one dominant metric with goal/progress state.
- `PlayerRankingLane`: four-player ordered competition rows.
- `MetricRail`: compact supporting metrics with icon and label.
- `RoundSelector`: time-window or competition-period selection.
- `StatusPill`: freshness, permission, offline, and sync states with icon/text.
- `ProgressTrack`: goal progress with reduced-motion behavior.
- `RoundResultStamp`: deterministic result and points presentation.
- `AchievementReveal`: non-random achievement/trophy celebration.
- `FeedEventCard`: event-specific compact content with reactions/comments.
- `HealthConnectionCard`: permission explanation and recovery action.

Components receive immutable view data and callbacks. They do not import
Supabase, HealthKit, Health Connect, or feature repositories. Feature screens
continue to own data loading, state mapping, and navigation.

## Motion Contract

Motion communicates cause, not decoration:

| Family | Use |
| --- | --- |
| Pulse | Syncing, live connection, active data refresh |
| Charge | Goal, streak, mission, and progress fill |
| Slide | Ranking position changes and lane movement |
| Stamp | Round closure, win, achievement, trophy, season result |
| Burst | High-value celebration only, such as a season win |

Motion budgets:

- Microinteraction: 120-180 ms.
- Navigation transition: 250-350 ms.
- Competition result: 450-700 ms with a restrained spring.
- No infinite background animation on ordinary screens.
- No repeated count-up animation caused by widget rebuilds.
- No animation for stale, denied, unavailable, or error states except a small
  state transition when the user explicitly retries.

Reduced-motion behavior removes particles, bounce, elastic deformation, and
long travel. The result remains understandable through opacity, color, icon,
text, and layout changes.

Flutter-native animation should handle the common path. Rive is optional and
must be justified by a specific celebratory asset after a prototype proves the
need. If used, the asset must support loading/error states and reduced-motion
behavior. Reference: https://rive.app/docs/runtimes/flutter/flutter

## State and Recovery Design

Every async state maps to a stable visual treatment and a user action:

| State | Visual treatment | Action |
| --- | --- | --- |
| `permission_denied` | Quiet warning icon, explanation, settings/retry action | Retry or open settings |
| `source_unavailable` | Platform-specific explanation, no false zero | Install/open supported source |
| `no_data` | Calm empty state, explain automatic source behavior | Connect or wait for source data |
| `stale_data` | Timestamp and stale label, retained last value | Refresh/retry |
| `backend_unavailable` | Preserve cached content and show offline banner | Retry when connected |
| `validation_failed` | Inline field-specific message | Correct input |
| `retryable_failure` | Preserve intent and show retry progress | Retry without duplication |

Color is never the only signal. Spanish copy stays at the UI boundary while
the domain keeps the existing English state vocabulary.

## Platform and Accessibility Contract

- Keep one brand system across iOS and Android; do not create separate visual
  products.
- Adapt safe areas, system bars, back navigation, permission sheets, haptics,
  and platform controls where users expect native behavior.
- Keep the branded competition palette stable rather than applying Android
  wallpaper colors to rankings or player identity.
- Respect reduced motion, reduced transparency, increased contrast, text scale,
  VoiceOver, TalkBack, and color-vision needs.
- Test all four player colors in grayscale and color-vision simulation.
- Use icon plus text/number for rank, freshness, permission, and failure.
- Treat 48x48 logical pixels as the minimum target in new components.
- Validate contrast at 4.5:1 or better for normal text and controls.

## Prototype and Tooling Workflow

Create one Figma file with these pages:

- `00 Research`: references, rejected directions, and anti-patterns.
- `01 Foundations`: variables for color, type, spacing, radius, and motion.
- `02 Components`: component states and accessibility variants.
- `03 Golden Flows`: `HOY`, ranking overtake, meal logging, round result.
- `04 Motion`: timing, easing, reduced-motion alternatives, and screen video.
- `05 Device Review`: iPhone and Android frames with issue annotations.

The prototype must include real-looking data for exactly four players and these
states: normal day, live overtake, round win, no data, stale data, offline,
permission denied, and season victory. It must be reviewed on a phone-sized
frame before implementation.

Anti-generic review rules:

- No screen may be approved as a repeated grid of equal rounded cards.
- Every competition screen must expose a recognizable four-player or round
  structure.
- Every decorative effect must explain a state, hierarchy, or interaction.
- Do not use stock fitness imagery for the core UI.
- Do not generate final visual assets with AI without a human-directed style
  pass and a licensing check.
- Compare the prototype against the product anti-references in `PRODUCT.md`.

## Flutter Implementation Boundary

The implementation should extend the existing theme instead of introducing a
parallel design system immediately:

- Extend `AppColors` and `AppTheme` with the Night Arena tokens.
- Add focused token types for spacing, radii, typography, motion, and player
  identity rather than scattering literals through feature screens.
- Style or wrap the existing `NavigationBar` before replacing its semantics.
- Migrate shared primitives first, then migrate one tab at a time.
- Keep feature repositories and domain models unchanged unless a visual state
  needs an existing field exposed by the presenter.
- Keep animation keys/state transitions at the presentation boundary so data
  correctness remains independent of motion.

## Roadmap

### Phase A: Freeze the visual contract

Deliverables:

- Approve this spec and reconcile it with `DESIGN.md`.
- Record the final palette, player identity mapping, typography candidate, and
  motion budget in the Figma variables.
- Audit current screens against the five-tab composition and list only visible
  inconsistencies.

Gate:

- All visual direction choices are fixed.
- Product invariants and current health/permission states are represented.

### Phase B: Build the Figma foundations

Deliverables:

- Foundation variables and text styles.
- Four player identity markers.
- Opaque content surfaces and one navigation glass treatment.
- Empty, stale, offline, denied, unavailable, and loading variants.
- Component states for light/dark and reduced motion.

Gate:

- A designer can assemble a complete screen without inventing a new color,
  radius, or status treatment.

### Phase C: Prototype the golden path

Deliverables:

- `HOY` opening state.
- Ranking overtake flow.
- Nutrition logging flow.
- Round result and achievement flow.
- `NOSOTROS` private roster flow.

Gate:

- A user can identify today's position, next action, and data freshness within
  five seconds of opening `HOY`.
- The four-person competition is recognizable without explanatory narration.

### Phase D: Validate motion

Deliverables:

- Motion board for pulse, charge, slide, stamp, and burst.
- Reduced-motion alternatives for every animated state.
- Figma prototype recordings on iPhone and Android-sized frames.

Gate:

- No animation repeats unexpectedly.
- No celebration is attached to a routine action.
- Motion communicates the changed state even with sound disabled.

### Phase E: Implement shared Flutter primitives

Deliverables:

- Theme/token extension in `lib/shared/ui`.
- `ArenaAppHeader`, `ArenaNavigationBar`, `ScoreHero`,
  `PlayerRankingLane`, `StatusPill`, and `ProgressTrack`.
- Widget tests for semantics, targets, text scale, and state variants.

Gate:

- `flutter analyze` is clean.
- Existing navigation and feature tests remain green.
- Shared primitives do not import feature repositories.

### Phase F: Migrate the tabs incrementally

Migration order:

1. `HOY`, because it carries the product promise and health recovery.
2. `RANKING`, because it proves the four-player visual language.
3. `JUEGO`, because it proves rewards and motion.
4. `REGISTRAR`, because it needs speed and form clarity.
5. `NOSOTROS`, because it completes identity and history.

Each tab must be migrated with its loading, empty, offline, stale, denied,
unavailable, error, and reduced-motion states. Avoid mixing a large visual
rewrite with unrelated backend behavior changes.

Gate:

- Each tab passes focused widget tests and a screenshot review against Figma.
- No manual step entry or privacy boundary is introduced.

### Phase G: Physical-device polish and release evidence

Deliverables:

- One iPhone and one Android device for functional motion checks, then the full
  two-iPhone/two-Android four-user matrix.
- Profile-mode performance review for navigation, ranking movement, feed scroll,
  and achievement reveal.
- Accessibility review with VoiceOver, TalkBack, text scaling, reduced motion,
  increased contrast, grayscale, and color-vision simulation.
- Offline/reconnect review for cached ranking, feed, and queued actions.

Gate:

- No visible jank in the core flows on physical devices.
- All four users can identify themselves and each other consistently.
- Stale, missing, denied, unavailable, and cached data remain understandable.
- Evidence is recorded in `ROADMAP.md` before release claims are made.

## Acceptance Checklist

- `HOY` makes today's competition the first meaningful visual.
- All four users are always represented in rankings.
- A rank change is understandable without relying on color.
- Glass is limited to navigation and transient controls.
- Cards are not the only visual grammar.
- The primary action is obvious on every tab.
- Routine data refreshes do not trigger celebratory motion.
- Reduced motion preserves information hierarchy.
- Text scaling does not clip scores, labels, or recovery actions.
- Offline and stale states preserve useful last-known information.
- Permission screens explain the reason and recovery path.
- No manual step entry exists.
- No public social mechanics or casino-like rewards appear.
- Flutter analysis, focused tests, and physical-device performance checks pass.

## Alternatives Rejected

### Full Supercell-style characters

Rejected because the product is a small private sports club, not a character
collection game. It would add asset and content overhead while weakening trust
around health data.

### Glass on every surface

Rejected because it harms hierarchy, contrast, and performance. It also copies
the operating system instead of giving Enfermicambio a distinct identity.

### Neon cyberpunk as the primary language

Rejected because it risks looking like a generic AI-generated esports template
and makes nutrition, permissions, and recovery states harder to scan.

### Separate iOS and Android visual systems

Rejected because four friends should perceive one competition. Platform-native
behavior is retained where it improves usability, but the product identity is
shared.

## Consequences

Night Arena gives the existing app a strong, implementable identity without
requiring a new backend or a wholesale rendering engine. The largest work is a
shared presentation/token pass followed by incremental tab migration. The
design deliberately spends visual complexity on the competition layer and keeps
health, nutrition, privacy, and recovery states calm and explicit.
