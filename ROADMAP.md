# Enfermicambio Implementation Roadmap

This roadmap turns `SPECS.md` into an executable delivery sequence for a private fitness competition app for exactly four allowlisted users. The product is not considered complete until the cross-platform health-data path, data trust rules, privacy controls, and core acceptance criteria work on two iPhones and two Android devices.

## Delivery Rules

- Treat the four-user constraint as a product and security invariant, not a future scaling target.
- Prove the highest-risk integration first: automatic step reads on one iPhone and one Android device, manual-entry filtering where detectable, time-window aggregation, and Supabase persistence.
- Keep the database authoritative. Realtime updates may improve responsiveness but must not be the only source of truth.
- Keep health-derived aggregates idempotent. Re-syncing a day must replace or recalculate that day's aggregate rather than append duplicate totals.
- Keep game points server-verified and ledger-backed. A client must not be able to award itself points.
- Use one configurable `competition_timezone` for round boundaries and season cutoffs.
- Do not add public registration, user-created groups, chat, payments, ads, live location tracking, navigation, medical guidance, or enterprise-scale infrastructure.
- At every checkpoint, record test evidence, known limitations, and the next blocking risk before advancing.

## Phase 0 - Cross-Platform Health Spike

**Goal:** Prove the hardest technical dependency before implementing the wider product.

- Create the smallest Flutter app that can run on one supported iPhone and one supported Android device.
- Evaluate the maintained Flutter health abstraction candidates from the specification against:
  - HealthKit support;
  - Health Connect support;
  - interval queries;
  - source metadata;
  - manual-entry filtering;
  - workouts and routes;
  - background refresh behavior.
- Implement permission requests for only the health data types used by the spike.
- Read today's automatic steps on both devices.
- Reject records marked as manual when platform metadata exposes that distinction.
- Use platform aggregation and source de-duplication behavior where possible. Do not blindly sum phone and wearable records.
- Split accepted steps into configurable `morning_steps`, `afternoon_steps`, `night_steps`, and `daily_steps`.
- Upload one idempotent daily aggregate to Supabase using `(user_id, date)` uniqueness.
- Store enough source metadata to debug discrepancies without exposing unnecessary low-level metadata in normal UI.
- Display a visible `last_synced` timestamp.
- Compare app totals with the device health app total for test days that include phone, wearable, and known manual records.

**Dependencies**

- Flutter SDK and mobile build toolchains.
- One iPhone with HealthKit access and one Android device with Health Connect access.
- A Supabase project with authenticated test identities.
- A selected health abstraction package, or a documented native-channel gap.

**Acceptance criteria**

- The same spike build reads automatic steps on one iPhone and one Android device.
- Manual records are excluded when the source exposes a reliable manual-entry marker.
- The aggregate is split using the configured competition timezone and time windows.
- Repeating the same sync does not create duplicate daily rows or inflate totals.
- The app shows a useful sync timestamp and a useful error state for denied permissions or unavailable health services.
- The remaining platform limitations are written down with a decision on whether the selected package is acceptable.

**Risks**

- Health APIs may differ in source metadata, permissions, route access, or background behavior.
- Phone and wearable totals may overlap if the platform query is implemented incorrectly.
- A package may support steps but not the complete workout, nutrition, or route surface needed later.

**Checkpoint 0**

- Attach device logs or screenshots for both platforms.
- Record the selected package and rejected alternatives.
- Record a sample day with expected total, accepted total, excluded records, and discrepancy explanation.
- Do not start the full UI/game/social implementation until this checkpoint passes or the product owner explicitly accepts a documented limitation.

## Phase 1 - Foundation and Private Access

**Goal:** Establish the app shell, schema, authentication, and access boundaries.

- Create the Flutter project with a clear feature-oriented structure.
- Create Supabase migrations for:
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
- Add constraints and indexes from the specification, including:
  - unique `(user_id, date)` for daily activity;
  - workout source/external identifiers where available;
  - route point ordering by `(workout_id, timestamp)`;
  - reaction primary key `(post_id, user_id, emoji)`;
  - unique achievement codes;
  - season result primary key `(season_id, user_id)`.
- Pre-create or allowlist exactly four authenticated accounts.
- Reject authenticated identities without a matching allowlisted profile.
- Implement row-level security so all four users can read shared data while writes remain owner-scoped.
- Protect system-generated posts and point-awarding paths from arbitrary client edits.
- Configure private storage buckets for avatars and media. Use authenticated access or signed URLs.
- Implement the bottom navigation shell with product identifiers `HOY`, `RANKING`, `REGISTRAR`, `JUEGO`, and `NOSOTROS`.
- Add loading, empty, permission, offline, and backend-error states before feature screens depend on them.

**Dependencies**

- Phase 0 health decision.
- Supabase Auth, PostgreSQL, Storage, and migration workflow.
- A documented local configuration mechanism with placeholders only; no secrets in source control.

**Acceptance criteria**

- All four known users can authenticate.
- An unknown authenticated user cannot read app data.
- Each user can update only their own profile and owner-scoped records.
- All four users can read the shared profiles, feed, rankings, and statistics allowed by the specification.
- Private media is not publicly readable.
- The app shell launches on iOS and Android with explicit states for loading, empty data, offline, and denied permissions.

**Risks**

- Incorrect RLS policies can expose health, nutrition, location, or private media.
- Schema decisions made before the health spike may force duplicate or non-idempotent storage.
- Auth providers may require platform-specific setup that cannot be validated in a simulator.

**Checkpoint 1**

- Apply migrations to a clean Supabase environment.
- Run an RLS matrix test for each table: owner read/write, peer read, peer write, unknown user access.
- Verify that storage URLs cannot be fetched without authorized access.
- Verify the same app shell works on one iOS and one Android test device.

## Phase 2 - Health Sync, Daily Activity, and Rankings

**Goal:** Deliver trustworthy automatic activity data and the four daily competitions.

- Generalize the Phase 0 sync into a reusable health integration service.
- Request only the permissions used by the current build.
- Sync when the app opens, returns to foreground, is manually refreshed, and when background refresh is available.
- Keep background behavior best-effort; never promise second-by-second synchronization.
- Import steps, active calories, distance, and exercise minutes where available.
- Preserve source metadata for troubleshooting and show freshness in the UI.
- Implement configurable competition windows:
  - morning: default 06:00-12:00;
  - afternoon: default 12:00-18:00;
  - night: default 18:00-24:00;
  - total: default 00:00-24:00.
- Use `competition_timezone` for all date and window calculations.
- Recalculate daily aggregates idempotently from accepted source data.
- Build the Today ranking and the Ranking views for:
  - today;
  - week;
  - season;
  - steps;
  - rounds;
  - distance;
  - workouts;
  - calories;
  - nutrition;
  - game points.
- Include all four users in ranking output, including users with zero or stale data.
- Make stale, missing, denied, and unavailable health data distinguishable.

**Dependencies**

- Passed Phase 0 and Phase 1 checkpoints.
- Selected health package and platform permission configuration.
- App configuration for timezone, windows, and default goals.

**Acceptance criteria**

- Two iPhones and two Android phones can connect to their respective health sources.
- No UI permits manual step entry.
- Detectable manual step samples are excluded.
- Daily data is segmented correctly at configured boundaries.
- Repeated syncs do not inflate totals.
- Rankings show all four users and include freshness information.
- A test day closely matches the platform's displayed automatic total after known manual records are excluded.

**Risks**

- Different HealthKit and Health Connect sources can produce different totals.
- Background refresh is OS-controlled and may be delayed.
- Date boundaries can be wrong if device timezone is used instead of the shared competition timezone.

**Checkpoint 2**

- Run a four-device test matrix with phone-only, wearable-connected, manual-entry, no-data, permission-denied, and stale-sync cases.
- Store expected versus accepted totals and investigate every material discrepancy.
- Freeze the aggregate contract before the game engine depends on it.

## Phase 3 - Competition, Points, Missions, Streaks, and Seasons

**Goal:** Make one full competition day run without manual administrative intervention.

- Add server-side round-closing jobs for morning, afternoon, night, and daily total.
- Record each round winner once and make job retries idempotent.
- Implement configurable points for daily rank, round wins, step goals, workouts, calorie targets, and missions.
- Write every awarded point to the immutable `season_points` ledger with reason and reference.
- Derive standings from the ledger rather than mutable client totals.
- Implement the monthly season lifecycle:
  - load active season;
  - stop awarding points to an ended season;
  - freeze final standings;
  - write `season_results`;
  - award the season trophy;
  - publish the season result event;
  - create the next season with zero points.
- Implement streaks with `current_count`, `longest_count`, and `last_qualified_date`.
- Implement a generic achievement rule model using metric, operator, threshold, time window, repeatability, hidden status, and points.
- Seed the initial achievement and mission packs from the specification.
- Support individual, competitive, and cooperative mission progress.
- Keep improvement ranking optional and clearly separate from raw step ranking.
- Add the `JUEGO` screen for current season, standings, missions, streaks, achievements, trophies, and history.

**Dependencies**

- Phase 2 daily activity and ranking contracts.
- Reliable server scheduling or equivalent Supabase Edge Function execution.
- Backend configuration for point values and lifecycle times.

**Acceptance criteria**

- One simulated or real full competition day closes each round once.
- Retries do not duplicate winners, achievements, mission completion, or points.
- A season can close and produce one champion plus four final result rows.
- A user cannot create or edit season points from the client.
- Streaks and non-repeatable achievements are stable across repeated evaluation.

**Risks**

- Scheduled jobs may run late or retry after partial completion.
- Mutable score totals can drift if the ledger is bypassed.
- Generic mission rules may become too flexible to test or too coupled to UI.

**Checkpoint 3**

- Run a time-controlled end-to-end day across all four users.
- Force retries and duplicate event delivery.
- Reconcile displayed standings with the immutable point ledger.
- Verify old-season points stop at the configured cutoff and historical results remain readable.

## Phase 4 - Private Social Feed and Notifications

**Goal:** Let the four users follow the day through a shared, low-noise timeline.

- Build the feed from manual posts and automatic activity events.
- Support text, photos, meals, workouts, routes, achievements, steps, ranking changes, round results, missions, and seasons.
- Add private media upload with client-side compression, orientation preservation, thumbnails, and visible retry states.
- Add captions, optional explicit post location, and references to meals, workouts, and achievements.
- Add the initial reaction set with one reaction per emoji per user per post.
- Add flat comments with author, timestamp, and delete-own behavior.
- Use Supabase Realtime for new posts, comments, reactions, ranking updates, mission completion, and achievement events.
- Keep database reads authoritative and recover cleanly after reconnects.
- Add rate limits or cooldowns for leader-change events to avoid feed spam.
- Add notification preferences for overtakes, round endings, achievements, workouts, comments/reactions, missions, and season results.
- Keep all user-facing copy playful and social, never medical or shame-oriented.

**Dependencies**

- Phase 1 private media and RLS.
- Phase 3 event and lifecycle rules.
- Push notification setup for APNs/FCM if notifications are included in the current release.

**Acceptance criteria**

- All four users can see a shared feed without public discovery.
- A user can create and delete their own manual post, but cannot edit protected system posts.
- Photos upload in compressed form and failed uploads can be retried.
- Comments and reactions obey ownership and uniqueness rules.
- Automatic step, workout, achievement, mission, round, and season events appear without excessive duplicates.
- Realtime reconnects do not lose the database-backed event.

**Risks**

- Realtime-only UI can diverge after reconnects or missed events.
- Unbounded media sizes can create storage and performance problems.
- Automatic event volume can make the feed noisy and reduce its motivational value.

**Checkpoint 4**

- Test feed creation and recovery on offline/online transitions.
- Verify RLS and storage access with all four accounts.
- Review an entire sample day for event duplication, ordering, and tone.

## Phase 5 - Nutrition and Barcode Food Logging

**Goal:** Make nutrition logging fast while preserving the distinction between food entry and health-derived steps.

- Add calorie target and optional macro targets to profiles.
- Implement meal types: breakfast, lunch, dinner, snack, and other.
- Implement food search in this priority order:
  - barcode scan;
  - Open Food Facts;
  - USDA FoodData Central fallback;
  - private/group cache;
  - custom food.
- Use `mobile_scanner` or the selected maintained barcode library for EAN/UPC scanning.
- Store nutrition snapshots on food entries so later source changes do not rewrite historical meals.
- Allow manual food entry. Do not reuse this path for steps.
- Add private food cache records for missing products so the next user can resolve the barcode immediately.
- Add meal photos and optional publication to the feed.
- Calculate consumed calories, remaining configured target, macros, meal count, and `within_calorie_target`.
- Do not present consumed calories minus exercise calories as a metabolic deficit unless a separate validated model is introduced.
- Add the meal summary screen and useful error states for not-found products, API failures, and upload failures.

**Dependencies**

- Phase 1 schema, storage, and private access.
- Camera permissions.
- Open Food Facts and USDA integration decisions.
- No paid API dependency unless coverage testing proves it necessary.

**Acceptance criteria**

- A packaged food can be scanned, resolved, portioned, assigned to a meal, and saved.
- Missing products can be created once and reused by all four users.
- Search and custom food entries calculate calories and macros.
- Meal photos are private by default and publish only through explicit user action.
- Daily nutrition totals match the saved food-entry snapshots.

**Risks**

- Public food data may have missing, inconsistent, or unit-dependent nutrition values.
- API outages must not prevent custom food creation.
- Nutrition estimates from photos can be misleading if presented as facts.

**Checkpoint 5**

- Test barcode hit, barcode miss, API outage, custom food, quantity changes, meal edit/delete, and photo upload failure.
- Verify the app labels any future photo-based nutrition estimation as approximate and adjustable.
- Confirm no step-entry control has been introduced through shared form components.

## Phase 6 - Workouts, Routes, Maps, and Profile History

**Goal:** Complete the activity and history surfaces defined for the MVP.

- Import workouts from HealthKit and Health Connect where available.
- De-duplicate using source and external workout identifiers when available.
- Store workout type, times, duration, distance, calories, pace/speed, source, and route availability.
- Import route points when available and store only fields supplied by the platform.
- Render a route map in workout detail and a compact map preview in the feed.
- Use `flutter_map` with OpenStreetMap tiles or MapLibre after licensing, maintenance, and platform behavior review.
- Do not implement navigation or live location tracking.
- Make location sharing explicit and post-scoped only.
- Add workout sharing cards and the `Publish to feed` action.
- Complete `NOSOTROS` profiles with current stats, season rank, streaks, trophies, and historical totals.
- Add season history and champion records.

**Dependencies**

- Phase 0 health package supports workouts and route access, or approved platform-specific extensions.
- Location permission only for explicit route/post features.
- Map provider and tile policy decision.

**Acceptance criteria**

- An imported run or workout appears once with correct core stats.
- A route is rendered when route data exists and the screen handles route-unavailable cases.
- A workout can be shared without exposing live location.
- Profile and season-history data remain available after a season reset.

**Risks**

- Route permissions and route availability vary by platform and workout source.
- Map tiles can create network, licensing, or quota constraints.
- Raw route points can be large and should not be fetched unnecessarily.

**Checkpoint 6**

- Test a workout with route, without route, duplicate source ID, denied route permission, and offline upload.
- Verify map rendering on both platforms and bounded route queries.
- Confirm no background location tracking is present.

## Phase 7 - Hardening, Backup, and Release Readiness

**Goal:** Turn the MVP into a reliable private daily-use app.

- Complete offline caching for latest stats, rankings, feed, profiles, and pending food/posts.
- Add retry and conflict behavior for health upserts, media uploads, and optimistic feed changes.
- Add explicit stale-sync, no-data, permission-denied, API-unavailable, and backend-offline states.
- Add performance checks for feed pagination, ranking queries, image sizes, and route payloads.
- Add scheduled backup verification and document data ownership/recovery procedures.
- Verify configuration can change competition windows, timezone, season type, point values, default goals, and event cooldowns without an app redeploy where intended.
- Run the complete core acceptance checklist from `SPECS.md`.
- Verify release builds on two iPhones and two Android phones.
- Document remaining platform limitations and future ideas separately from MVP commitments.

**Dependencies**

- Phases 1-6 complete.
- Release signing and mobile store/test-distribution access.
- Backup access for Supabase/Postgres and storage.

**Acceptance criteria**

- The core app acceptance criteria in the specification all pass or have an explicitly accepted exception.
- A temporary backend outage does not destroy pending user input.
- Backups and restore/rebuild procedures are tested, not merely documented.
- No secrets, public private-media buckets, debug bypasses, or unrestricted test accounts remain in release configuration.
- A new developer can follow `README.md` and `CODESTYLE.md` to build, test, and diagnose the project.

**Risks**

- OS updates can change health permissions or background behavior.
- Backup procedures may exist on paper but fail during an actual restore.
- A polish pass can accidentally broaden scope or weaken privacy.

**Checkpoint 7 - Release Gate**

- Product owner signs off on the four-device acceptance matrix.
- Engineering signs off on tests, migrations, RLS, storage, backups, and release configuration.
- Record the build identifier, selected dependency versions, known limitations, and rollback/recovery path.
- Only then label the build as the finished MVP.

## Cross-Phase Verification Matrix

- **Identity:** four allowlisted users can log in; unknown users cannot read data.
- **Health:** iOS HealthKit and Android Health Connect both work; manual steps are excluded where detectable.
- **Time:** all daily rounds and seasons use `competition_timezone`.
- **Data:** daily aggregates are idempotent; workouts are de-duplicated; points use an immutable ledger.
- **Privacy:** shared visibility is limited to the four users; media is private; location is explicit and post-scoped.
- **Social:** posts, comments, reactions, and automatic events are recoverable from the database.
- **Nutrition:** barcode, search, cache, custom food, meal photos, and macro totals work without affecting step rules.
- **Offline:** cached reads remain useful; pending writes retry visibly.
- **Operations:** backups, configuration, logs, and release diagnostics are documented.
