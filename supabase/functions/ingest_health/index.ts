import { createClient } from '@supabase/supabase-js'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, 'Content-Type': 'application/json' },
})

async function sha256(value: string) {
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))
  return [...new Uint8Array(bytes)].map(x => x.toString(16).padStart(2, '0')).join('')
}

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  const token = request.headers.get('Authorization')?.replace(/^Bearer\s+/i, '').trim()
  if (!token || token.length < 32) return json({ error: 'Invalid token' }, 401)

  const client = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  )
  const hash = await sha256(token)
  const { data: tokenRow } = await client.from('health_ingest_tokens')
    .select('user_id').eq('token_hash', hash).maybeSingle()
  if (!tokenRow) return json({ error: 'Invalid token' }, 401)

  let payload: Record<string, unknown>
  try { payload = await request.json() } catch { return json({ error: 'Invalid JSON' }, 400) }
  const platform = payload.source_platform
  if (platform !== 'ios' && platform !== 'android') return json({ error: 'source_platform must be ios or android' }, 400)
  const activityDate = String(payload.activity_date || '')
  if (!/^\d{4}-\d{2}-\d{2}$/.test(activityDate)) return json({ error: 'activity_date must use YYYY-MM-DD' }, 400)
  const number = (key: string) => Math.max(0, Number(payload[key]) || 0)

  const { error: activityError } = await client.from('daily_activity').upsert({
    user_id: tokenRow.user_id,
    activity_date: activityDate,
    morning_steps: Math.round(number('morning_steps')),
    afternoon_steps: Math.round(number('afternoon_steps')),
    night_steps: Math.round(number('night_steps')),
    daily_steps: Math.round(number('daily_steps')),
    active_calories: number('active_calories'),
    distance_meters: number('distance_meters'),
    exercise_minutes: number('exercise_minutes'),
    synced_at: new Date().toISOString(),
    source_platform: platform,
    source_app: String(payload.source_app || 'health-export'),
    source_device: payload.source_device ? String(payload.source_device) : null,
    recording_method: 'automatic_export',
    manual_entry_detected: Boolean(payload.manual_entry_detected),
    source_metadata: { exporter: payload.source_app || 'unknown', pwa_ingest: true },
  }, { onConflict: 'user_id,activity_date' })
  if (activityError) return json({ error: activityError.message }, 422)

  const workouts = Array.isArray(payload.workouts) ? payload.workouts : []
  if (workouts.length) {
    const rows = workouts.slice(0, 100).map((workout: Record<string, unknown>) => ({
      user_id: tokenRow.user_id,
      external_id: workout.external_id ? String(workout.external_id) : null,
      source: String(workout.source || payload.source_app || 'health-export'),
      workout_type: String(workout.workout_type || 'workout'),
      started_at: String(workout.started_at), ended_at: String(workout.ended_at),
      duration_seconds: Math.max(1, Math.round(Number(workout.duration_seconds) || 1)),
      distance_meters: workout.distance_meters == null ? null : Math.max(0, Number(workout.distance_meters)),
      active_calories: workout.active_calories == null ? null : Math.max(0, Number(workout.active_calories)),
      route_available: false,
    }))
    const { error } = await client.from('workouts').upsert(rows, { onConflict: 'source,external_id', ignoreDuplicates: true })
    if (error) return json({ error: error.message, activity_saved: true }, 422)
  }

  await client.from('health_ingest_tokens').update({ last_used_at: new Date().toISOString() }).eq('user_id', tokenRow.user_id)
  return json({ ok: true, activity_date: activityDate, workouts_received: workouts.length })
})
