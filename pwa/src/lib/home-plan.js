// Home-mode plan builder.
//
// This module deliberately keeps the generator independent from React.  The view can render a
// plan, let somebody remove a movement, and then pass the same (plain) object to
// applyHomePlanToState from a Zustand update.  Every movement is resolved from EXDB so the
// normal workout runtime, progression rules, exercise translations and history keep working.

import { EXDB } from './exercises-data.js'
import { uid } from './format.js'
import { applyTrainingPlace } from './equipment.js'

export const HOME_DURATIONS = Object.freeze([10, 20, 30, 45])
export const HOME_OBJECTIVES = Object.freeze(['strength', 'active', 'mobility'])
export const HOME_LEVELS = Object.freeze(['beginner', 'intermediate', 'advanced'])
export const HOME_IMPACTS = Object.freeze(['low', 'high'])
export const HOME_NOISES = Object.freeze(['quiet', 'normal'])
export const HOME_EQUIPMENT = Object.freeze(['none', 'chair', 'band', 'dumbbells'])

export const HOME_DEFAULTS = Object.freeze({
  duration: 20,
  objective: 'strength',
  level: 'beginner',
  impact: 'low',
  noise: 'quiet',
  equipment: 'none',
  sessions: null,
})

export const HOME_OPTIONS = Object.freeze({
  durations: HOME_DURATIONS,
  objectives: HOME_OBJECTIVES,
  levels: HOME_LEVELS,
  impacts: HOME_IMPACTS,
  noises: HOME_NOISES,
  equipment: HOME_EQUIPMENT,
})

const EXIDX = new Map(EXDB.map(exercise => [exercise.id, exercise]))
const LEVEL_RANK = { beginner: 1, intermediate: 2, advanced: 3 }
const OBJECTIVE_ALIASES = {
  strength: 'strength', fuerza: 'strength', fuerte: 'strength', musculacion: 'strength',
  muscle: 'strength', muscles: 'strength', power: 'strength',
  active: 'active', activo: 'active', activa: 'active', cardio: 'active', energia: 'active',
  mobility: 'mobility', movilidad: 'mobility', recovery: 'mobility', recuperacion: 'mobility',
  stretch: 'mobility', estirar: 'mobility',
}
const LEVEL_ALIASES = {
  beginner: 'beginner', inicial: 'beginner', principiante: 'beginner', basic: 'beginner', basico: 'beginner',
  intermediate: 'intermediate', intermedio: 'intermediate', medio: 'intermediate',
  advanced: 'advanced', avanzado: 'advanced', expert: 'advanced', experto: 'advanced',
}
const IMPACT_ALIASES = {
  low: 'low', bajo: 'low', baja: 'low', quiet: 'low', suave: 'low', silent: 'low',
  high: 'high', alto: 'high', alta: 'high', any: 'high', libre: 'high', mixed: 'high', mixto: 'high',
}
const NOISE_ALIASES = {
  quiet: 'quiet', silencioso: 'quiet', silenciosa: 'quiet', bajo: 'quiet', baja: 'quiet', low: 'quiet',
  normal: 'normal', any: 'normal', libre: 'normal', alto: 'normal', alta: 'normal', loud: 'normal',
}
const EQUIPMENT_ALIASES = {
  none: 'none', ninguno: 'none', ninguna: 'none', 'sin equipo': 'none', bodyweight: 'none',
  chair: 'chair', silla: 'chair', banco: 'chair', bench: 'chair',
  band: 'band', banda: 'band', elastic: 'band', elastico: 'band', 'resistance band': 'band',
  dumbbell: 'dumbbells', dumbbells: 'dumbbells', mancuerna: 'dumbbells', mancuernas: 'dumbbells',
}

const cleanToken = value => String(value == null ? '' : value)
  .normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim()

const oneOf = (value, aliases, fallback) => aliases[cleanToken(value)] || fallback
const nearestDuration = value => {
  const n = Number(value)
  if (!Number.isFinite(n)) return HOME_DEFAULTS.duration
  return HOME_DURATIONS.reduce((best, current) =>
    Math.abs(current - n) < Math.abs(best - n) ? current : best, HOME_DEFAULTS.duration)
}

export function normalizeHomeOptions(options = {}) {
  const source = options && typeof options === 'object' ? options : {}
  const sessionsValue = Number(source.sessions ?? source.days ?? source.workoutsPerWeek ?? source.frequency)
  const sessions = Number.isFinite(sessionsValue) && sessionsValue > 0
    ? Math.min(4, Math.max(2, Math.round(sessionsValue)))
    : null
  return {
    duration: nearestDuration(source.duration ?? source.minutes ?? source.time),
    objective: oneOf(source.objective ?? source.goal ?? source.focus, OBJECTIVE_ALIASES, HOME_DEFAULTS.objective),
    level: oneOf(source.level ?? source.experience, LEVEL_ALIASES, HOME_DEFAULTS.level),
    impact: oneOf(source.impact ?? source.impactLevel, IMPACT_ALIASES, HOME_DEFAULTS.impact),
    noise: oneOf(source.noise ?? source.sound ?? source.noiseLevel, NOISE_ALIASES, HOME_DEFAULTS.noise),
    equipment: oneOf(source.equipment ?? source.kit ?? source.gear, EQUIPMENT_ALIASES, HOME_DEFAULTS.equipment),
    sessions,
  }
}

// `kit` is the extra item a movement needs.  `none` is intentionally explicit: chair, band and
// dumbbell movements can then be filtered without treating an EXDB equipment label as a user
// profile (the profile is updated separately when a plan is saved).
const movement = (id, guideSlug, kit, objectives, focus, minLevel = 1, impact = 'low', noise = 'quiet') => ({
  id, guideSlug, kit, objectives, focus, minLevel, impact, noise,
})

// Curated from EXDB and the local Workout Guide frames.  The guide slug is kept here because
// EXDB's long names (and a few translated aliases) do not always match the asset directory slug
// byte-for-byte.  All ids below are bodyweight, band or dumbbell entries present in EXDB.
export const HOME_LIBRARY = Object.freeze([
  // Quiet strength — no equipment.
  movement('0662', 'push-up', 'none', ['strength', 'active'], 'push'),
  movement('0493', 'incline-push-up', 'none', ['strength', 'active'], 'push', 1),
  movement('0659', 'wall-push-up', 'none', ['strength', 'active'], 'push', 1),
  movement('1685', 'squat', 'none', ['strength', 'active', 'mobility'], 'squat', 1),
  movement('3013', 'glute-bridge', 'none', ['strength', 'active', 'mobility'], 'hinge', 1),
  movement('3561', 'glute-bridge-march', 'none', ['strength', 'active', 'mobility'], 'hinge', 2),
  movement('1460', 'walking-lunge', 'none', ['strength', 'active'], 'legs', 1, 'low', 'normal'),
  movement('2368', 'split-squat', 'none', ['strength'], 'legs', 2),
  movement('1373', 'standing-calf-raise', 'none', ['strength', 'active'], 'legs', 1),
  movement('0276', 'dead-bug', 'none', ['strength', 'active', 'mobility'], 'core', 1),
  movement('0687', 'russian-twist', 'none', ['strength', 'active'], 'core', 2),
  movement('0705', 'side-plank', 'none', ['strength', 'active', 'mobility'], 'core', 2),
  movement('0464', 'plank', 'none', ['strength', 'active', 'mobility'], 'core', 1),
  movement('3167', 'towel-row', 'none', ['strength'], 'pull', 2),
  movement('1773', 'towel-row', 'none', ['strength'], 'pull', 2),
  movement('0129', 'bench-dip', 'chair', ['strength'], 'push', 2),
  movement('2963', 'captains-chair-knee-raise', 'chair', ['strength', 'active'], 'core', 2),
  movement('3132', 'squat', 'chair', ['strength', 'mobility'], 'squat', 1),

  // Quiet/low-impact conditioning.  Louder choices are still available when the user allows
  // normal noise and high impact below.
  movement('0630', 'mountain-climber', 'none', ['active'], 'cardio', 1, 'low', 'normal'),
  movement('0628', 'banded-lateral-walk', 'none', ['active', 'mobility'], 'legs', 1),
  movement('1604', 'worlds-greatest-stretch', 'none', ['mobility', 'active'], 'mobility', 1),
  movement('1511', 'hamstring-stretch', 'none', ['mobility'], 'mobility', 1),
  movement('1271', 'doorway-chest-stretch', 'none', ['mobility'], 'mobility', 1),
  movement('1548', 'standing-quad-stretch', 'chair', ['mobility'], 'mobility', 1),
  movement('0690', 'seated-forward-fold-stretch', 'chair', ['mobility'], 'mobility', 1),
  movement('1363', 'seated-forward-fold-stretch', 'none', ['mobility'], 'mobility', 1),
  movement('3561', 'glute-bridge-march', 'none', ['mobility'], 'hinge', 1),

  // Higher-impact active options.  These are excluded by a low-impact request and become
  // available for normal noise/high impact profiles.
  movement('1160', 'burpee', 'none', ['active'], 'cardio', 2, 'high', 'loud'),
  movement('3224', 'jumping-jack', 'none', ['active'], 'cardio', 1, 'high', 'loud'),
  movement('3361', 'skater-hop', 'none', ['active'], 'cardio', 2, 'high', 'loud'),

  // Band kit.
  movement('1004', 'banded-squat', 'band', ['strength', 'active'], 'squat', 1),
  movement('0988', 'banded-row', 'band', ['strength'], 'pull', 1),
  movement('0997', 'banded-face-pull', 'band', ['strength', 'mobility'], 'pull', 1),
  movement('0975', 'push-up', 'band', ['strength'], 'push', 2),
  movement('0993', 'band-pull-apart', 'band', ['strength', 'mobility'], 'pull', 1),
  movement('1408', 'banded-glute-bridge', 'band', ['strength', 'active'], 'hinge', 1),
  movement('0987', 'split-squat', 'band', ['strength'], 'legs', 2),
  movement('0972', 'banded-dead-bug', 'band', ['strength', 'active'], 'core', 1),
  movement('0979', 'banded-pallof-press', 'band', ['strength', 'active'], 'core', 1),
  movement('1003', 'banded-squat', 'band', ['active'], 'squat', 1),
  movement('1018', 'banded-face-pull', 'band', ['strength'], 'pull', 1),
  movement('0999', 'standing-calf-raise', 'band', ['strength'], 'legs', 1),
  movement('0968', 'bicep-curl', 'band', ['strength'], 'pull', 1),
  movement('0998', 'tricep-kickback', 'band', ['strength'], 'push', 1),

  // Dumbbells.
  movement('1760', 'goblet-squat', 'dumbbells', ['strength', 'active'], 'squat', 1),
  movement('0300', 'dumbbell-romanian-deadlift', 'dumbbells', ['strength'], 'hinge', 1),
  movement('1459', 'dumbbell-romanian-deadlift', 'dumbbells', ['strength'], 'hinge', 2),
  movement('0293', 'dumbbell-bent-over-row', 'dumbbells', ['strength'], 'pull', 1),
  movement('0294', 'bicep-curl', 'dumbbells', ['strength'], 'pull', 1),
  movement('0313', 'hammer-curl', 'dumbbells', ['strength'], 'pull', 1),
  movement('2137', 'arnold-press', 'dumbbells', ['strength'], 'push', 2),
  movement('0334', 'lateral-raise', 'dumbbells', ['strength', 'mobility'], 'push', 1),
  movement('0336', 'walking-lunge', 'dumbbells', ['strength'], 'legs', 1, 'low', 'normal'),
  movement('1739', 'tricep-kickback', 'dumbbells', ['strength'], 'push', 1),
  movement('0407', 'dumbbell-side-bend', 'dumbbells', ['strength'], 'core', 1),
  movement('0417', 'standing-calf-raise', 'dumbbells', ['strength'], 'legs', 1),
])

const HOME_BY_ID = new Map(HOME_LIBRARY.map(item => [item.id, item]))

export function homeExerciseMeta(idOrEntry) {
  const id = typeof idOrEntry === 'string' ? idOrEntry : idOrEntry?.id
  return HOME_BY_ID.get(id) || null
}

export function getHomeExercise(idOrEntry) {
  const id = typeof idOrEntry === 'string' ? idOrEntry : idOrEntry?.id
  const ex = EXIDX.get(id)
  const meta = HOME_BY_ID.get(id)
  return ex && meta ? { ...ex, ...meta } : ex ? { ...ex } : null
}

export const homeExerciseFor = getHomeExercise

const GUIDE_ROOT = 'workout-guide/assets/'
export function guideAssetFor(idOrEntry, frame = 1) {
  const meta = typeof idOrEntry === 'object' && idOrEntry?.guideSlug
    ? idOrEntry
    : homeExerciseMeta(idOrEntry)
  if (!meta?.guideSlug) return null
  const n = Math.min(3, Math.max(1, Math.round(Number(frame) || 1)))
  return `${GUIDE_ROOT}${meta.guideSlug}/frame-${n}.svg`
}

// Aliases make the asset helper discoverable from an integration or a small storybook without
// having to know the internal naming used by the generator.
export const homeGuideAsset = guideAssetFor

const defaultSessionsFor = duration => duration <= 10 ? 2 : duration <= 20 ? 3 : duration <= 30 ? 3 : 4
const exercisesPerRoutineFor = duration => duration <= 10 ? 4 : duration <= 20 ? 5 : duration <= 30 ? 6 : 7

function eligibleForKit(item, equipment) {
  return item.kit === 'none' || item.kit === equipment
}

function eligibleForPreferences(item, options) {
  if (!options.objective || !item.objectives.includes(options.objective)) return false
  if (!eligibleForKit(item, options.equipment)) return false
  if ((LEVEL_RANK[options.level] || 1) < item.minLevel) return false
  if (options.impact === 'low' && item.impact !== 'low') return false
  if (options.noise === 'quiet' && item.noise !== 'quiet') return false
  return true
}

const FOCUS_ORDER = {
  strength: ['push', 'legs', 'hinge', 'pull', 'core'],
  active: ['cardio', 'squat', 'push', 'legs', 'hinge', 'core', 'mobility'],
  mobility: ['mobility', 'hinge', 'legs', 'push', 'core'],
}

// A small, stable hash keeps generated plans varied across the four routines while preserving
// deterministic previews.  `seed` is optional and can be supplied by a test or a story.
function hashSeed(seed) {
  return String(seed ?? 'home').split('').reduce((sum, char, i) => (sum + char.charCodeAt(0) * (i + 1)) % 1000003, 17)
}

function availableLibrary(options) {
  const strict = HOME_LIBRARY.filter(item => eligibleForPreferences(item, options))
  if (strict.length >= 3) return strict
  // If a very narrow combination (for example mobility + chair + quiet) has fewer than three
  // entries, relax only the minimum level.  Impact, noise and equipment remain hard safety
  // constraints, and bodyweight still stays the baseline.
  const relaxed = HOME_LIBRARY.filter(item => item.objectives.includes(options.objective)
    && eligibleForKit(item, options.equipment)
    && (options.impact !== 'low' || item.impact === 'low')
    && (options.noise !== 'quiet' || item.noise === 'quiet'))
  return relaxed.length ? relaxed : HOME_LIBRARY.filter(item => item.kit === 'none' && item.impact === 'low' && item.noise === 'quiet')
}

function chooseMovements(pool, count, routineIndex, options, seed) {
  const order = FOCUS_ORDER[options.objective] || FOCUS_ORDER.strength
  const groups = order.map(focus => pool.filter(item => item.focus === focus))
  const rest = pool.filter(item => !order.includes(item.focus))
  const chosen = []
  const used = new Set()
  const offset = (hashSeed(seed) + routineIndex * 11) % Math.max(1, pool.length)
  let round = 0
  while (chosen.length < count && (chosen.length < pool.length || pool.length === 0)) {
    let added = false
    for (let groupIndex = 0; groupIndex < groups.length && chosen.length < count; groupIndex++) {
      const group = groups[groupIndex]
      if (!group.length) continue
      const item = group[(offset + round + groupIndex * 2) % group.length]
      if (used.has(item.id)) continue
      used.add(item.id); chosen.push(item); added = true
    }
    if (chosen.length >= count) break
    if (rest.length) {
      const item = rest[(offset + round) % rest.length]
      if (!used.has(item.id)) { used.add(item.id); chosen.push(item); added = true }
    }
    if (!added) break
    round++
  }
  // There are enough curated movements for normal plans, but a fallback keeps a plan usable if
  // EXDB is refreshed and a future catalogue accidentally drops one of them.
  if (chosen.length < count) {
    const fallback = pool.length ? pool : HOME_LIBRARY.filter(item => item.kit === 'none')
    for (let i = 0; chosen.length < count && fallback.length; i++) chosen.push(fallback[(offset + i) % fallback.length])
  }
  return chosen
}

function targetFor(item, options, position) {
  const rank = LEVEL_RANK[options.level] || 1
  const activeCardio = options.objective === 'active' && EXIDX.get(item.id)?.bp === 'cardio'
  if (options.objective === 'mobility') {
    return {
      id: item.id, sets: options.duration >= 30 ? 2 : 1,
      sec: 25 + rank * 5, mode: 'time', weight: 0, bodyweight: EXIDX.get(item.id)?.eq === 'body weight',
      homeEquipment: item.kit,
    }
  }
  if (activeCardio) {
    return {
      id: item.id, sets: 1, sec: options.duration >= 30 ? 40 : 30, mode: 'time', weight: 0,
      bodyweight: EXIDX.get(item.id)?.eq === 'body weight', homeEquipment: item.kit,
    }
  }
  const sets = options.objective === 'active' ? (rank >= 3 ? 3 : 2) : (rank === 1 ? 2 : rank === 2 ? 3 : 4)
  const reps = options.objective === 'active' ? 10 + rank * 2 : 8 + rank * 2 + (position % 2)
  return {
    id: item.id, sets, reps, weight: 0, mode: 'reps',
    bodyweight: EXIDX.get(item.id)?.eq === 'body weight', homeEquipment: item.kit,
  }
}

function objectiveLabel(objective) {
  return objective === 'active' ? 'Activa' : objective === 'mobility' ? 'Movilidad' : 'Fuerza'
}

function routineGlyph(objective) {
  return objective === 'active' ? 'figureRun' : objective === 'mobility' ? 'stretch' : 'figureStrength'
}

/**
 * Generate 2–4 app-native routines for a week.  The result is plain JSON-safe data: it can be
 * shown as a preview, filtered, serialized, or merged into the existing store without mutation.
 */
export function createHomePlan(options = {}) {
  const normalized = normalizeHomeOptions(options)
  const sessions = normalized.sessions || defaultSessionsFor(normalized.duration)
  const count = exercisesPerRoutineFor(normalized.duration)
  const pool = availableLibrary(normalized).filter(item => EXIDX.has(item.id))
  const seed = options?.seed ?? `${normalized.objective}-${normalized.duration}-${normalized.equipment}`
  const routines = Array.from({ length: sessions }, (_, routineIndex) => {
    const movements = chooseMovements(pool, count, routineIndex, normalized, seed)
    const letter = String.fromCharCode(65 + routineIndex)
    const ex = movements.map((item, position) => ({
      ...targetFor(item, normalized, position),
      // Keep a tiny amount of provenance with the routine; existing RoutineEdit/Workout fields
      // ignore these additive keys, while a future home-mode editor can explain substitutions.
      homeGuideSlug: item.guideSlug,
      homeImpact: item.impact,
      homeNoise: item.noise,
    }))
    return {
      id: uid(),
      name: `Casa · ${objectiveLabel(normalized.objective)} ${letter}`,
      emoji: routineGlyph(normalized.objective),
      ex,
      trainingPlace: 'home',
      homeMode: true,
      duration: normalized.duration,
      objective: normalized.objective,
      level: normalized.level,
      impact: normalized.impact,
      noise: normalized.noise,
      equipment: normalized.equipment,
      home: {
        duration: normalized.duration, objective: normalized.objective, level: normalized.level,
        impact: normalized.impact, noise: normalized.noise, equipment: normalized.equipment,
        session: routineIndex + 1,
      },
    }
  })
  return {
    id: uid(),
    generatedAt: new Date().toISOString(),
    ...normalized,
    sessions,
    routines,
  }
}

export const generateHomePlan = createHomePlan

/** Estimate the displayed duration without coupling the generator to a particular UI. */
export function estimatePlanMinutes(planOrOptions) {
  if (planOrOptions?.routines) {
    const routines = planOrOptions.routines.filter(Boolean)
    return routines.map(routine => Number(routine.duration) || Number(planOrOptions.duration) || 20)
  }
  const options = normalizeHomeOptions(planOrOptions)
  return Array.from({ length: options.sessions || defaultSessionsFor(options.duration) }, () => options.duration)
}

const clone = value => JSON.parse(JSON.stringify(value))
const uniqueId = (used, candidate) => {
  let id = candidate || uid()
  while (used.has(id)) id = uid()
  used.add(id)
  return id
}

/**
 * Merge a generated plan into a store draft.  Existing routines and weekly assignments are
 * retained byte-for-byte; new sessions occupy currently empty days only.  The caller normally
 * invokes this inside `useStore.getState().update(s => applyHomePlanToState(s, plan))`.
 */
export function applyHomePlanToState(S, plan, options = {}) {
  if (!S || typeof S !== 'object') throw new TypeError('A store state is required')
  const source = plan && typeof plan === 'object' ? plan : {}
  const inputRoutines = Array.isArray(source.routines) ? source.routines : []
  const removed = new Set(options.removedExerciseIds || source.removedExerciseIds || [])
  const routines = inputRoutines.map(routine => {
    const next = clone(routine)
    next.ex = (Array.isArray(next.ex) ? next.ex : []).filter(entry => !removed.has(entry.id))
    return next
  }).filter(routine => routine.ex.length)
  if (!routines.length) return { added: 0, scheduled: [], unscheduled: [], profile: null }

  S.routines = Array.isArray(S.routines) ? S.routines : []
  S.week = S.week && typeof S.week === 'object' ? S.week : {}
  const usedRoutineIds = new Set(S.routines.map(routine => routine?.id).filter(Boolean))
  const added = routines.map(routine => {
    const next = { ...routine, id: uniqueId(usedRoutineIds, routine.id) }
    next.ex = next.ex.map(entry => ({ ...entry }))
    S.routines.push(next)
    return next
  })

  // Home mode is a first-class place.  Reusing the shared helper creates/activates eq-home, then
  // we add only the concrete catalogue equipment required by this plan so Library/RoutineEdit
  // report a compatible profile immediately.
  const profile = applyTrainingPlace(S, 'home')
  if (profile) {
    const required = new Set(profile.equipment || [])
    added.forEach(routine => routine.ex.forEach(entry => {
      const ex = EXIDX.get(entry.id)
      if (ex?.eq && ex.eq !== 'body weight') required.add(ex.eq)
    }))
    profile.equipment = [...required]
  }

  // Monday, Wednesday, Friday, then the remaining days keeps a new plan predictable while
  // respecting any assignments the user already made. Object keys match the existing `S.week`
  // contract (0 = Sunday … 6 = Saturday).
  const preferredDays = [1, 3, 5, 0, 2, 4, 6]
  const freeDays = preferredDays.filter(day => !S.week[day] && !S.week[String(day)])
  const scheduled = []
  const unscheduled = []
  added.forEach((routine, index) => {
    const day = freeDays[index]
    if (day == null) { unscheduled.push(routine.id); return }
    S.week[day] = routine.id
    scheduled.push({ day, routineId: routine.id })
  })
  return { added: added.length, routineIds: added.map(routine => routine.id), scheduled, unscheduled, profile }
}

export const mergeHomePlan = applyHomePlanToState
export const saveHomePlan = applyHomePlanToState
