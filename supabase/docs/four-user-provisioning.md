# Four-User Provisioning

The app allowlist is exactly four `auth.users` + four `profiles` rows. This document describes the provisioning procedure. Credentials and access tokens are never committed to the repository.

## Auth model

Supabase Auth with Google sign-in as the primary identity provider. There is no public registration. Exactly four allowlisted users exist; anyone else is rejected at the RLS layer (`is_allowlisted_user()`).

Provisioning is manual and uses the service role key. When a user signs in with Google for the first time, Supabase links the Google identity to the existing `auth.users` row by email. No extra `profiles` row is created automatically.

## Prerequisites

- A linked Supabase project (`supabase link --project-ref bweynxdzovnbcjwgddar`).
- Google OAuth credentials configured in Supabase Auth -> Providers -> Google (client ID + secret from Google Cloud Console).
- The service role key for the project (Settings -> API -> service_role), kept out of source control.

## Procedure

1. Collect the four email addresses. Decide each user's `display_name`.

2. Run the provisioning script for each of the 4 friends (using default password '123456' for fast initial setup):

   ```powershell
   $env:SERVICE_ROLE_KEY = "eyJ..."
   node supabase/scripts/provision_user.js "udefret12@gmail.com" "123456" "Freddy"
   node supabase/scripts/provision_user.js "felipe@gmail.com" "123456" "Felipe"
   node supabase/scripts/provision_user.js "cristiancarrillo262@gmail.com" "123456" "Cristian"
   node supabase/scripts/provision_user.js "Samineiror123@gmail.com" "123456" "Samir"
   ```

   The script creates the `auth.users` row (email confirmed, no email verification required), then the matching `profiles` row with the same UUID, `platform=unknown`, `timezone=America/Santiago`, and the default targets.

3. After provisioning, each user signs in with Google. Supabase links the Google identity to the existing account by email.

4. The user changes their real name and any settings in the `NOSOTROS` tab.

## Verification

- `auth.users` count is exactly four and `profiles` count is exactly four.
- A fifth `profiles` insert raises the cap exception (`public.enforce_four_profile_cap()`).
- Each user signs in with Google and reads `app_config`, all profiles, and shared data.
- Anonymous REST requests to `app_config`, `profiles`, and `daily_activity` return `401`.
- An authenticated user without a `profiles` row reads nothing.
