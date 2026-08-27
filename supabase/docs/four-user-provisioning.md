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

2. Generate a different strong temporary password for each person and run the provisioning script four times. Never reuse or commit those passwords:

   ```powershell
   $env:SERVICE_ROLE_KEY = "eyJ..."
   node supabase/scripts/provision_user.js "PERSON_1_EMAIL" "UNIQUE_STRONG_PASSWORD_1" "PERSON_1_NAME"
   node supabase/scripts/provision_user.js "PERSON_2_EMAIL" "UNIQUE_STRONG_PASSWORD_2" "PERSON_2_NAME"
   node supabase/scripts/provision_user.js "PERSON_3_EMAIL" "UNIQUE_STRONG_PASSWORD_3" "PERSON_3_NAME"
   node supabase/scripts/provision_user.js "PERSON_4_EMAIL" "UNIQUE_STRONG_PASSWORD_4" "PERSON_4_NAME"
   ```

   The script creates the `auth.users` row (email confirmed, no email verification required), then the matching `profiles` row with the same UUID, `platform=unknown`, `timezone=America/Santiago`, and the default targets.

3. Rotate any credentials that were used by the legacy Flutter quick-login screen. Each user can then sign in with Google; Supabase links that identity to the existing account by email.

4. The user changes their real name and any settings in the `NOSOTROS` tab.

## Verification

- `auth.users` count is exactly four and `profiles` count is exactly four.
- A fifth `profiles` insert raises the cap exception (`public.enforce_four_profile_cap()`).
- Each user signs in with Google and reads `app_config`, all profiles, and shared data.
- Anonymous REST requests to `app_config`, `profiles`, and `daily_activity` return `401`.
- An authenticated user without a `profiles` row reads nothing.
