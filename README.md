# Enfermicambio

A private fitness and social competition app for exactly four friends, running on two iPhones and two Android phones. Real-world movement and nutrition become the input to a private game: rankings, missions, streaks, trophies, achievements, seasons, and a shared activity feed.

This repository currently contains the product specification and delivery plan. The app is complete only when the acceptance criteria in `SPECS.md` and the release gate in `ROADMAP.md` pass on all four devices.

## What the Finished Product Looks Like

### First run

A new user opens the app and signs in with their pre-created account. There is no registration form; the four accounts already exist. A short onboarding explains that steps and workouts are read automatically from Apple Health or Health Connect, that manually entered steps do not count, and that the other three members can see shared fitness stats. The user connects their health source, sets a daily calorie target and step target, and lands on `HOY`.

### HOY (home)

The default screen. At the top, a personal summary for today:

```text
8,420 steps   510 active kcal   1 workout   1,540 / 2,200 kcal
```

Below it, the current four-person ranking, always showing all four users, each with a `last synced` indicator:

```text
1. Diego   9,800    synced 2 min ago
2. Nico    8,950    synced 5 min ago
3. Pedro   8,420    synced 1 min ago
4. Juan    7,310    stale - last sync 3 h ago
```

The rest of the screen is the shared private timeline: automatic events (step milestones, round results, overtake alerts, achievements) mixed with manual posts (photos, meals, workouts, routes). A user can react with an emoji or leave a comment on anything.

### RANKING

A segmented control switches between `Today`, `Week`, and `Season`. A category selector offers steps, rounds, distance, workouts, calories, nutrition, and game points. Every view shows all four users, including users with no data yet, clearly marked. Morning, afternoon, night, and full-day step rankings are first-class views.

### REGISTRAR

The action tab for nutrition and social content: scan a barcode, search food, photograph a meal, create a meal, write a post, attach a location, share a workout. There is deliberately no way to enter steps.

Scanning a barcode resolves the product through Open Food Facts, falling back to the group's private cache, then to USDA, then to a create-once custom food that all four users can reuse. The user picks a serving, assigns it to breakfast, lunch, dinner, snack, or other, and saves. The meal summary shows consumed, target, and remaining calories plus macro totals.

### JUEGO

The game screen: current season standings, today's missions, active streaks, the achievement collection, the trophy cabinet, and season history with past champions.

Points are not raw steps. Daily rank pays 10/7/4/2, each round win pays +3, hitting the step goal pays +2, a workout pays +3, staying within the calorie target pays +2, missions pay variable rewards. All values are server-configurable. Points are recorded in an append-only ledger; standings are derived from it.

Seasons run monthly. At season end the backend freezes standings, crowns a champion, publishes the result to the feed, and starts the next season at zero. Historical stats never reset.

### NOSOTROS

The four profiles: avatar, season rank, today's steps, current streaks, workouts and distance this week, season points, trophies, and lifetime stats (steps, distance, workouts, daily wins, round wins, season wins, longest streaks).

### A day in the feed

```text
08:34  Diego finished a run - 6.2 km, 36 min
09:01  Nico reached 5,000 steps
11:58  Pedro won the morning round
13:12  Juan logged lunch - 712 kcal [photo]
16:21  Diego reached 10,000 steps
18:00  Diego won the afternoon round
19:42  Pedro finished a workout - 58 min
21:04  Nico passed Diego by 214 steps
00:00  Daily result: Diego takes the day
```

Leader-change events are rate-limited so the feed stays fun instead of noisy.

## Architecture

```text
Flutter app (iOS + Android)
  |-- feature modules: auth, profiles, health, activity, ranking,
  |                    nutrition, workouts, feed, game, notifications
  |-- Apple HealthKit (iOS) / Health Connect (Android)
  |-- Flutter health abstraction plugin, native channels only for gaps
  |
Supabase
  |-- Auth (four allowlisted accounts, no public signup)
  |-- PostgreSQL + Row Level Security on every table
  |-- Realtime (delivery only; the database stays authoritative)
  |-- Private Storage (avatars, feed, meal, workout media)
  |-- Edge Functions + scheduled jobs (round closes, points, seasons)
```

Core data rules:

- Daily health aggregates upsert on `(user_id, date)`; re-syncing recalculates, never duplicates.
- Workouts de-duplicate on `(source, external_id)` where available.
- Food entries store nutrition snapshots; later source changes never rewrite history.
- Season points are an append-only ledger, writable only by backend jobs.
- All rounds and season cutoffs use one shared `competition_timezone`.

## Privacy and Security

- Exactly four allowlisted identities; anyone else reads nothing.
- RLS on every table: shared reads, owner-scoped writes, service-role-only game writes.
- Private storage buckets with signed URLs; no public media.
- No live location tracking. Location is attached explicitly, per post.
- Minimal permissions, requested in context. No secrets in source control.

## Technology

- Flutter / Dart.
- iOS: HealthKit. Android: Health Connect.
- Supabase: Auth, PostgreSQL, Realtime, Storage, Edge Functions.
- Barcode scanning: `mobile_scanner`.
- Food data: Open Food Facts first, USDA FoodData Central fallback, private group cache.
- Maps: `flutter_map` + OpenStreetMap, or MapLibre.
- Push: FCM/APNs.

## Setup

A Flutter scaffold with the Phase 0 health spike foundation exists in `lib/`. The full product is not built yet. Current commands:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Backend workflow:

```powershell
supabase start
supabase db reset
supabase db push
```

Configuration comes from a `.env` file based on `.env.example` (placeholders only, never committed with real values) and from the backend `app_config` table for game tuning.

Requirements: Flutter stable, Xcode with signing for the iPhones, Android SDK with a Health Connect-capable device, a Supabase project, and physical test devices. Health behavior cannot be fully validated on simulators.

## Development Status

In active development. The backend schema (Phases 0-1) is applied to the remote Supabase project: `profiles`, `daily_activity`, full Phase 1 schema with RLS, private storage buckets, the `award_points` ledger, and standings. The Flutter app has a five-tab shell, Google/email sign-in, the HOY dashboard with live rankings and feed, RANKING with freshness indicators, REGISTRAR actions, JUEGO season standings, NOSOTROS profiles, health sync (steps + calories + distance + exercise) with offline ranking cache, nutrition domain with Open Food Facts resolution, and workout de-duplication. See `ROADMAP.md` for the phase plan, `CODESTYLE.md` for engineering rules, and `SPECS.md` for the full product definition. Device validation and full acceptance still require physical iPhone/Android testing.
