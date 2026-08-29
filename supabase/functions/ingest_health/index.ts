import { createClient } from '@supabase/supabase-js'

const PLATFORM_SOURCE = {
  ios: 'ios_shortcut',
  android: 'android_health_connect',
} as const
const LEGACY_SOURCE = 'generic_health_export'
const ACCEPTED_SOURCES = [...Object.values(PLATFORM_SOURCE), LEGACY_SOURCE]
const MAX_BODY_BYTES = 1024 * 1024
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const json = (body: Record<string, unknown>, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...cors, 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' },
})

async function sha256(value: string) {
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))
  return [...new Uint8Array(bytes)].map(x => x.toString(16).padStart(2, '0')).join('')
}

const text = (value: unknown, fallback = '') => typeof value === 'string' && value.trim() ? value.trim() : fallback
const number = (payload: Record<string, unknown>, key: string) => Math.max(0, Number(payload[key]) || 0)
const mergedNumber = (payload: Record<string, unknown>, key: string, fallback: unknown) =>
  Object.prototype.hasOwnProperty.call(payload, key) ? number(payload, key) : Math.max(0, Number(fallback) || 0)

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  const token = request.headers.get('Authorization')?.replace(/^Bearer\s+/i, '').trim()
  if (!token || token.length < 32 || token.length > 256) return json({ error: 'Invalid token' }, 401)
  const bodyLength = Number(request.headers.get('content-length') || 0)
  if (bodyLength > MAX_BODY_BYTES) return json({ error: 'Payload too large' }, 413)

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  )
  const hash = await sha256(token)
  const { data: tokenRow, error: tokenError } = await admin.from('health_ingestion_tokens')
    .select('user_id,source').eq('token_hash', hash).in('source', ACCEPTED_SOURCES).eq('active', true).maybeSingle()
  if (tokenError) return json({ error: 'Bridge unavailable' }, 503)
  if (!tokenRow?.user_id) return json({ error: 'Invalid token' }, 401)

  let payload: Record<string, unknown>
  try {
    const raw = await request.text()
    if (new TextEncoder().encode(raw).byteLength > MAX_BODY_BYTES) return json({ error: 'Payload too large' }, 413)
    payload = JSON.parse(raw)
  } catch { return json({ error: 'Invalid JSON' }, 400) }

  const platform = payload.source_platform
  if (platform !== 'ios' && platform !== 'android') return json({ error: 'source_platform must be ios or android' }, 400)
  const source = PLATFORM_SOURCE[platform]
  if (tokenRow.source !== source && tokenRow.source !== LEGACY_SOURCE) return json({ error: 'Token does not belong to this platform' }, 403)
  const activityDate = text(payload.activity_date)
  if (!/^\d{4}-\d{2}-\d{2}$/.test(activityDate) || Number.isNaN(Date.parse(`${activityDate}T00:00:00Z`))) {
    return json({ error: 'activity_date must use YYYY-MM-DD' }, 400)
  }
  const importedAt = new Date().toISOString()
  const sourceApp = text(payload.source_app, platform === 'ios' ? 'EnfermiCambio Shortcut' : 'Health Connect Exporter').slice(0, 120)
  const manual = payload.manual_entry_detected === true
  const metricKeys = ['morning_steps', 'afternoon_steps', 'night_steps', 'daily_steps', 'active_calories', 'distance_meters', 'exercise_minutes']
  const metricSamples = metricKeys.filter(key => Object.prototype.hasOwnProperty.call(payload, key)).length
  const recordRun = async (status: 'success' | 'failed', stage: string, workouts = 0, errorMessage: string | null = null) => {
    await admin.from('health_ingestion_runs').insert({
      user_id: tokenRow.user_id,
      source,
      status,
      stage,
      metric_samples: metricSamples,
      workouts,
      imported_dates: [activityDate],
      error_message: errorMessage,
    })
  }

  const { data: previousActivity, error: previousError } = await admin.from('daily_activity')
    .select('morning_steps,afternoon_steps,night_steps,daily_steps,active_calories,distance_meters,exercise_minutes')
    .eq('user_id', tokenRow.user_id).eq('activity_date', activityDate).maybeSingle()
  if (previousError) return json({ error: 'Could not merge existing activity' }, 503)

  const { error: activityError } = await admin.from('daily_activity').upsert({
    user_id: tokenRow.user_id,
    activity_date: activityDate,
    morning_steps: Math.round(mergedNumber(payload, 'morning_steps', previousActivity?.morning_steps)),
    afternoon_steps: Math.round(mergedNumber(payload, 'afternoon_steps', previousActivity?.afternoon_steps)),
    night_steps: Math.round(mergedNumber(payload, 'night_steps', previousActivity?.night_steps)),
    daily_steps: Math.round(mergedNumber(payload, 'daily_steps', previousActivity?.daily_steps)),
    active_calories: mergedNumber(payload, 'active_calories', previousActivity?.active_calories),
    distance_meters: mergedNumber(payload, 'distance_meters', previousActivity?.distance_meters),
    exercise_minutes: mergedNumber(payload, 'exercise_minutes', previousActivity?.exercise_minutes),
    synced_at: importedAt,
    source_platform: platform,
    source_app: sourceApp,
    source_device: text(payload.source_device) || null,
    recording_method: manual ? 'mixed' : 'automatic_export',
    manual_entry_detected: manual,
    source_metadata: { bridge: source, raw_payload_stored: false, imported_at: importedAt },
  }, { onConflict: 'user_id,activity_date' })
  if (activityError) {
    await recordRun('failed', 'daily_activity', 0, activityError.message)
    return json({ error: activityError.message }, 422)
  }

  const rawWorkouts = Array.isArray(payload.workouts) ? payload.workouts.slice(0, 100) : []
  const rows = []
  for (const rawWorkout of rawWorkouts) {
    if (!rawWorkout || typeof rawWorkout !== 'object') continue
    const workout = rawWorkout as Record<string, unknown>
    const startedAt = new Date(text(workout.started_at))
    if (Number.isNaN(startedAt.getTime())) continue
    const duration = Math.max(1, Math.round(Number(workout.duration_seconds) || 1))
    const endedAt = new Date(text(workout.ended_at) || startedAt.getTime() + duration * 1000)
    const fingerprint = `${tokenRow.user_id}|${startedAt.toISOString()}|${text(workout.workout_type, 'workout')}|${duration}`
    rows.push({
      user_id: tokenRow.user_id,
      external_id: text(workout.external_id) || await sha256(fingerprint),
      source,
      workout_type: text(workout.workout_type, 'workout').slice(0, 120),
      started_at: startedAt.toISOString(),
      ended_at: Number.isNaN(endedAt.getTime()) ? new Date(startedAt.getTime() + duration * 1000).toISOString() : endedAt.toISOString(),
      duration_seconds: duration,
      distance_meters: workout.distance_meters == null ? null : Math.max(0, Number(workout.distance_meters) || 0),
      active_calories: workout.active_calories == null ? null : Math.max(0, Number(workout.active_calories) || 0),
      route_available: false,
    })
  }
  if (rows.length) {
    const { error } = await admin.from('workouts').upsert(rows, { onConflict: 'source,external_id' })
    if (error) {
      await recordRun('failed', 'workouts', 0, error.message)
      return json({ error: error.message, activity_saved: true }, 422)
    }
  }

  await admin.from('health_ingestion_tokens').update({ last_used_at: importedAt }).eq('token_hash', hash)
  await recordRun('success', 'complete', rows.length)
  await admin.rpc('evaluate_achievements', { p_user_id: tokenRow.user_id, p_date: activityDate })
  try {
    await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/generate_events`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ user_id: tokenRow.user_id, date: activityDate }),
    })
  } catch { /* daily close remains the authoritative retry path */ }

  return json({ ok: true, activity_date: activityDate, workouts_received: rows.length })
})
