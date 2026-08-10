# Checkpoint 0 - Cross-Platform Health Spike

Date: 2026-08-10
Status: IN PROGRESS - code foundation verified locally; device evidence pending.

## Scope completed

- 0.2 Minimal Flutter app with one spike screen (`lib/features/health/presentation/health_spike_screen.dart`): connect, sync, today's totals per window, `last_synced`, visible states.
- 0.4 Permission request limited to step read on both platforms (`HealthPluginRepository.requestStepReadPermission`).
- 0.6 Manual-entry filtering implemented and unit tested (`ActivitySegmenter` + `HealthStepSample.isManual`).
- 0.8 Window segmentation in `competition_timezone` (06:00-12:00, 12:00-18:00, 18:00-24:00), boundaries read from `AppConfig`, with the daily total covering 00:00-24:00.
- 0.9 `daily_activity` table in `supabase/migrations/0001_phase0_foundation.sql` with `unique(user_id, activity_date)`; idempotent upsert implemented in `SupabaseDailyActivitySink`.
- 0.10 Diagnostic source metadata columns (`source_platform`, `source_app`, `source_device`, `recording_method`, `manual_entry_detected`, `source_metadata`) present in the migration and populated by the sync pipeline.
- 0.12 Visible states: syncing, success with `last_synced`, permission denied, health source unavailable, no data.

## Local verification (run 2026-08-10)

- `flutter analyze`: No issues found.
- `flutter test`: 2 tests passed (`test/activity_segmenter_test.dart`).
  - Segments records at competition window boundaries.
  - Excludes manual records and reports the count.
- `flutter build apk --debug`: built successfully (`build\app\outputs\flutter-apk\app-debug.apk`).
  - `minSdk = 26` set for the `health` plugin requirement.

## Remote verification (run 2026-08-10)

- Migration `0001_phase0_foundation.sql` applied to the remote Supabase project (`bweynxdzovnbcjwgddar`, region `us-east-2`) and recorded as `20260810000001` in `supabase_migrations.schema_migrations`.
- `supabase migration list`: local and remote in sync; `db push --dry-run` reports "up to date".
- Tables created: `app_config`, `profiles`, `daily_activity`. `app_config` seeded with the Phase 0 defaults (windows, timezone provisional UTC, point values, goals, cooldown).
- Anonymous REST requests to `app_config`, `profiles`, `daily_activity` return `401`, confirming RLS blocks unauthenticated access as designed.

## Environment status

- Flutter 3.44.9 stable, Dart 3.12.2, Android SDK 36.1.0 present.
- `cmdline-tools` component missing; Android license status unknown (affects `flutter doctor` only, not the debug APK build).
- Xcode unavailable (Windows host): iOS build and HealthKit validation are blocked locally.
- Supabase CLI not installed: migration 0001 has not been applied to a live or local Postgres.
- No physical iPhone or Android phone connected: items 0.5, 0.7 (real aggregation), and 0.11 remain unverified.

## Pending device evidence

- 0.5 Read today's steps on one physical iPhone and one physical Android phone.
- 0.7 Platform aggregation strategy validated against phone + wearable overlap on real devices.
- 0.11 Validation day table: platform total vs accepted total vs excluded manual records per device.

## Package decision (0.3, provisional)

- Selected: `health` plugin (^13.3.1) for the spike.
- Rationale: single abstraction covering HealthKit and Health Connect, per-record source metadata and `recordingMethod` exposure, windows/interval queries.
- Rejected for now: CARP Health, ConnectKit. Recorded as provisional until device evidence from 0.5/0.7 is available.

## Known limitations

- Aggregation currently sums sample records with proportional overlap handling; real-device validation of platform aggregation (no double counting of phone + wearable overlap) is outstanding.
- `app_config.competition_timezone` is seeded as `UTC` (provisional); set the group timezone before real competitions.
- No Supabase project provisioned: upsert persistence is code-tested but not integration-tested against Postgres.
