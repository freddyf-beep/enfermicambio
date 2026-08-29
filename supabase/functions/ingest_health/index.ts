import { createClient } from '@supabase/supabase-js'
import {
  inferHealthPlatform,
  normalizeHealthPayload,
  type HealthPlatform,
  type NormalizedActivity,
  type NormalizedMetric,
} from './normalizer.ts'

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
  return [...new Uint8Array(bytes)].map(byte => byte.toString(16).padStart(2, '0')).join('')
}

const number = (value: unknown) => Math.max(0, Number(value) || 0)
const tokenPlatform = (source: string): HealthPlatform | null =>
  source === PLATFORM_SOURCE.ios ? 'ios' : source === PLATFORM_SOURCE.android ? 'android' : null

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
    const parsed = JSON.parse(raw)
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error('not an object')
    payload = parsed as Record<string, unknown>
  } catch {
    return json({ error: 'Invalid JSON object' }, 400)
  }

  const inferredPlatform = inferHealthPlatform(payload) || tokenPlatform(tokenRow.source)
  if (!inferredPlatform) return json({ error: 'Could not identify the health platform' }, 400)
  const expectedSource = PLATFORM_SOURCE[inferredPlatform]
  if (tokenRow.source !== expectedSource && tokenRow.source !== LEGACY_SOURCE) {
    return json({ error: 'Token does not belong to this platform' }, 403)
  }

  const importedAt = new Date().toISOString()
  if (payload.validate_only === true) {
    await admin.from('health_ingestion_tokens').update({ last_used_at: importedAt }).eq('token_hash', hash)
    return json({ ok: true, validated: true, platform: inferredPlatform, accepted: 0, deduped: 0 })
  }

  let normalized
  try {
    normalized = normalizeHealthPayload(payload)
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unsupported health payload' }, 400)
  }
  if (normalized.platform !== inferredPlatform) return json({ error: 'Payload platform does not match its token' }, 403)

  // Empty envelopes are the Test Connection payload used by Conduit and Life
  // Dashboard. A valid 2xx here confirms URL + Bearer token without inventing
  // a health-data reception in the activity history.
  if (!normalized.activities.length && !normalized.samples.length && !normalized.workouts.length) {
    await admin.from('health_ingestion_tokens').update({ last_used_at: importedAt }).eq('token_hash', hash)
    return json({ ok: true, validated: true, platform: normalized.platform, accepted: 0, deduped: 0 })
  }

  const source = PLATFORM_SOURCE[normalized.platform]
  const sampleKeys = new Set<string>()
  const samples = normalized.samples.filter(sample => {
    const key = `${sample.metric}|${sample.external_id}`
    if (sampleKeys.has(key)) return false
    sampleKeys.add(key)
    return true
  })
  let samplesAccepted = 0
  let samplesDeduped = 0
  let sampleTotals: Array<Record<string, unknown>> = []
  if (samples.length) {
    const { data, error } = await admin.rpc('merge_health_activity_samples', {
      p_user_id: tokenRow.user_id,
      p_source: source,
      p_samples: samples,
    })
    if (error) return json({ error: `Could not merge health samples: ${error.message}` }, 503)
    const result = data && typeof data === 'object' ? data as Record<string, unknown> : {}
    samplesAccepted = Math.max(0, Number(result.accepted) || 0)
    samplesDeduped = Math.max(0, Number(result.deduped) || 0)
    sampleTotals = Array.isArray(result.daily_totals) ? result.daily_totals as Array<Record<string, unknown>> : []
  }

  const activitiesByDate = new Map<string, NormalizedActivity>()
  const addActivity = (incoming: NormalizedActivity) => {
    const existing = activitiesByDate.get(incoming.activityDate)
    if (!existing) {
      activitiesByDate.set(incoming.activityDate, {
        activityDate: incoming.activityDate,
        metrics: { ...incoming.metrics },
        authoritative: [...incoming.authoritative],
      })
      return
    }
    Object.assign(existing.metrics, incoming.metrics)
    existing.authoritative = [...new Set([...existing.authoritative, ...incoming.authoritative])]
  }
  normalized.activities.forEach(addActivity)

  const sampleMetricsByDate = new Map<string, Set<NormalizedMetric>>()
  for (const sample of samples) {
    const metrics = sampleMetricsByDate.get(sample.activity_date) || new Set<NormalizedMetric>()
    metrics.add(sample.metric)
    sampleMetricsByDate.set(sample.activity_date, metrics)
  }
  for (const total of sampleTotals) {
    const date = typeof total.activity_date === 'string' ? total.activity_date : ''
    const presentMetrics = sampleMetricsByDate.get(date)
    if (!presentMetrics?.size) continue
    const metrics: Partial<Record<NormalizedMetric, number>> = {}
    for (const metric of presentMetrics) metrics[metric] = number(total[metric])
    addActivity({ activityDate: date, metrics, authoritative: [...presentMetrics] })
  }

  const activities = [...activitiesByDate.values()].sort((a, b) => a.activityDate.localeCompare(b.activityDate))
  const importedDates = activities.map(activity => activity.activityDate)
  const previousByDate = new Map<string, Record<string, unknown>>()
  if (importedDates.length) {
    const { data, error } = await admin.from('daily_activity')
      .select('activity_date,morning_steps,afternoon_steps,night_steps,daily_steps,active_calories,distance_meters,exercise_minutes')
      .eq('user_id', tokenRow.user_id).in('activity_date', importedDates)
    if (error) return json({ error: 'Could not merge existing activity' }, 503)
    for (const row of data || []) previousByDate.set(row.activity_date, row)
  }

  const activityRows = activities.map(activity => {
    const previous = previousByDate.get(activity.activityDate) || {}
    const merged = (metric: NormalizedMetric) => {
      if (!Object.prototype.hasOwnProperty.call(activity.metrics, metric)) return number(previous[metric])
      const incoming = number(activity.metrics[metric])
      return activity.authoritative.includes(metric) ? incoming : Math.max(incoming, number(previous[metric]))
    }
    return {
      user_id: tokenRow.user_id,
      activity_date: activity.activityDate,
      morning_steps: Math.round(merged('morning_steps')),
      afternoon_steps: Math.round(merged('afternoon_steps')),
      night_steps: Math.round(merged('night_steps')),
      daily_steps: Math.round(merged('daily_steps')),
      active_calories: merged('active_calories'),
      distance_meters: merged('distance_meters'),
      exercise_minutes: merged('exercise_minutes'),
      synced_at: importedAt,
      source_platform: normalized.platform,
      source_app: normalized.sourceApp,
      source_device: normalized.sourceDevice,
      recording_method: normalized.manualEntryDetected ? 'mixed' : 'automatic_export',
      manual_entry_detected: normalized.manualEntryDetected,
      source_metadata: {
        bridge: source,
        importer: normalized.sourceApp,
        request_id: normalized.requestId,
        raw_payload_stored: false,
        imported_at: importedAt,
      },
    }
  })

  const recordRun = async (status: 'success' | 'failed', stage: string, workoutCount = 0, errorMessage: string | null = null) => {
    await admin.from('health_ingestion_runs').insert({
      user_id: tokenRow.user_id,
      source,
      request_id: normalized.requestId,
      status,
      stage,
      metric_samples: normalized.metricSamples,
      workouts: workoutCount,
      imported_dates: importedDates,
      warnings: normalized.warnings,
      error_message: errorMessage,
    })
  }

  if (activityRows.length) {
    const { error } = await admin.from('daily_activity').upsert(activityRows, { onConflict: 'user_id,activity_date' })
    if (error) {
      await recordRun('failed', 'daily_activity', 0, error.message)
      return json({ error: error.message }, 422)
    }
  }

  const workoutKeys = new Set<string>()
  const workoutRows = normalized.workouts.filter(workout => {
    const key = workout.externalId
    if (workoutKeys.has(key)) return false
    workoutKeys.add(key)
    return true
  }).map(workout => ({
    user_id: tokenRow.user_id,
    external_id: workout.externalId,
    source,
    workout_type: workout.workoutType,
    started_at: workout.startedAt,
    ended_at: workout.endedAt,
    duration_seconds: workout.durationSeconds,
    distance_meters: workout.distanceMeters,
    active_calories: workout.activeCalories,
    route_available: false,
  }))
  if (workoutRows.length) {
    const { error } = await admin.from('workouts').upsert(workoutRows, { onConflict: 'source,external_id' })
    if (error) {
      await recordRun('failed', 'workouts', 0, error.message)
      return json({ error: error.message, activity_saved: activityRows.length > 0 }, 422)
    }
  }

  await admin.from('health_ingestion_tokens').update({ last_used_at: importedAt }).eq('token_hash', hash)
  await recordRun('success', 'complete', workoutRows.length)
  for (const date of importedDates) {
    await admin.rpc('evaluate_achievements', { p_user_id: tokenRow.user_id, p_date: date })
    try {
      await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/generate_events`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ user_id: tokenRow.user_id, date }),
      })
    } catch { /* daily close remains the authoritative retry path */ }
  }

  return json({
    ok: true,
    validated: true,
    platform: normalized.platform,
    imported_dates: importedDates,
    workouts_received: workoutRows.length,
    warnings: normalized.warnings,
    accepted: samplesAccepted + activityRows.length + workoutRows.length,
    deduped: samplesDeduped,
  })
})
