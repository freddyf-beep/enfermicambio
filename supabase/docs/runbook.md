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
