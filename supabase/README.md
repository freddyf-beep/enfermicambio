# Supabase Backend

This directory contains the database foundation for the four-user private fitness competition app described in `SPECS.md`.

## Migration 0001

`migrations/0001_phase0_foundation.sql` creates the Phase 0 backend surface:

- `profiles`: authenticated app profiles and the four-user allowlist source;
- `daily_activity`: idempotent daily automatic-activity aggregates;
- `app_config`: shared competition timezone, round windows, goals, cooldowns, and point values;
- diagnostic health-source metadata on `daily_activity`;
- indexes for date/ranking, user history, sync freshness, display names, and JSON diagnostics;
- `public.is_allowlisted_user()`: a security-definer helper for authenticated RLS checks;
- a database trigger that prevents more than four profile rows;
- RLS policies and grants for allowlisted reads and owner-scoped writes.

The migration does not seed real users. Provision exactly four `auth.users` identities, then insert the matching four `profiles` rows with the service role or another trusted administrative path. The `profiles.id` value must equal the corresponding `auth.users.id`.

## Configuration

The migration seeds deterministic defaults:

- `competition_timezone`: `UTC` as a provisional value;
- morning: `06:00`-`12:00`;
- afternoon: `12:00`-`18:00`;
- night: `18:00`-`24:00`;
- monthly seasons;
- default step goal of `10000`;
- initial point values from the specification.

Before real competition data is collected, set `competition_timezone` to the single timezone shared by the group. Configuration writes are intentionally not granted to the `authenticated` role. Use a trusted server-side/admin process for changes.

`config_value` is JSONB so the client can read strings, numbers, and point maps without a schema migration for every balance adjustment. Application code must validate the expected JSON type and range before using a value.

## Daily Activity Contract

`daily_activity` is unique on `(user_id, activity_date)`. Health synchronization must use an upsert/recalculation flow so repeating a sync replaces the same daily aggregate instead of appending a duplicate.

The required activity fields are:

- `morning_steps`;
- `afternoon_steps`;
- `night_steps`;
- `daily_steps`;
- `active_calories`;
- `distance_meters`;
- `exercise_minutes`;
- `synced_at`.

`daily_steps` is the full competition-day total. The three round columns begin at `06:00`, so they do not necessarily sum to the full-day value when activity occurs between `00:00` and `06:00`.

Diagnostic fields preserve the source context needed to investigate platform discrepancies:

- `source_platform`;
- `source_app`;
- `source_device`;
- `recording_method`;
- `manual_entry_detected`;
- `source_metadata`.

The diagnostic flag does not make a manual record valid. The health integration must reject detectable manual records before calculating the aggregate. `source_metadata` must contain only the minimum troubleshooting data and must never contain raw health samples, access tokens, or unnecessary personal identifiers.

## Allowlist and RLS Assumptions

- Supabase Auth is the identity source.
- `profiles.id` is the authenticated user's UUID.
- The profile trigger enforces a maximum of four rows, including concurrent provisioning attempts.
- `is_allowlisted_user()` returns false for anonymous requests, unknown identities, and any invalid state with more than four profile rows.
- There is no authenticated insert or delete policy for `profiles`; profile provisioning and removal are administrative operations.
- Allowlisted users can read all profiles, config, and daily activity because the product is intentionally transparent within the four-person group.
- Users can update only their own profile and insert/update only their own daily activity.
- Users cannot delete daily activity through the client in this migration. Corrections should come from a trusted sync/reconciliation path.
- `app_config` is readable by allowlisted users but writable only by a trusted administrative/server-side role.
- RLS protects authorization boundaries, but it cannot prove that a client-reported health aggregate is genuine. Phase 0 still requires device testing, source metadata, manual-entry filtering, platform aggregation/de-duplication, and later server validation where practical.
- The security-definer allowlist helper relies on the table owner being able to read `public.profiles` without being blocked by that table's RLS policy. Do not add `FORCE ROW LEVEL SECURITY` to `public.profiles` without replacing the helper with an equivalent private-schema implementation.

## Validation Checklist

After applying the migration:

1. Confirm the migration applies cleanly to a fresh Supabase database.
2. Provision exactly four Auth users and matching profile rows through an administrative path.
3. Confirm a fifth profile insert fails.
4. Confirm an anonymous request cannot read config, profiles, or daily activity.
5. Confirm each allowlisted user can read all four profiles and daily activity rows.
6. Confirm a user cannot insert or update another user's daily activity.
7. Confirm a user cannot update another user's profile.
8. Confirm repeated daily activity upserts target `(user_id, activity_date)`.
9. Confirm config changes are rejected for the `authenticated` role.
10. Confirm diagnostic metadata does not appear in normal user-facing copy unless explicitly needed for troubleshooting.

## Local Commands

Use the repository's configured Supabase CLI workflow once the project is initialized:

```powershell
supabase start
supabase db reset
supabase db lint
```

Do not place project URLs, service-role keys, access tokens, or user credentials in this directory or in source control.
