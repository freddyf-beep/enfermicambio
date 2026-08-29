import { t } from './i18n.js'
import { EXDB } from './exercises-data.js'

// Every equipment value present in the catalogue, most common first — this becomes the
// checklist Settings shows when you build a profile.
export const ALL_EQUIPMENT = (() => {
  const c = {}
  EXDB.forEach(e => { if (e.eq) c[e.eq] = (c[e.eq] || 0) + 1 })
  return Object.keys(c).sort((a, b) => c[b] - c[a] || (a < b ? -1 : 1))
})()

export const TRAINING_PLACES = {
  home: { id: 'eq-home', name: 'Casa', equipment: [] },
  gym: { id: 'eq-gym', name: 'Gimnasio', equipment: ALL_EQUIPMENT },
}

export function applyTrainingPlace(S, place) {
  const preset = TRAINING_PLACES[place]
  if (!preset) return null
  S.equipProfiles = S.equipProfiles || []
  let profile = S.equipProfiles.find(item => item.kind === place || item.id === preset.id)
  if (!profile) {
    profile = { id: preset.id, kind: place, name: preset.name, equipment: [...preset.equipment] }
    S.equipProfiles.push(profile)
  } else if (!profile.kind) profile.kind = place
  S.trainingPlace = place
  S.activeEquipId = profile.id
  S.equipFilterOn = true
  return profile
}

// Body weight is never gated by a profile — no gym or home setup can take it away from you,
// and every profile should be able to see bodyweight exercises regardless of what's checked.
const ALWAYS_AVAILABLE = 'body weight'

// Curated from the existing visual catalogue. These movements need no dedicated gym
// machine; some use an ordinary chair, wall or towel as described in their guide.
const HOME_BY_TARGET = {
  pectorals: '0662',
  'upper back': '3167',
  lats: '1773',
  quads: '1685',
  glutes: '3013',
  hamstrings: '0730',
  calves: '1373',
  triceps: '0259',
  biceps: '1769',
  delts: '3662',
  abs: '0276',
  obliques: '0006',
  forearms: '1428',
}

const HOME_BY_BODY_PART = {
  chest: '0662', back: '3167', 'upper legs': '1685', 'lower legs': '1373',
  'upper arms': '0259', shoulders: '3662', waist: '0276',
}

const EXERCISE_BY_ID = new Map(EXDB.map(exercise => [exercise.id, exercise]))

export const HOME_REPERTOIRE = [...new Set([...Object.values(HOME_BY_TARGET), ...Object.values(HOME_BY_BODY_PART)])]
  .map(id => EXERCISE_BY_ID.get(id)).filter(Boolean)

export function homeReplacementFor(exercise) {
  if (!exercise || exercise.eq === ALWAYS_AVAILABLE) return null
  const id = HOME_BY_TARGET[exercise.tg] || HOME_BY_BODY_PART[exercise.bp]
  return id ? EXERCISE_BY_ID.get(id) || null : null
}

export function activeProfile(S) {
  if (!S.equipFilterOn) return null
  const profiles = S.equipProfiles || []
  return profiles.find(p => p.id === S.activeEquipId) || null
}

// Whether an exercise is usable under the active profile. With filtering off, or no profile
// selected, everything is available — this is purely additive, never a trap that hides your
// whole library because you haven't set anything up yet.
export function exAvailable(S, ex) {
  const p = activeProfile(S)
  if (!p) return true
  if (!ex.eq || ex.eq === ALWAYS_AVAILABLE) return true
  return (p.equipment || []).includes(ex.eq)
}

export function newProfile(name) {
  return { id: 'eq' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6), name, equipment: [] }
}
