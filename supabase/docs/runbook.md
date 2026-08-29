# Operational Runbook

Procedures for operating the Enfermicambio Supabase backend and releases. Apply with care; most steps touch the live database.

## Conventions

- Migrations are forward-only. Never edit an applied migration; corrections are new migrations.
- All destructive operations run inside a transaction or against a copy first.
- Secrets (service role key, DB password, access tokens) live in the local `.env`, never in source control.

## Deploy (migrations)

```powershell
# From the repository root, after pulling latest master:
supabase link --project-ref bweynxdzovnbcjwgddar
supabase db push
```

Verify the remote history matches local:

```powershell
supabase migration list
```

## Migrate (new change)

1. Create the migration file with the CLI so the timestamp format is correct:

   ```powershell
   supabase migration new <snake_case_name>
   ```

2. Write the SQL (forward-only), then apply:

   ```powershell
   supabase db push
   ```

3. Record the result in `ROADMAP.md` checkpoint log and commit.

For the gamification daily-close fix specifically:

1. Apply `supabase/migrations/20260827100001_fix_evaluate_missions_ambiguity.sql`
   (via `db push` with a correct history, or the SQL editor).
2. Run `supabase/scripts/mission_close_day_smoke_test.sql` against the remote
   database and confirm it prints `evaluate_missions OK` plus the streak counts.
3. Invoke the `close_day` Edge Function once for today (or wait for the 00:10
   cron) so streaks/achievements recompute from real activity:

   ```powershell
   $body = @{ date = (Get-Date -Format 'yyyy-MM-dd') } | ConvertTo-Json
   Invoke-RestMethod -Uri 'https://bweynxdzovnbcjwgddar.supabase.co/functions/v1/close_day' `
     -Method Post -Headers @{ apikey = 'sb_publishable_JS-Th9Up9BBHjI51WD4Reg_V57pz8BO' } `
     -Body $body
   ```

4. Open the PWA at `#/game` and confirm Rachas and Logros show non-zero state
   for users with qualifying activity.

## Rollback

There is no automated rollback for forward-only migrations. Recovery paths:

- If the migration is not yet pushed, delete the local migration file and re-run `supabase db push`.
- If the migration was pushed and broke the schema, write a corrective migration (e.g., `revert_x`) that reverses only the harmful changes, then `supabase db push`.
- For data damage, restore from backup (below) or replay immutable records.

## Restore from backup

Supabase hosts automatic backups (daily, with PITR on paid plans). To restore:

1. In the Supabase dashboard: Database -> Backups.
2. Choose the restore point and confirm. Restore is to the same project (overwrites) or a new project.
3. After restore, verify: `supabase migration list` shows the same history; a sample query returns expected rows.

Backup/restore must be tested before release. Document the actual test output in `ROADMAP.md` Phase 7.4.

## Rotate keys

- Service role key: Supabase dashboard -> Settings -> API -> regenerate `service_role`. Update the local `.env` and any CI secrets.
- Google OAuth client secret: Google Cloud Console -> Credentials -> regenerate the secret, then update Supabase Auth -> Providers -> Google.
- DB password: dashboard -> Settings -> Database -> reset password. Update local `.env` / pooler connection strings.

After rotating any key, verify a full sign-in round trip and one upsert.

## Add a replacement device

A user switches phones:

1. Install the app and sign in with the same Google account (or email).
2. Grant health permissions on the new device.
3. The first sync upserts `daily_activity` for the current day. Historical data re-syncs on subsequent reads if the platform retains it; earlier days are not backfilled automatically.
4. Confirm the profile still shows the same `display_name` and targets.

## Environment layout

- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `COMPETITION_TZ`: local `.env` (git-ignored), placeholders only in `.env.example`.
- `SERVICE_ROLE_KEY`: local shell variable for `supabase/scripts/provision_user.js`; CI secret where needed.
- Game tuning: `app_config` table (service-role write); no redeploy required.

## Release

### Android

The CI workflow `ci.yml` builds a debug APK on every push; download it from the Actions run's artifacts. For a distributable release, a signed release APK/AAB requires a keystore:

1. Generate a keystore (once) and store it as a GitHub secret (`ANDROID_KEYSTORE`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`).
2. Reference it in `android/app/build.gradle.kts` via the secrets.
3. Extend `ci.yml` to run `flutter build apk --release` and upload the artifact.

### iOS (sideload, free Apple ID)

The `build-ipa.yml` workflow builds an unsigned IPA for sideloading with Sideloadly/AltStore. The build is valid for 7 days under a free Apple ID.

1. From the Actions run, download the `enfermicambio-ipa` artifact.
2. Unzip and open `Enfermicambio.ipa` in Sideloadly.
3. Enter the free Apple ID and an app-specific password; install to the registered iPhone.
4. Reinstall (same process) when the 7-day certificate expires.

### Release checklist (Phase 7.7)

Run against release builds on the target devices:

1. All four known users authenticate; unknown users read nothing.
2. No manual step entry UI exists anywhere.
3. Automatic steps read on HealthKit and Health Connect.
4. Daily steps split into morning/afternoon/night; repeated syncs never inflate totals.
5. Rankings show all four users with last-sync freshness.
6. Workouts sync automatically where available; outdoor routes render on the map.
7. Food logging works (scan/search/custom), daily calories and macros correct.
8. Posts, photos, comments, and reactions publish and appear in the shared feed.
9. Automatic feed events appear without spam.
10. Streaks, achievements, and missions are calculated.
11. Season points are awarded without duplicates; season close crowns a champion.
12. Offline: cached reads useful; queued writes replay on reconnect.
13. No public buckets; private media is not fetchable without auth.
14. Backup restore was tested into a clean project.

### Backup verification

- Confirm the Supabase automatic backup schedule in the dashboard (Database -> Backups).
- On a paid plan, enable PITR before release.
- Test an actual restore into a fresh project and confirm `supabase migration list` and a sample query.

### Rollback

- Migrations are forward-only; corrective changes are new migrations.
- Data damage recovery: restore from backup, then replay immutable records (ledger entries are append-only and safe to recompute for open seasons).
- App: reinstall a previous artifact (GitHub Actions retains artifacts for 30 days by default).
