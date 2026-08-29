export type HealthPlatform = 'ios' | 'android'

export type NormalizedMetric =
  | 'morning_steps'
  | 'afternoon_steps'
  | 'night_steps'
  | 'daily_steps'
  | 'distance_meters'
  | 'active_calories'
  | 'exercise_minutes'

export type NormalizedActivity = {
  activityDate: string
  metrics: Partial<Record<NormalizedMetric, number>>
  authoritative: NormalizedMetric[]
}

export type NormalizedSample = {
  metric: NormalizedMetric
  external_id: string
  activity_date: string
  value: number
  started_at: string | null
  ended_at: string | null
}

export type NormalizedWorkout = {
  externalId: string
  workoutType: string
  startedAt: string
  endedAt: string
  durationSeconds: number
  distanceMeters: number | null
  activeCalories: number | null
}

export type NormalizedHealthPayload = {
  platform: HealthPlatform
  sourceApp: string
  sourceDevice: string | null
  requestId: string | null
  activities: NormalizedActivity[]
  samples: NormalizedSample[]
  workouts: NormalizedWorkout[]
  metricSamples: number
  warnings: string[]
  manualEntryDetected: boolean
}

const APP_TIME_ZONE = 'America/Santiago'
const METRICS: NormalizedMetric[] = [
  'morning_steps',
  'afternoon_steps',
  'night_steps',
  'daily_steps',
  'distance_meters',
  'active_calories',
  'exercise_minutes',
]

const record = (value: unknown): Record<string, unknown> | null =>
  value !== null && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : null

const array = (value: unknown) => Array.isArray(value) ? value : []
const valueOf = (source: Record<string, unknown>, ...keys: string[]) => {
  for (const key of keys) if (Object.prototype.hasOwnProperty.call(source, key)) return source[key]
  return undefined
}
const cleanText = (value: unknown, fallback = '') => typeof value === 'string' && value.trim() ? value.trim() : fallback
const cleanNumber = (value: unknown) => Math.max(0, Number(value) || 0)

const validDate = (value: unknown): value is string => {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false
  const parsed = new Date(`${value}T00:00:00Z`)
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value
}

const iso = (value: unknown): string | null => {
  const date = new Date(typeof value === 'number' ? value : cleanText(value))
  return Number.isNaN(date.getTime()) ? null : date.toISOString()
}

const isoFromUnixMs = (value: unknown): string | null => {
  const milliseconds = Number(value)
  return Number.isFinite(milliseconds) && milliseconds > 0 ? iso(milliseconds) : null
}

const ensureEndAfterStart = (startedAt: string, endedAt: string | null, durationSeconds: number) =>
  endedAt && new Date(endedAt).getTime() > new Date(startedAt).getTime()
    ? endedAt
    : new Date(new Date(startedAt).getTime() + Math.max(1, durationSeconds) * 1000).toISOString()

const activityDate = (timestamp: string) => new Intl.DateTimeFormat('en-CA', {
  timeZone: APP_TIME_ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
}).format(new Date(timestamp))

const stableId = (prefix: string, source: Record<string, unknown>, startedAt: string, endedAt: string) =>
  cleanText(valueOf(source, 'uuid', 'external_id', 'externalId'), `${prefix}|${startedAt}|${endedAt}`).slice(0, 512)

function directPayload(payload: Record<string, unknown>): NormalizedHealthPayload {
  const platform = payload.source_platform
  if (platform !== 'ios' && platform !== 'android') throw new Error('source_platform must be ios or android')
  if (!validDate(payload.activity_date)) throw new Error('activity_date must use a real YYYY-MM-DD date')

  const metrics: Partial<Record<NormalizedMetric, number>> = {}
  const authoritative: NormalizedMetric[] = []
  for (const metric of METRICS) {
    if (!Object.prototype.hasOwnProperty.call(payload, metric)) continue
    metrics[metric] = cleanNumber(payload[metric])
    authoritative.push(metric)
  }
  const workouts: NormalizedWorkout[] = []
  for (const item of array(payload.workouts).slice(0, 200)) {
    const workout = record(item)
    if (!workout) continue
    const startedAt = iso(valueOf(workout, 'started_at', 'start_time'))
    if (!startedAt) continue
    const durationSeconds = Math.max(1, Math.round(cleanNumber(workout.duration_seconds) || 1))
    const endedAt = ensureEndAfterStart(startedAt, iso(valueOf(workout, 'ended_at', 'end_time')), durationSeconds)
    const workoutType = cleanText(valueOf(workout, 'workout_type', 'type'), 'workout').slice(0, 120)
    workouts.push({
      externalId: stableId(workoutType, workout, startedAt, endedAt),
      workoutType,
      startedAt,
      endedAt,
      durationSeconds,
      distanceMeters: valueOf(workout, 'distance_meters', 'total_distance_m') == null ? null : cleanNumber(valueOf(workout, 'distance_meters', 'total_distance_m')),
      activeCalories: valueOf(workout, 'active_calories', 'total_energy_kcal') == null ? null : cleanNumber(valueOf(workout, 'active_calories', 'total_energy_kcal')),
    })
  }
  return {
    platform,
    sourceApp: cleanText(payload.source_app, platform === 'ios' ? 'Apple Health bridge' : 'Android health bridge').slice(0, 120),
    sourceDevice: cleanText(payload.source_device) || null,
    requestId: cleanText(valueOf(payload, 'request_id', 'requestId')) || null,
    activities: [{ activityDate: payload.activity_date, metrics, authoritative }],
    samples: [],
    workouts,
    metricSamples: authoritative.length,
    warnings: [],
    manualEntryDetected: payload.manual_entry_detected === true,
  }
}

function lifeDashboardPayload(payload: Record<string, unknown>): NormalizedHealthPayload {
  const platform: HealthPlatform = payload.source === 'healthkit_ios' ? 'ios' : 'android'
  const samples: NormalizedSample[] = []
  const workouts: NormalizedWorkout[] = []
  const warnings: string[] = []
  const totals = array(payload.daily_totals).slice(0, 366)
  const activities: NormalizedActivity[] = []

  for (const item of totals) {
    const total = record(item)
    if (!total || !validDate(total.date)) continue
    const metrics: Partial<Record<NormalizedMetric, number>> = {}
    const authoritative: NormalizedMetric[] = []
    const mappings: Array<[string, NormalizedMetric]> = [
      ['steps', 'daily_steps'],
      ['distance_meters', 'distance_meters'],
      ['active_calories', 'active_calories'],
    ]
    for (const [input, metric] of mappings) {
      if (!Object.prototype.hasOwnProperty.call(total, input)) continue
      metrics[metric] = cleanNumber(total[input])
      authoritative.push(metric)
    }
    activities.push({ activityDate: total.date, metrics, authoritative })
  }

  const addSamples = (items: unknown[], metric: NormalizedMetric, inputKey: string) => {
    for (const item of items.slice(0, 5000)) {
      const sample = record(item)
      if (!sample) continue
      const startedAt = iso(valueOf(sample, 'start_time', 'started_at'))
      const endedAt = iso(valueOf(sample, 'end_time', 'ended_at')) || startedAt
      if (!startedAt || !endedAt) continue
      samples.push({
        metric,
        external_id: stableId(metric, sample, startedAt, endedAt),
        activity_date: activityDate(startedAt),
        value: cleanNumber(sample[inputKey]),
        started_at: startedAt,
        ended_at: endedAt,
      })
    }
  }

  if (!activities.length) {
    addSamples(array(payload.steps), 'daily_steps', 'count')
    addSamples(array(payload.distance), 'distance_meters', 'meters')
    addSamples(array(payload.active_calories), 'active_calories', 'calories')
    if (platform === 'android') warnings.push('Activa Daily totals en Life Dashboard para deduplicar correctamente teléfono y reloj.')
  }

  for (const item of array(payload.exercise).slice(0, 500)) {
    const exercise = record(item)
    if (!exercise) continue
    const startedAt = iso(valueOf(exercise, 'start_time', 'started_at'))
    if (!startedAt) continue
    const durationSeconds = Math.max(1, Math.round(cleanNumber(exercise.duration_seconds) || 1))
    const endedAt = ensureEndAfterStart(startedAt, iso(valueOf(exercise, 'end_time', 'ended_at')), durationSeconds)
    const externalId = stableId('exercise', exercise, startedAt, endedAt)
    samples.push({
      metric: 'exercise_minutes',
      external_id: externalId,
      activity_date: activityDate(startedAt),
      value: durationSeconds / 60,
      started_at: startedAt,
      ended_at: endedAt,
    })
    workouts.push({
      externalId,
      workoutType: cleanText(exercise.type, 'workout').slice(0, 120),
      startedAt,
      endedAt,
      durationSeconds,
      distanceMeters: valueOf(exercise, 'distance_meters') == null ? null : cleanNumber(exercise.distance_meters),
      activeCalories: valueOf(exercise, 'active_calories') == null ? null : cleanNumber(exercise.active_calories),
    })
  }

  return {
    platform,
    sourceApp: platform === 'ios' ? 'Life Dashboard Companion iOS' : 'Life Dashboard Companion',
    sourceDevice: cleanText(payload.device) || null,
    requestId: cleanText(valueOf(payload, 'batch_id', 'batchId')) || null,
    activities,
    samples,
    workouts,
    metricSamples: samples.length + activities.reduce((sum, row) => sum + row.authoritative.length, 0),
    warnings,
    manualEntryDetected: false,
  }
}

function conduitPayload(payload: Record<string, unknown>): NormalizedHealthPayload {
  const samples: NormalizedSample[] = []
  const workouts: NormalizedWorkout[] = []
  let sourceDevice: string | null = null
  const metricByType: Record<string, NormalizedMetric> = {
    HKQuantityTypeIdentifierStepCount: 'daily_steps',
    HKQuantityTypeIdentifierDistanceWalkingRunning: 'distance_meters',
    HKQuantityTypeIdentifierDistanceCycling: 'distance_meters',
    HKQuantityTypeIdentifierDistanceSwimming: 'distance_meters',
    HKQuantityTypeIdentifierActiveEnergyBurned: 'active_calories',
    HKQuantityTypeIdentifierAppleExerciseTime: 'exercise_minutes',
  }

  for (const item of array(payload.batches).slice(0, 100)) {
    const batch = record(item)
    if (!batch) continue
    const healthKitType = cleanText(valueOf(batch, 'hkTypeId', 'hk_type_id'))
    for (const raw of array(batch.samples).slice(0, 5000)) {
      const sample = record(raw)
      if (!sample) continue
      const startedAt = isoFromUnixMs(valueOf(sample, 'startUnixMs', 'start_unix_ms'))
      const endedAt = isoFromUnixMs(valueOf(sample, 'endUnixMs', 'end_unix_ms')) || startedAt
      if (!startedAt || !endedAt) continue
      const source = record(sample.source)
      if (!sourceDevice && source) sourceDevice = cleanText(valueOf(source, 'productType', 'product_type', 'name')) || null
      const externalId = stableId(healthKitType || 'healthkit', sample, startedAt, endedAt)

      if (healthKitType === 'HKWorkoutTypeIdentifier') {
        const workout = record(sample.workout)
        if (!workout) continue
        const durationSeconds = Math.max(1, Math.round(cleanNumber(valueOf(workout, 'durationSeconds', 'duration_seconds')) || (new Date(endedAt).getTime() - new Date(startedAt).getTime()) / 1000 || 1))
        workouts.push({
          externalId,
          workoutType: cleanText(valueOf(workout, 'activityType', 'activity_type'), 'workout').slice(0, 120),
          startedAt,
          endedAt: new Date(endedAt).getTime() > new Date(startedAt).getTime() ? endedAt : new Date(new Date(startedAt).getTime() + durationSeconds * 1000).toISOString(),
          durationSeconds,
          distanceMeters: valueOf(workout, 'totalDistanceM', 'total_distance_m') == null ? null : cleanNumber(valueOf(workout, 'totalDistanceM', 'total_distance_m')),
          activeCalories: valueOf(workout, 'totalEnergyKcal', 'total_energy_kcal') == null ? null : cleanNumber(valueOf(workout, 'totalEnergyKcal', 'total_energy_kcal')),
        })
        continue
      }

      const metric = metricByType[healthKitType]
      const quantity = record(sample.quantity)
      if (!metric || !quantity) continue
      samples.push({
        metric,
        external_id: externalId,
        activity_date: activityDate(startedAt),
        value: cleanNumber(quantity.value),
        started_at: startedAt,
        ended_at: endedAt,
      })
    }
  }

  return {
    platform: 'ios',
    sourceApp: 'Conduit Health Sync',
    sourceDevice,
    requestId: cleanText(valueOf(payload, 'batchId', 'batch_id')) || null,
    activities: [],
    samples,
    workouts,
    metricSamples: samples.length,
    warnings: [],
    manualEntryDetected: false,
  }
}

export function inferHealthPlatform(payload: Record<string, unknown>): HealthPlatform | null {
  if (payload.source_platform === 'ios' || payload.source_platform === 'android') return payload.source_platform
  if (payload.source === 'health_connect') return 'android'
  if (payload.source === 'healthkit_ios') return 'ios'
  if (valueOf(payload, 'schemaVersion', 'schema_version') === 'v1' && Array.isArray(payload.batches)) return 'ios'
  return null
}

export function normalizeHealthPayload(payloadValue: unknown): NormalizedHealthPayload {
  const payload = record(payloadValue)
  if (!payload) throw new Error('Payload must be a JSON object')
  if (payload.source === 'health_connect' || payload.source === 'healthkit_ios') return lifeDashboardPayload(payload)
  if (valueOf(payload, 'schemaVersion', 'schema_version') === 'v1' && Array.isArray(payload.batches)) return conduitPayload(payload)
  return directPayload(payload)
}
