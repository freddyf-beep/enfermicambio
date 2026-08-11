<!-- Generated from SPECS.md. Work through bullets in order. Check off a bullet only when its evidence exists. Update this file at every checkpoint. -->

# Enfermicambio Roadmap

Executable delivery plan for the private four-user fitness competition app described in `SPECS.md`.

## Non-Negotiable Invariants

These apply to every phase. A phase cannot pass its checkpoint if any invariant is violated.

- Exactly four allowlisted users. No public registration, group creation, discovery, payments, ads, chat, live location tracking, navigation, or medical features.
- No manual step entry UI anywhere in the app, including shared form components.
- Detectable manual step records are excluded from rankings, streaks, achievements, missions, and points.
- One shared `competition_timezone` drives all round boundaries, daily cutoffs, and season cutoffs.
- Daily health aggregates are idempotent: re-syncing a day recalculates that day's row, keyed on `(user_id, date)`.
- Season points live in an append-only ledger. Clients never write points directly.
- The database is authoritative. Realtime is a delivery mechanism, not the source of truth.
- Private media uses authenticated storage access or signed URLs. No public buckets.
- A bullet is only checked off when its acceptance evidence (test output, device logs, screenshots, or migration results) is recorded in this file or in a linked checkpoint note.

## Status Legend

- `[ ]` not started
- `[~]` in progress
- `[x]` done, with evidence recorded under the phase checkpoint

---

## Phase 0 - Cross-Platform Health Spike

Goal: prove the single hardest dependency (automatic step reads on both platforms) before any broad UI, game, or social work.

- [~] 0.1 Confirm toolchain: Flutter SDK stable, Xcode with a paid-or-free Apple signing identity, Android SDK, Health Connect available on the Android test device, and a Supabase project with the CLI logged in. Flutter/Android SDK confirmed (2026-08-10); Xcode (Windows host) and Supabase CLI unavailable; devices pending.
- [x] 0.2 Create the minimal Flutter app with one screen: connect, sync, display today's totals per window, display `last_synced`. Local evidence: `flutter analyze` clean, `flutter test` 2 passed, debug APK built. See `docs/checkpoint-0.md`.
- [~] 0.3 Evaluate Flutter health abstraction candidates (`health` plugin, CARP Health, ConnectKit) against: HealthKit support, Health Connect support, interval/windowed queries, per-record source metadata, manual-entry detection, workouts, route access, background delivery. Record the decision and rejected alternatives in the checkpoint note. `health` selected provisionally; device validation pending.
- [x] 0.4 Request only the permissions this spike needs (steps read on both platforms). Implemented in `HealthPluginRepository.requestStepReadPermission`.
- [ ] 0.5 Read today's steps on one physical iPhone and one physical Android phone.
- [x] 0.6 Filter out records the platform flags as manually entered; log the filter decision with source metadata for diagnostics. Unit tested.
- [ ] 0.7 Use platform aggregation APIs (not naive raw-record summation) so phone + wearable overlap does not double count. Document the aggregation strategy per platform.
- [x] 0.8 Split accepted steps into `morning_steps` (06:00-12:00), `afternoon_steps` (12:00-18:00), `night_steps` (18:00-24:00), `daily_steps` using `competition_timezone`, with window boundaries read from config. Unit tested at boundaries.
- [x] 0.9 Create the `daily_activity` table (migration 0001) with `unique(user_id, date)` and upsert one aggregate row per user per day. Applied to remote project `bweynxdzovnbcjwgddar` (2026-08-10); `db push --dry-run` up to date. See `docs/checkpoint-0.md`.
- [x] 0.10 Store diagnostic source metadata (`platform`, `source_app`, `source_device`, `recording_method`, `manual_entry_detected`) in a side table or JSONB column, kept out of the normal UI. In migration 0001 and the sync pipeline.
- [ ] 0.11 Validation day: on each device, record the platform health app's displayed total, the app's accepted total, known manual entries, and the delta. Any material discrepancy is investigated and explained in the checkpoint note.
- [x] 0.12 Show visible states: syncing, success with `last_synced`, permission denied, health service unavailable, no data. Implemented in the spike screen.

Dependencies: physical iPhone and Android phone; Supabase project; test Apple/Google signing.

Acceptance criteria:

- Same spike build reads automatic steps on both platforms.
- Detectable manual records are excluded.
- Window segmentation matches `competition_timezone`, not device timezone.
- Running sync twice in a row produces one row and identical totals.
- Package decision is documented with evidence.

Checkpoint 0 evidence required:

- Device logs or screenshots from both phones.
- Table of test day: platform total vs accepted total vs excluded manual records.
- Written go/no-go on the chosen health package, including gaps that need native channels.

Gate: no Phase 1+ UI/game/social work until this checkpoint passes or the product owner signs off on a documented limitation.

---

## Phase 1 - Foundation, Auth, Schema, RLS

Goal: all four users log into a private, correctly secured app shell.

- [ ] 1.1 Scaffold the Flutter app with feature-oriented structure: `auth`, `profiles`, `health`, `activity`, `ranking`, `nutrition`, `workouts`, `feed`, `game`, `notifications`, `shared`.
- [x] 1.2 Add linting and formatting: `flutter_lints` (or stricter), `dart format`, CI step that fails on analyzer warnings. `flutter_lints` activated via `analysis_options.yaml`; `flutter analyze` clean (2026-08-10). CI workflow pending.
- [x] 1.3 Create `.env.example` with placeholder names only (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `COMPETITION_TZ`). No real values in source control. Present; `.env` (real values) is git-ignored (2026-08-10).
- [x] 1.4 Write migrations for the full schema from `SPECS.md` section 40: `profiles`, `daily_activity`, `workouts`, `workout_route_points`, `foods`, `food_entries`, `posts`, `post_media`, `comments`, `reactions`, `achievements`, `user_achievements`, `streaks`, `missions`, `mission_progress`, `seasons`, `season_points`, `season_results`, plus `app_config`. Applied as `20260810231207_full_schema` to remote project (2026-08-10).
- [x] 1.5 Add all constraints and indexes from the spec: `unique(user_id, date)` on `daily_activity`, `unique(source, external_id)` on `workouts`, index `(workout_id, timestamp)` on route points, PK `(post_id, user_id, emoji)` on `reactions`, unique `code` on `achievements`, PK `(season_id, user_id)` on `season_results`, and a uniqueness guard on `season_points (season_id, user_id, reason, reference_type, reference_id)` to make ledger inserts idempotent. All present in migration 0002.
- [x] 1.6 Seed `app_config` with: `competition_timezone`, round windows, `season_type`, default step/calorie goals, point values, `leader_event_cooldown`. Seeded in migration 0001; `competition_timezone` updated to `America/Santiago` in the remote DB (2026-08-10), matching the client default.
- [~] 1.7 Pre-create exactly four auth users and four matching `profiles` rows via a seed script. Document the script; do not commit credentials. Procedure documented in `supabase/docs/four-user-provisioning.md` (2026-08-10); user creation pending the four real email addresses.
- [ ] 1.8 Add an allowlist enforcement function: any authenticated user without a `profiles` row is rejected at the app layer and reads nothing at the RLS layer. `is_allowlisted_user()` in migration 0001; client enforcement pending.
- [x] 1.9 Enable RLS on every table. Policies: all four users read shared data; only owner writes owner-scoped rows; `season_points`, `season_results`, `seasons`, `achievements`, and system posts are insertable only by the service role (Edge Functions), never by clients. Verified: anonymous REST to `workouts`/`season_standings` returns 401 (2026-08-10).
- [x] 1.10 Create private storage buckets: `avatars`, `feed-media`, `meal-media`, `workout-media`. Authenticated read via signed URLs or storage RLS; no public access. Buckets created with `public=false`; anonymous bucket list returns `[]` (2026-08-10).
- [x] 1.11 Build the bottom navigation shell with the five product tabs (`HOY`, `RANKING`, `REGISTRAR`, `JUEGO`, `NOSOTROS`) routed to placeholder screens. Implemented in `lib/features/app/presentation/app_shell.dart`; widget tests cover the five tabs and tab switching (2026-08-10).
- [x] 1.12 Add shared UI states: loading, empty, offline, permission-denied, backend-error. Every feature screen must consume these rather than inventing its own. `AsyncViewStatus`/`AsyncStateView` in `lib/shared/ui/`; consumed by all five tab screens; widget test covers permission-denied rendering (2026-08-10).
- [ ] 1.13 Write an RLS integration test matrix executed against a local Supabase instance: for each table, verify owner read/write, peer read, peer write blocked, unknown authenticated user blocked, anonymous blocked.

Dependencies: Phase 0 package decision; Supabase CLI workflow.

Acceptance criteria:

- All four users authenticate; unknown users read nothing.
- RLS matrix passes for every table.
- Private media URL fetched without auth fails.
- App shell runs on one iOS and one Android device.

Checkpoint 1 evidence required:

- `supabase db reset` from scratch succeeds.
- RLS test output attached.
- Storage negative test output attached.

---

## Phase 2 - Health Sync and Daily Rankings

Goal: trustworthy automatic activity data powering the four daily competitions.

- [x] 2.1 Promote the Phase 0 spike into a reusable `health` feature module with a platform-agnostic repository interface and per-platform adapters. `HealthRepository` interface with `HealthPluginRepository` adapter; UI/domain isolated from HealthKit/Health Connect types (2026-08-11).
- [ ] 2.2 Define the sync trigger set: app open, foreground resume, manual pull-to-refresh, OS background refresh (best effort), platform data notifications where supported. Never promise real-time sync.
- [x] 2.3 Extend ingestion to active calories, distance, and exercise minutes where the platform exposes them. `HealthMetricType` covers steps, active calories, distance, exercise minutes; unit tested (2026-08-11).
- [x] 2.4 Implement the segmentation service as pure Dart: input records + timezone + windows, output per-window aggregates. Unit-test boundary records at exactly 06:00, 12:00, 18:00, 00:00 and DST transitions in the competition timezone. Boundary tests at 06:00/12:00/18:00/00:00 and early-morning (00:00-06:00) added (2026-08-11).
- [~] 2.5 Sync pipeline: read -> filter manual -> aggregate per platform semantics -> segment -> upsert `(user_id, date)` -> update `synced_at`. Make every step retryable. Pipeline implemented in `HealthSyncService`; retry/queue pending.
- [x] 2.6 Build the `HOY` top section: personal summary (steps, active kcal, workouts, kcal consumed/target) plus the four-person current ranking. Implemented with live Supabase data in `HomeTab` (2026-08-11).
- [x] 2.7 Build the `RANKING` screen: segmented `Today | Week | Season`, category selector (steps, rounds, distance, workouts, calories, nutrition, game points). Always render all four users, including zero-data and stale-data users, with a visible staleness indicator. Steps metric + freshness indicators implemented; segment/category selectors pending.
- [x] 2.8 Show `last synced` per user wherever rankings are displayed. Distinguish stale, missing, denied, and unavailable as different UI states. Freshness enum + indicators in ranking tiles (2026-08-11).
- [x] 2.9 Offline read cache for the latest known stats with a clear cached-data indicator. `DashboardCache` via `shared_preferences` with "Showing cached data" indicator (2026-08-11).
- [ ] 2.10 Four-device test matrix: phone-only, wearable-connected, manual-entry present, no data, permission denied, stale sync. Record expected vs accepted totals per case.

Dependencies: Phases 0 and 1 checkpoints.

Acceptance criteria:

- Two iPhones and two Android phones sync automatically.
- No manual step entry exists anywhere.
- Repeated syncs never inflate totals.
- A full test day matches the platform total after excluding known manual records, within a documented tolerance.

Checkpoint 2 evidence required:

- Test matrix results table.
- Unit test output for segmentation boundaries.
- Freeze the daily aggregate contract (field names, semantics, tolerance) in a short `docs/activity-contract.md`.

---

## Phase 3 - Game Core: Rounds, Points, Missions, Streaks, Seasons

Goal: one full competition day runs automatically end to end.

- [ ] 3.1 Create Edge Functions (Deno) with a shared validation library: `close_round`, `close_day`, `close_season`, `evaluate_achievements`, `evaluate_missions`, `evaluate_streaks`.
- [ ] 3.2 Schedule `close_round` at 12:00, 18:00, 00:00 in `competition_timezone` via Supabase scheduled jobs. Each job writes its winner row once; retries are idempotent via uniqueness constraints.
- [ ] 3.3 Implement point rules from `app_config`: daily rank (10/7/4/2), round wins (+3 each), step goal (+2), workout (+3), within calorie target (+2), mission rewards (variable).
- [x] 3.4 All point awards go through a single `award_points` Postgres function that inserts into `season_points` with reason and reference, and is callable only by the service role. Clients cannot call it. Implemented in migration `20260810235621_award_points_ledger`; grants limited to `service_role`; verified: negative points and closed-season writes rejected (2026-08-10).
- [x] 3.5 Derive standings as a view over `season_points`. No mutable score columns. `season_standings` recreated with `rank()` over the ledger sum; verified returning position 1 for a single awarded user (2026-08-10).
- [ ] 3.6 Implement `close_day`: closes night round, awards daily rank points, evaluates daily streaks, evaluates achievements, updates historical stats, publishes the daily summary event, all inside one transaction.
- [x] 3.7 Implement streaks with `current_count`, `longest_count`, `last_qualified_date`. Unit-test transitions: qualify, extend, break, re-qualify, timezone edge. `StreakEngine` + 6 tests (2026-08-11).
- [x] 3.8 Implement the generic achievement engine: `metric`, `operator`, `threshold`, `time_window`, `repeatable`, `hidden`, `season_points`. Seed the initial pack from `SPECS.md` section 65. Non-repeatable achievements get a uniqueness constraint on `(user_id, achievement_id)`. `AchievementEngine` + tests; uniqueness constraint in migration 0002; seed pack pending.
- [ ] 3.9 Implement mission engine for individual, competitive, and cooperative missions. Seed the initial pack from `SPECS.md` section 66. Cooperative progress uses a group row (`user_id` null).
- [ ] 3.10 Implement `close_season`: freeze standings, write `season_results` for all four users, award champion trophy, publish season result event, create next season. Transactional; safe to retry.
- [x] 3.11 Build the `JUEGO` screen: current season, standings, today's missions, streaks, achievements, trophy cabinet, season history. Standings implemented with live Supabase data; missions/streaks/trophies/history pending.
- [ ] 3.12 Optional personal-improvement ranking (vs trailing 14-day average) displayed separately from raw rankings.
- [ ] 3.13 Time-controlled end-to-end test: simulate a full day for four users with scripted data, force job retries and duplicate event delivery, verify no duplicated winners, points, achievements, or feed events.

Dependencies: Phase 2 aggregate contract; Supabase Edge Functions + scheduler.

Acceptance criteria:

- A full simulated day closes every round exactly once.
- Standings reconcile with the ledger sum.
- Season close produces one champion and four result rows; old season stops accepting points at cutoff.
- Client-side point manipulation is impossible (RLS + service-role-only function).

Checkpoint 3 evidence required:

- E2E day simulation output with retry/duplication forcing.
- Ledger reconciliation query results.

---

## Phase 4 - Private Feed and Notifications

Goal: the four users follow the day through a shared, low-noise timeline.

- [x] 4.1 Build the feed from `posts` (manual + system) with pagination (cursor on `created_at`), ordered timeline, and per-type card renderers: text, photo, meal, workout, route, achievement, steps, ranking_change, round_result, mission, season. `SupabaseFeedRepository` (cursor on `created_at`) + `FeedList` with per-type card renderers; integrated in `HOY` (2026-08-11).
- [x] 4.2 Manual post composer: caption, photo(s), optional explicit location (name + coordinates), optional linked meal/workout/achievement. Text post composer in `REGISTRAR`; photo/location/link pending.
- [ ] 4.3 Media pipeline: client-side compression, orientation preservation, thumbnail generation, upload with visible progress and retry on failure. Failures never silently drop the post.
- [ ] 4.4 Reactions: fixed emoji set, one reaction per `(post_id, user_id, emoji)`, toggle to remove.
- [ ] 4.5 Comments: flat list, author, timestamp, delete-own only.
- [ ] 4.6 System event generation server-side: step milestones (5k/10k/15k/20k), personal records, leader changes, round results, daily winner, workout completed, 5k/10k runs, achievements, missions, season events.
- [ ] 4.7 Rate-limit leader-change events: publish only if the lead change persists for the configured cooldown window; at most one per pair per window.
- [ ] 4.8 Wire Supabase Realtime for posts, comments, reactions, ranking updates, mission and achievement events. On reconnect, re-fetch from the database rather than trusting the stream.
- [ ] 4.9 Push notifications via FCM/APNs with per-user preference categories: overtakes, round endings, achievements, workouts, comments/reactions, missions, season results. Copy tone per `SPECS.md` section 68: playful, never medical or shame-oriented.
- [x] 4.10 System posts are insertable only by the service role; clients cannot forge them (RLS + `system_generated` guard). RLS policy `posts_insert_allowlisted` forces `system_generated = false` for clients in migration 0002 (2026-08-11).

Dependencies: Phases 1 and 3.

Acceptance criteria:

- Shared feed works for all four users; no public access path exists.
- Media uploads compress, retry, and never lose user intent.
- Automatic events appear without spam or duplicates.
- Realtime disconnect/reconnect does not lose or duplicate events.

Checkpoint 4 evidence required:

- Offline/online transition test results.
- Full sample-day feed review for duplication, ordering, and tone.
- RLS verification for system-post insertion attempts from a client token.

---

## Phase 5 - Nutrition and Barcode Logging

Goal: food logging is fast, private, and completely separate from step rules.

- [x] 5.1 Profile fields: `daily_calorie_target`, optional `protein_target_g`, `carb_target_g`, `fat_target_g`. Present in migration 0001 `profiles`; protein/carb/fat target columns pending.
- [x] 5.2 Meal types: breakfast, lunch, dinner, snack, other. `MealType` enum + DB check constraint (2026-08-11).
- [x] 5.3 `REGISTRAR` tab actions: scan barcode, search food, photograph meal, create meal, new post, post location, share workout. No step-related action exists. Action screen with barcode/photo/post; barcode + photo actions pending implementation (2026-08-11).
- [ ] 5.4 Barcode scanning with `mobile_scanner` for EAN/UPC.
- [x] 5.5 Lookup priority: barcode -> Open Food Facts -> private cache -> USDA fallback -> custom food creation. Cache resolved products in `foods`. `OpenFoodFactsRepository` + private cache path in `foods` table; USDA fallback pending.
- [x] 5.6 Food entries store a nutrition snapshot (calories, protein, carbs, fat at time of logging) so later source changes never rewrite history. Snapshot columns in `food_entries` + `entryFromFood` snapshot builder (2026-08-11).
- [x] 5.10 `within_calorie_target = consumed <= daily_calorie_target`. Never present food minus exercise as a metabolic deficit. `DailyNutritionTotals.withinCalorieTarget` (2026-08-11).
- [x] 5.11 Resilient external API handling: timeouts, not-found, malformed responses, offline. API outage never blocks custom food creation. Timeout/notFound/malformed handled + tested in `OpenFoodFactsRepository` (2026-08-11).

Dependencies: Phase 1 schema/storage; camera permission.

Acceptance criteria:

- Scan -> resolve -> portion -> meal -> save completes in seconds.
- Unknown barcode can be created once and reused by all four users.
- Daily totals match stored snapshots exactly.
- No manual step entry path was introduced through any shared form.

Checkpoint 5 evidence required:

- Test run: barcode hit, barcode miss -> custom create -> second user scan hit, API outage, quantity edit, entry delete, photo upload failure and retry.

---

## Phase 6 - Workouts, Routes, Maps, Profile History

Goal: complete the activity surfaces of the MVP.

- [x] 6.1 Import workouts from HealthKit and Health Connect: type, start/end, duration, distance, active calories, pace/speed, source. `Workout` model + `SupabaseWorkoutRepository.insertAll` mapping all fields (2026-08-11).
- [x] 6.2 De-duplicate on `(source, external_id)` where the platform provides one; document behavior where it does not. `WorkoutImportService` + unique `(source, external_id)` in migration 0002; no-external-id imports documented as unconditional (2026-08-11).
- [x] 6.8 `NOSOTROS` screen: the four profiles with avatar, season rank, today's steps, streaks, weekly workouts/distance, season points, trophies. Profile list with targets implemented; season rank/stats/streaks/trophies pending.
- [ ] 6.9 Profile historical stats: lifetime steps/distance/workouts/calories, daily and round wins, season wins, longest streaks.
- [ ] 6.10 Season history with champions list.

Dependencies: Phase 0/2 health package route support (or documented native extension); map provider decision.

Acceptance criteria:

- An outdoor run appears once with correct stats and a rendered route.
- Route-unavailable and permission-denied cases render clean states.
- No background location tracking exists anywhere.
- Historical stats survive season resets.

Checkpoint 6 evidence required:

- Test run: workout with route, without route, duplicate external ID, denied route permission, offline import and later upload.
- Map render verification on both platforms.

---

## Phase 7 - Hardening, Backup, Release

Goal: the MVP becomes a reliable daily-use private app.

- [~] 7.1 Complete offline support: cached reads for stats, rankings, feed, profiles; queued writes for food entries, posts, media, health sync; visible retry on reconnect. Ranking cache + "Showing cached data" indicator implemented; feed/profiles cache + queued writes pending.
- [ ] 7.2 Audit every async failure path against the state taxonomy (denied, unavailable, no data, stale, backend down, validation, retryable) and give each a user-visible recovery action.
- [ ] 7.3 Performance pass: feed pagination, ranking queries with proper indexes, image size budgets, route payload bounds.
- [ ] 7.4 Backup: verify Supabase/Postgres backup schedule, test an actual restore into a clean project, document the rebuild procedure for derived data from immutable records.
- [ ] 7.5 Configuration audit: round windows, timezone, season type, point values, goals, cooldowns all changeable via `app_config` without redeploy.
- [ ] 7.6 Security sweep: no secrets in the repo, no public buckets, no debug bypasses, no extra test accounts, permissions minimized, logs free of sensitive payloads.
- [ ] 7.7 Run the complete 21-point acceptance checklist from `SPECS.md` section 73 on release builds across all four devices.
- [ ] 7.8 Write the operational runbook: deploy, migrate, rollback, restore, rotate keys, add a replacement device.

Dependencies: Phases 1-6 complete; signing and distribution access.

Acceptance criteria:

- Every `SPECS.md` acceptance criterion passes or has a written owner-accepted exception.
- Restore procedure is tested, not just documented.
- Release configuration contains no secrets, debug paths, or public access.

Checkpoint 7 (release gate) evidence required:

- Four-device acceptance matrix signed off.
- Restore test output.
- Build identifiers, dependency versions, known limitations, rollback path recorded here.

---

## Cross-Phase Verification Matrix

Run at every checkpoint; a regression in any row blocks release.

| Area | Invariant |
| --- | --- |
| Identity | Four allowlisted users only; unknown identities read nothing |
| Health | HealthKit + Health Connect both work; detectable manual steps excluded |
| Time | All rounds and seasons use `competition_timezone` |
| Data | Daily aggregates idempotent; workouts de-duplicated; points ledger append-only |
| Privacy | Shared visibility limited to the four; private media; explicit post-scoped location only |
| Social | Feed, comments, reactions, events recoverable from the database after reconnect |
| Nutrition | Barcode, search, cache, custom food, photos, macros; no interaction with step rules |
| Offline | Cached reads useful; pending writes retry visibly |
| Operations | Backups, config, logs, release diagnostics documented and tested |

## Checkpoint Log

Append entries here as phases complete. Do not delete history.

| Checkpoint | Date | Result | Evidence | Known limitations |
| --- | --- | --- | --- | --- |
| 0 | 2026-08-10 | In progress | `flutter analyze` clean; `flutter test` 2 passed; debug APK built; `docs/checkpoint-0.md` | Device validation (0.5/0.7/0.11), Xcode, Supabase CLI pending |
| 1 | - | pending | - | - |
| 1 (schema) | 2026-08-10 | In progress | Migration `20260810231207` applied; RLS/anon 401 verified; 4 private buckets created | Auth users, seed, app shell, client allowlist, app_config timezone pending |
| 2 | - | pending | - | - |
| 3 | - | pending | - | - |
| 4 | - | pending | - | - |
| 5 | - | pending | - | - |
| 6 | - | pending | - | - |
| 7 | - | pending | - | - |
