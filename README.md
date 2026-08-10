# Enfermicambio

Enfermicambio is a private fitness and social competition app for exactly four known friends. It turns automatically recorded movement and manually logged nutrition into shared rankings, workouts, missions, streaks, trophies, achievements, seasons, and a private activity feed.

This repository currently contains the product specification and implementation documentation. The application is complete only when the implementation satisfies the acceptance criteria in `SPECS.md` and the release gate in `ROADMAP.md`.

## Product Definition

The finished app is intended for two iPhones and two Android phones:

- HealthKit supplies iOS activity data.
- Health Connect supplies Android activity data.
- Supabase provides authentication, PostgreSQL, Realtime, private storage, and server-side jobs.
- Flutter provides the mobile application and shared feature code.

The app is intentionally small and private. It is not a public social network, commercial SaaS product, marketplace, coaching service, or multi-tenant platform.

## Core Behavior

### Private four-user access

- Exactly four accounts are pre-created or allowlisted.
- There is no public registration, group creation, discovery, followers, billing, advertising, or public profile.
- All four users can read the shared fitness statistics and private feed.
- Each user can modify only their own profile, health-derived records, nutrition entries, workouts, and manual posts according to the access rules.

### Automatic activity

- Steps are read from Apple HealthKit or Android Health Connect.
- The app has no manual step-entry UI.
- Step samples marked as manually entered are rejected when the platform exposes that metadata.
- Phone and wearable sources are handled with platform aggregation and de-duplication behavior where possible.
- Daily steps are split into configurable morning, afternoon, night, and total windows.
- All rounds and season cutoffs use one shared `competition_timezone`, not each device's local timezone.
- The UI exposes a `last synced` timestamp and distinguishes stale, missing, denied, and unavailable data.

### Competition

The app provides:

- morning, afternoon, night, and full-day rankings;
- today, week, and season statistics;
- active calories, distance, workouts, exercise minutes, nutrition, and game points;
- configurable points for ranks, round wins, step goals, workouts, calorie targets, and missions;
- personal improvement ranking as an optional fairness feature.

Game points are not raw step totals. They are awarded by validated rules and recorded in an immutable season ledger.

### Workouts and routes

Workouts may be imported automatically from HealthKit or Health Connect. A workout can include type, start/end time, duration, distance, active calories, pace/speed, source, and route availability.

When route data exists, the finished app renders it in workout detail and may show a compact route preview in the feed. Route sharing is explicit. There is no live location tracking, navigation, or turn-by-turn directions.

### Nutrition

Users can log breakfast, lunch, dinner, snacks, and other meals. Nutrition supports:

- calorie targets and optional protein, carbohydrate, and fat targets;
- barcode scanning for EAN/UPC products;
- Open Food Facts as the primary lookup source;
- USDA FoodData Central as a fallback;
- a private four-user food cache;
- custom foods and quantities;
- meal photos;
- optional meal posts.

For the MVP, `within_calorie_target` means consumed calories are less than or equal to the configured daily target. The app must not describe consumed calories minus exercise calories as a real metabolic deficit without a separate validated model.

### Social feed

The private feed combines manual posts and automatic events. Supported content includes text, photos, meals, workouts, routes, achievements, step milestones, ranking changes, round results, missions, and seasons.

Users can:

- add captions and optional explicit post locations;
- react once per emoji per post;
- add flat comments;
- delete their own comments;
- publish meals, workouts, routes, and achievements intentionally.

Automatic feed events are rate-limited so leader changes do not overwhelm the timeline.

### Game layer

The game screen contains the current season, standings, missions, streaks, achievements, trophies, and season history. The rules are configurable and include individual, competitive, and cooperative missions.

At the end of a season, the backend freezes standings, stores final positions, awards the champion trophy, publishes the result, and starts a new season with zero points. Historical activity and trophies remain available.

## Architecture

```text
Flutter mobile app
  |
  +-- Feature modules
  |     +-- Auth and profiles
  |     +-- Health sync
  |     +-- Activity and rankings
  |     +-- Nutrition
  |     +-- Workouts and routes
  |     +-- Feed and notifications
  |     +-- Missions, achievements, streaks, seasons
  |
  +-- Platform health APIs
  |     +-- Apple HealthKit
  |     +-- Android Health Connect
  |
  +-- Supabase
        +-- Auth
        +-- PostgreSQL
        +-- Row-level security
        +-- Realtime
        +-- Private Storage
        +-- Edge Functions or scheduled jobs
```

The database is authoritative. Realtime is an update mechanism, not the sole source of truth. Health aggregates are idempotent, workouts use external source IDs where available, food entries are editable records, and points are append-only ledger entries.

The expected primary data model includes:

- `profiles`;
- `daily_activity`;
- `workouts`;
- `workout_route_points`;
- `foods`;
- `food_entries`;
- `posts`;
- `post_media`;
- `comments`;
- `reactions`;
- `achievements`;
- `user_achievements`;
- `streaks`;
- `missions`;
- `mission_progress`;
- `seasons`;
- `season_points`;
- `season_results`;
- configurable app settings.

## Navigation

The product navigation uses these product identifiers:

```text
HOY        Personal summary, current ranking, and shared feed
RANKING    Today, week, and season comparisons
REGISTRAR  Nutrition, barcode, meal photos, and social actions
JUEGO      Missions, streaks, achievements, trophies, and seasons
NOSOTROS   The four profiles and historical shared statistics
```

The identifiers above may remain localized in the product UI. Engineering documentation, code symbols, logs, and test names remain in English.

## Main Workflows

### First login

```text
Login
  ->
Connect Health
  ->
Choose only the required permissions
  ->
Set calorie target
  ->
Set step target
  ->
Ready
```

The onboarding must explain that activity is read automatically, manual steps do not count, and the other three members can see shared fitness statistics.

### Health sync

```text
Open or foreground app
  ->
Request or verify health permissions
  ->
Read accepted automatic records
  ->
De-duplicate and reject detectable manual entries
  ->
Split by competition timezone and configured windows
  ->
Upsert daily aggregates
  ->
Refresh rankings and last-synced state
```

Background refresh and platform notifications are best-effort. The product must not promise second-by-second synchronization.

### Food logging

```text
Scan barcode
  ->
Lookup Open Food Facts
  ->
Fallback to USDA or private cache
  ->
Create custom food if missing
  ->
Choose serving and quantity
  ->
Choose meal type
  ->
Save nutrition snapshot
  ->
Optionally publish to feed
```

Search follows the same data-source priority without requiring a barcode.

### Workout sharing

```text
Import workout
  ->
De-duplicate by source identifier
  ->
Show stats and route when available
  ->
Optionally publish a workout or route card
```

### Daily and season lifecycle

At round boundaries, the backend closes the relevant window, records the winner, awards verified points, and publishes a result. At the end of the competition day it evaluates daily points, streaks, achievements, missions, historical stats, and a daily summary. At season end it freezes results, awards the champion trophy, publishes the result, and starts the next season.

## Privacy and Security

- Require authentication for all application data.
- Allow only the four known identities to access the app.
- Apply row-level security to every user-owned and shared table.
- Keep health, nutrition, route, location, and media data private to the four users.
- Use authenticated storage access or signed URLs; do not use public media buckets.
- Request only permissions needed by the current feature set.
- Request location only for explicit route or post-location actions.
- Keep system-generated posts and game-point awards behind trusted backend validation.
- Do not log raw health records, access tokens, or unnecessary location details.
- Do not commit secrets. Use local configuration placeholders and deployment-managed secret storage.

## Setup

The implementation is expected to require:

- Flutter and Dart;
- Xcode and an Apple development environment for iOS;
- Android Studio, Android SDK, and a Health Connect-capable Android device for Android;
- a Supabase project;
- configured Apple/Google authentication only if those providers are enabled;
- device permissions for HealthKit, Health Connect, camera, media, location, and notifications only where used.

The exact repository commands should be added when the project structure exists. The expected command shape is:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Expected backend workflow placeholders:

```powershell
supabase start
supabase db reset
supabase db push
```

Use the project's chosen Supabase CLI workflow once migrations and local configuration are present. Do not place real URLs, keys, tokens, signing credentials, or user passwords in this document or in source control.

Before running a device build, configure the platform-specific health permissions and the app's local environment values using the repository's eventual template, such as `.env.example`. The template must contain names and safe placeholders only.

## Development Status

The implementation is not claimed to exist merely because this README describes it. The first engineering task is the cross-platform health spike described in `ROADMAP.md`: read today's automatic steps on one iPhone and one Android device, exclude detectable manual entries, split the result into configured windows, and upload idempotent aggregates to Supabase.

The planned delivery order is:

1. Health spike.
2. Foundation, authentication, schema, and RLS.
3. Health synchronization and rankings.
4. Game rules, missions, streaks, achievements, and seasons.
5. Social feed and notifications.
6. Nutrition and barcode logging.
7. Workouts, routes, maps, and profile history.
8. Offline behavior, backups, hardening, and release validation.

Use `ROADMAP.md` for phase checkpoints and `CODESTYLE.md` for implementation rules.

## Expected MVP

The MVP is complete when all four users can authenticate and use the private app with:

- HealthKit and Health Connect step sync;
- detectable manual-step rejection;
- morning, afternoon, night, and daily rankings;
- active calories, distance, and workout import;
- monthly season points and a champion result;
- private feed with automatic events, photos, comments, and reactions;
- food logging, barcode lookup, custom food fallback, calories, and macros;
- streaks, initial achievements, initial missions, and a season trophy;
- route maps in workout detail when route data exists;
- privacy, offline, error, backup, and recovery behavior that has passed the release checkpoint.

The product succeeds by supporting daily use by these four people. It is intentionally personal, small, and maintainable.
