# Four-User Provisioning

The app allowlist is exactly four `auth.users` + four `profiles` rows. This document describes the provisioning procedure. Credentials and access tokens are never committed to the repository.

## Prerequisites

- A linked Supabase project (`supabase link --project-ref <ref>`).
- A Supabase access token (`SUPABASE_ACCESS_TOKEN`) for the admin API.
- The service role key for the project (Settings -> API -> service_role, kept out of source control).

## Procedure

1. Collect the four email addresses and temporary passwords. Use real, owned addresses so users can sign in.

2. Create the four auth users through the admin API:

   ```powershell
   $anon = "YOUR_ANON_KEY"
   $body = @{ email = "person1@example.com"; password = "temporary-password" } | ConvertTo-Json
   Invoke-RestMethod -Uri "https://<ref>.supabase.co/auth/v1/admin/users" `
     -Method Post -Headers @{ apikey = $anon; Authorization = "Bearer $SERVICE_ROLE_KEY"; "Content-Type" = "application/json" } `
     -Body $body
   ```

3. The response returns each user's `id` UUID. Insert the matching four `profiles` rows with the service role via the PostgREST admin path, or with a trusted SQL connection:

   ```sql
   insert into public.profiles (id, display_name, platform, timezone, daily_calorie_target, daily_step_target)
   values
     ('<user-uuid-1>', 'Diego', 'unknown', 'America/Santiago', 2200, 10000),
     ('<user-uuid-2>', 'Nico', 'unknown', 'America/Santiago', 2200, 10000),
     ('<user-uuid-3>', 'Pedro', 'unknown', 'America/Santiago', 2200, 10000),
     ('<user-uuid-4>', 'Juan', 'unknown', 'America/Santiago', 2200, 10000);
   ```

   The `profiles.id` must equal the corresponding `auth.users.id`. The four-user cap trigger rejects a fifth row.

4. Reset each temporary password or have each user set their own via the app's password flow.

## Verification

- `auth.users` count is exactly four and `profiles` count is exactly four.
- A fifth `profiles` insert raises the cap exception.
- Each user can sign in and read `app_config`, all profiles, and shared data.
- Anonymous REST requests to `app_config`, `profiles`, and `daily_activity` return `401`.
