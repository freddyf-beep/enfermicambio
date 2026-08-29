import assert from 'node:assert/strict'
import test from 'node:test'
import { normalizeHealthPayload } from './normalizer.ts'

test('normalizes Conduit ProtoJSON and keeps HealthKit UUIDs stable', () => {
  const start = Date.parse('2026-08-29T13:00:00Z')
  const normalized = normalizeHealthPayload({
    schemaVersion: 'v1',
    batchId: 'batch-ios',
    batches: [
      { hkTypeId: 'HKQuantityTypeIdentifierStepCount', samples: [{ uuid: 'step-1', startUnixMs: String(start), endUnixMs: String(start + 60000), quantity: { value: 123, unit: 'count' } }] },
      { hkTypeId: 'HKQuantityTypeIdentifierActiveEnergyBurned', samples: [{ uuid: 'cal-1', startUnixMs: String(start), endUnixMs: String(start + 60000), quantity: { value: 45, unit: 'kcal' } }] },
      { hkTypeId: 'HKWorkoutTypeIdentifier', samples: [{ uuid: 'workout-1', startUnixMs: String(start), endUnixMs: String(start + 1800000), workout: { activityType: 'running', durationSeconds: 1800, totalDistanceM: 4200 } }] },
    ],
  })
  assert.equal(normalized.platform, 'ios')
  assert.equal(normalized.requestId, 'batch-ios')
  assert.deepEqual(normalized.samples.map(sample => [sample.metric, sample.external_id, sample.value]), [
    ['daily_steps', 'step-1', 123],
    ['active_calories', 'cal-1', 45],
  ])
  assert.equal(normalized.workouts[0].externalId, 'workout-1')
  assert.equal(normalized.workouts[0].durationSeconds, 1800)
})

test('prefers deduplicated Android daily totals and maps exercise UUIDs', () => {
  const normalized = normalizeHealthPayload({
    timestamp: '2026-08-29T12:00:00Z',
    app_version: '1.8.0',
    source: 'health_connect',
    daily_totals: [{ date: '2026-08-29', steps: 8420, distance_meters: 6120, active_calories: 510 }],
    steps: [{ uuid: 'ignored-because-aggregate', count: 9000, start_time: '2026-08-29T08:00:00Z', end_time: '2026-08-29T09:00:00Z' }],
    exercise: [{ uuid: 'run-1', type: 'running', start_time: '2026-08-29T10:00:00Z', end_time: '2026-08-29T10:30:00Z', duration_seconds: 1800 }],
  })
  assert.equal(normalized.platform, 'android')
  assert.deepEqual(normalized.activities[0].metrics, { daily_steps: 8420, distance_meters: 6120, active_calories: 510 })
  assert.equal(normalized.samples.some(sample => sample.metric === 'daily_steps'), false)
  assert.equal(normalized.samples.find(sample => sample.metric === 'exercise_minutes')?.external_id, 'run-1')
  assert.equal(normalized.workouts[0].workoutType, 'running')
})

test('accepts the exact Conduit Test Connection envelope when SwiftProtobuf omits empty batches', () => {
  const normalized = normalizeHealthPayload({
    schemaVersion: 'v1',
    batchId: 'test-1',
    deviceId: 'iphone-test',
    sentAtUnixMs: '1788012000000',
  })
  assert.equal(normalized.platform, 'ios')
  assert.equal(normalized.requestId, 'test-1')
  assert.equal(normalized.samples.length, 0)
  assert.equal(normalized.workouts.length, 0)
})

test('preserves segmented and manual flags from the legacy flat contract', () => {
  const normalized = normalizeHealthPayload({
    source_platform: 'ios',
    activity_date: '2026-08-29',
    morning_steps: 1500,
    afternoon_steps: 2300,
    night_steps: 700,
    daily_steps: 4500,
    manual_entry_detected: true,
  })
  assert.deepEqual(normalized.activities[0].metrics, {
    morning_steps: 1500,
    afternoon_steps: 2300,
    night_steps: 700,
    daily_steps: 4500,
  })
  assert.equal(normalized.manualEntryDetected, true)
})
