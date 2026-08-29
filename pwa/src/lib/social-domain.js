const timezone = () => import.meta.env.VITE_COMPETITION_TZ || 'America/Santiago'

export const rankingCategories = {
  daily_steps: { label: 'Pasos', shortLabel: 'Pasos', icon: 'figureRun', unit: 'pasos' },
  window_steps: { label: 'Pasos de la franja', shortLabel: 'Franja', icon: 'clock', unit: 'pasos' },
  active_calories: { label: 'Calorías activas', shortLabel: 'Kcal', icon: 'flame', unit: 'kcal' },
  distance_meters: { label: 'Distancia', shortLabel: 'Km', icon: 'route', unit: 'km' },
  workouts: { label: 'Entrenamientos', shortLabel: 'Entr.', icon: 'dumbbell', unit: 'sesiones' },
  points: { label: 'Puntos', shortLabel: 'Pts', icon: 'trophy', unit: 'pts' },
}

export const rankingPeriods = {
  today: 'Hoy',
  week: 'Semana',
  season: 'Temporada',
}

export function dateInCompetitionTimezone(value = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone(), year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(value)
}

export function rankingRange(period, activeSeason, now = new Date()) {
  const today = dateInCompetitionTimezone(now)
  if (period === 'season' && activeSeason) {
    return {
      start: dateInCompetitionTimezone(new Date(activeSeason.starts_at)),
      end: dateInCompetitionTimezone(new Date(activeSeason.ends_at)),
      startIso: activeSeason.starts_at,
      endExclusiveIso: activeSeason.ends_at,
    }
  }
  if (period === 'week') {
    const parts = today.split('-').map(Number)
    const localNoon = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2], 12))
    const weekday = new Intl.DateTimeFormat('en-US', { timeZone: timezone(), weekday: 'short' }).format(localNoon)
    const offset = { Mon: 0, Tue: 1, Wed: 2, Thu: 3, Fri: 4, Sat: 5, Sun: 6 }[weekday] ?? 0
    localNoon.setUTCDate(localNoon.getUTCDate() - offset)
    const start = dateInCompetitionTimezone(localNoon)
    return { start, end: today, startIso: zonedMidnightIso(start), endExclusiveIso: zonedMidnightIso(nextDay(today)) }
  }
  return { start: today, end: today, startIso: zonedMidnightIso(today), endExclusiveIso: zonedMidnightIso(nextDay(today)) }
}

function nextDay(day) {
  const [year, month, date] = day.split('-').map(Number)
  return new Date(Date.UTC(year, month - 1, date + 1)).toISOString().slice(0, 10)
}

function zonedMidnightIso(day) {
  const [year, month, date] = day.split('-').map(Number)
  const utcGuess = Date.UTC(year, month - 1, date)
  const parts = Object.fromEntries(new Intl.DateTimeFormat('en-US', {
    timeZone: timezone(), year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23',
  }).formatToParts(new Date(utcGuess)).filter(part => part.type !== 'literal').map(part => [part.type, part.value]))
  const representedAsUtc = Date.UTC(Number(parts.year), Number(parts.month) - 1, Number(parts.day), Number(parts.hour), Number(parts.minute), Number(parts.second))
  return new Date(utcGuess - (representedAsUtc - utcGuess)).toISOString()
}

function windowMetric(row, now = new Date()) {
  const hour = Number(new Intl.DateTimeFormat('en-US', {
    timeZone: timezone(), hour: '2-digit', hour12: false,
  }).format(now)) % 24
  if (hour >= 6 && hour < 12) return Number(row.morning_steps) || 0
  if (hour >= 12 && hour < 18) return Number(row.afternoon_steps) || 0
  if (hour >= 18) return Number(row.night_steps) || 0
  return Number(row.daily_steps) || 0
}

export function aggregateRanking({ profiles = [], activity = [], workouts = [], points = [], standings = [], category, now = new Date() }) {
  const values = Object.fromEntries(profiles.map(profile => [profile.id, 0]))
  const synced = {}
  for (const row of activity) {
    const id = row.user_id
    if (!(id in values)) values[id] = 0
    const metric = category === 'window_steps' ? windowMetric(row, now)
      : category === 'distance_meters' ? (Number(row.distance_meters) || 0) / 1000
      : ['daily_steps', 'active_calories'].includes(category) ? Number(row[category]) || 0
      : 0
    values[id] += metric
    if (row.synced_at && (!synced[id] || row.synced_at > synced[id])) synced[id] = row.synced_at
  }
  if (category === 'workouts') for (const row of workouts) values[row.user_id] = (values[row.user_id] || 0) + 1
  if (category === 'points') {
    const source = standings.length ? standings.map(row => ({ user_id: row.user_id, points: row.total_points })) : points
    for (const row of source) values[row.user_id] = (values[row.user_id] || 0) + (Number(row.points) || 0)
  }
  return profiles.map(profile => ({ ...profile, value: values[profile.id] || 0, synced_at: synced[profile.id] || null }))
    .sort((a, b) => b.value - a.value || String(a.display_name).localeCompare(String(b.display_name), 'es'))
    .map((row, index) => ({ ...row, position: index + 1 }))
}

export function missionProgress(mission, progressRows, userId) {
  const rows = progressRows.filter(row => row.mission_id === mission.id)
  const own = rows.find(row => row.user_id === userId)
  const group = rows.find(row => !row.user_id)
  const row = mission.mission_type === 'cooperative' ? group : own
  const progress = row?.progress || {}
  const current = Number(progress.current ?? progress.value ?? progress.count ?? 0)
  const target = Number(progress.target ?? mission.rules?.target ?? mission.rules?.threshold ?? 1) || 1
  return { current, target, completed: Boolean(row?.completed), ratio: Math.min(1, current / target) }
}

export function splitStorageReference(reference) {
  if (!reference || /^https?:\/\//i.test(reference)) return null
  const slash = reference.indexOf('/')
  if (slash < 1 || slash === reference.length - 1) return null
  return { bucket: reference.slice(0, slash), path: reference.slice(slash + 1) }
}

// Repair text stored as UTF-8 but decoded as Windows-1252/Latin-1. The legacy
// Flutter client applied the same fix at the boundary, so the PWA keeps old
// rows readable without rewriting the database.
const windows1252SpecialBytes = {
  0x20ac: 0x80, 0x201a: 0x82, 0x192: 0x83, 0x201e: 0x84, 0x2026: 0x85,
  0x2020: 0x86, 0x2021: 0x87, 0x2c6: 0x88, 0x2030: 0x89, 0x160: 0x8a,
  0x2039: 0x8b, 0x152: 0x8c, 0x17d: 0x8e, 0x2018: 0x91, 0x2019: 0x92,
  0x201c: 0x93, 0x201d: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97,
  0x2dc: 0x98, 0x2122: 0x99, 0x161: 0x9a, 0x203a: 0x9b, 0x153: 0x9c,
  0x17e: 0x9e, 0x178: 0x9f,
}

export function repairMojibake(value) {
  const text = String(value ?? '')
  if (!/[ÃÂâð]/.test(text)) return text
  try {
    const bytes = []
    for (const character of text) {
      const code = character.codePointAt(0)
      const byte = windows1252SpecialBytes[code] ?? (code <= 0xff ? code : null)
      if (byte == null) return text
      bytes.push(byte)
    }
    return new TextDecoder('utf-8', { fatal: true }).decode(new Uint8Array(bytes))
  } catch {
    return text
  }
}
