// Provision a single allowlisted user (auth + profile) via the Supabase admin API.
//
// Usage:
//   $env:SERVICE_ROLE_KEY = "eyJ..."    # Settings -> API -> service_role (never committed)
//   node provision_user.js udefret12@gmail.com "TemporaryPassword123!" "Diego"
//
// The account is created with email+password so it can sign in today; Google
// sign-in is later linked to the same email by the provider, preserving the
// four-user allowlist.

const https = require('https');

const ref = 'bweynxdzovnbcjwgddar';
const serviceRoleKey = process.env.SERVICE_ROLE_KEY;
const [email, password, displayName] = process.argv.slice(2);

if (!serviceRoleKey || !email || !password || !displayName) {
  console.error(
    'Usage: node provision_user.js <email> <password> <displayName> with SERVICE_ROLE_KEY set',
  );
  process.exit(1);
}

function request(path, method, body) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const req = https.request(
      {
        hostname: `${ref}.supabase.co`,
        path,
        method,
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
          ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          let parsed = null;
          try {
            parsed = JSON.parse(data);
          } catch (_) {
            parsed = data;
          }
          resolve({ status: res.statusCode, body: parsed });
        });
      },
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function main() {
  const existing = await request(
    `/auth/v1/admin/users?select=id,email&email=${encodeURIComponent(email)}`,
    'GET',
    null,
  );
  let userId;

  if (existing.status === 200 && Array.isArray(existing.body) && existing.body.length > 0) {
    userId = existing.body[0].id;
    console.log(`Auth user already exists: ${userId}`);
  } else {
    const created = await request('/auth/v1/admin/users', 'POST', {
      email,
      password,
      email_confirm: true,
    });
    if (created.status !== 201 && created.status !== 200) {
      console.error('Failed to create auth user:', created.status, JSON.stringify(created.body));
      process.exit(1);
    }
    userId = created.body.id;
    console.log(`Created auth user: ${userId}`);
  }

  const profile = await request(
    `/rest/v1/profiles?id=eq.${userId}&select=id`,
    'GET',
    null,
  );
  if (profile.status === 200 && Array.isArray(profile.body) && profile.body.length > 0) {
    console.log('Profile already exists; nothing to do.');
  } else {
    const inserted = await request('/rest/v1/profiles', 'POST', {
      id: userId,
      display_name: displayName,
      platform: 'unknown',
      timezone: 'America/Santiago',
      daily_calorie_target: 2200,
      daily_step_target: 10000,
      weekly_workout_target: 3,
    });
    if (inserted.status !== 201 && inserted.status !== 200) {
      console.error('Failed to create profile:', inserted.status, JSON.stringify(inserted.body));
      process.exit(1);
    }
    console.log(`Created profile for ${email}`);
  }

  console.log('Done.');
}

main().catch((err) => {
  console.error('FAILED:', err.message);
  process.exit(1);
});
