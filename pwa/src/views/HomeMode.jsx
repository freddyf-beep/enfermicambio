import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import Icon from '../components/Icon.jsx'
import { exerciseNameFor } from '../lib/i18n.js'
import { useStore } from '../store/useStore.js'
import {
  HOME_DEFAULTS,
  HOME_DURATIONS,
  HOME_OBJECTIVES,
  HOME_LEVELS,
  HOME_IMPACTS,
  HOME_NOISES,
  HOME_EQUIPMENT,
  applyHomePlanToState,
  createHomePlan,
  getHomeExercise,
  guideAssetFor,
  normalizeHomeOptions,
  estimatePlanMinutes,
} from '../lib/home-plan.js'
import '../home-mode.css'

const OBJECTIVE_COPY = {
  strength: { label: 'Fuerza', hint: 'Control y progresión', icon: 'figureStrength' },
  active: { label: 'Activo', hint: 'Ritmo y energía', icon: 'figureRun' },
  mobility: { label: 'Movilidad', hint: 'Moverte mejor', icon: 'stretch' },
}
const LEVEL_COPY = {
  beginner: { label: 'Inicial', hint: 'Empiezo con calma' },
  intermediate: { label: 'Intermedio', hint: 'Ya tengo base' },
  advanced: { label: 'Avanzado', hint: 'Quiero un reto' },
}
const IMPACT_COPY = {
  low: { label: 'Bajo', hint: 'Sin saltos', icon: 'moon' },
  high: { label: 'Libre', hint: 'También saltos', icon: 'bolt' },
}
const NOISE_COPY = {
  quiet: { label: 'Silencioso', hint: 'Vecinos tranquilos', icon: 'moon' },
  normal: { label: 'Normal', hint: 'Puedo hacer ruido', icon: 'activity' },
}
const EQUIPMENT_COPY = {
  none: { label: 'Ninguno', hint: 'Solo tu cuerpo', icon: 'person' },
  chair: { label: 'Silla', hint: 'Una silla estable', icon: 'chair' },
  band: { label: 'Banda', hint: 'Banda elástica', icon: 'link' },
  dumbbells: { label: 'Mancuernas', hint: 'Un par de pesas', icon: 'dumbbell' },
}
const DAY_NAMES = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb']
const HOME_EXERCISE_NAMES = {
  'push-up': 'Flexión de brazos', 'incline-push-up': 'Flexión inclinada', 'wall-push-up': 'Flexión en pared',
  squat: 'Sentadilla', 'glute-bridge': 'Puente de glúteos', 'glute-bridge-march': 'Puente con marcha',
  'walking-lunge': 'Zancadas caminando', 'split-squat': 'Sentadilla dividida', 'standing-calf-raise': 'Elevación de pantorrillas',
  'dead-bug': 'Dead bug', 'russian-twist': 'Giro ruso', 'side-plank': 'Plancha lateral', plank: 'Plancha',
  'towel-row': 'Remo con toalla', 'bench-dip': 'Fondos en silla', 'captains-chair-knee-raise': 'Elevación de rodillas',
  'mountain-climber': 'Escaladores', 'worlds-greatest-stretch': 'Estiramiento completo', 'hamstring-stretch': 'Estiramiento de isquiotibiales',
  'doorway-chest-stretch': 'Apertura de pecho', 'standing-quad-stretch': 'Estiramiento de cuádriceps', 'seated-forward-fold-stretch': 'Flexión sentada',
  burpee: 'Burpee', 'jumping-jack': 'Saltos de tijera', 'skater-hop': 'Saltos de patinador',
  'banded-squat': 'Sentadilla con banda', 'banded-row': 'Remo con banda', 'banded-face-pull': 'Face pull con banda',
  'banded-push-up': 'Flexión con banda', 'band-pull-apart': 'Apertura con banda', 'banded-glute-bridge': 'Puente con banda',
  'banded-split-squat': 'Sentadilla dividida con banda', 'banded-dead-bug': 'Dead bug con banda', 'banded-pallof-press': 'Press Pallof con banda',
  'bicep-curl': 'Curl de bíceps', 'tricep-kickback': 'Extensión de tríceps', 'goblet-squat': 'Sentadilla goblet',
  'dumbbell-romanian-deadlift': 'Peso muerto rumano', 'dumbbell-bent-over-row': 'Remo con mancuernas', 'hammer-curl': 'Curl martillo',
  'arnold-press': 'Press Arnold', 'lateral-raise': 'Elevación lateral', 'dumbbell-side-bend': 'Flexión lateral con mancuerna',
}
const homeExerciseName = exercise => HOME_EXERCISE_NAMES[exercise?.guideSlug] || (exercise ? exerciseNameFor(exercise) : 'Ejercicio')

function baseUrl() {
  const raw = import.meta.env?.BASE_URL || '/'
  return raw.endsWith('/') ? raw : `${raw}/`
}

function fmtEntry(entry) {
  if (entry.mode === 'time') return `${entry.sets || 1} × ${entry.sec || 30} s`
  return `${entry.sets || 1} × ${entry.reps || 10}`
}

function EquipmentIcon({ name }) {
  // `chair` is intentionally drawn with the familiar home glyph until a dedicated chair icon
  // is added to the shared set; this keeps the option visually complete without a new global icon.
  return <Icon name={name === 'chair' ? 'house' : name} />
}

function OptionButton({ selected, onClick, icon, label, hint, className = '' }) {
  return <button type="button" className={`ec-home-choice ${selected ? 'is-selected' : ''} ${className}`}
    aria-pressed={selected} onClick={onClick}>
    {icon && <span className="ec-home-choice-icon"><EquipmentIcon name={icon} /></span>}
    <span><b>{label}</b>{hint && <small>{hint}</small>}</span>
    {selected && <Icon name="checkCircle" className="ec-home-choice-check" />}
  </button>
}

function AnimatedGuide({ exercise }) {
  const slug = exercise?.guideSlug || exercise?.homeGuideSlug
  const [frame, setFrame] = useState(1)
  const [failed, setFailed] = useState(false)
  useEffect(() => {
    setFrame(1); setFailed(false)
    if (!slug) return undefined
    const timer = window.setInterval(() => setFrame(value => value === 3 ? 1 : value + 1), 760)
    return () => window.clearInterval(timer)
  }, [slug])
  if (!slug || failed) return <span className="ec-home-media-fallback"><Icon name="figureStrength" /></span>
  const path = guideAssetFor({ guideSlug: slug }, frame)
  return <span className="ec-home-media"><img src={`${baseUrl()}${path}`} alt="" loading="lazy" decoding="async" onError={() => setFailed(true)} /></span>
}

function ScheduleHint({ week, sessions }) {
  const keys = [1, 3, 5, 0, 2, 4, 6]
  const free = keys.filter(day => !week?.[day] && !week?.[String(day)])
  if (free.length < sessions) return <p className="ec-home-schedule-hint"><Icon name="calendar" /> Tu semana está llena; las rutinas quedarán guardadas para asignarlas después.</p>
  return <p className="ec-home-schedule-hint"><Icon name="calendar" /> Se propondrán {free.slice(0, sessions).map(day => DAY_NAMES[day]).join(' · ')}. Tus días actuales no cambian.</p>
}

function HomeRoutineCard({ routine, routineIndex, onRemove }) {
  const entries = Array.isArray(routine.ex) ? routine.ex : []
  return <article className={`ec-home-routine ${entries.length ? '' : 'is-empty'}`}>
    <header className="ec-home-routine-head">
      <div><span className="ec-home-routine-index">{String(routineIndex + 1).padStart(2, '0')}</span><div><p>Sesión {routineIndex + 1}</p><h3>{routine.name.replace(/^Casa · /, '')}</h3></div></div>
      <span className="ec-home-routine-time"><Icon name="timer" /> {routine.duration || 20} min</span>
    </header>
    <div className="ec-home-exercises">
      {entries.map((entry, index) => {
        const exercise = getHomeExercise(entry.id)
        const name = homeExerciseName(exercise)
        return <div className="ec-home-exercise" key={`${entry.id}-${index}`}>
          <AnimatedGuide exercise={{ ...exercise, homeGuideSlug: entry.homeGuideSlug }} />
          <div className="ec-home-exercise-copy"><b>{name}</b><span>{fmtEntry(entry)}{entry.homeEquipment !== 'none' && ` · ${EQUIPMENT_COPY[entry.homeEquipment]?.label || entry.homeEquipment}`}</span></div>
          <button type="button" className="ec-home-remove" aria-label={`Quitar ${name}`} onClick={() => onRemove(routine.id, entry.id)}><Icon name="xmark" /></button>
        </div>
      })}
      {!entries.length && <div className="ec-home-empty-routine"><Icon name="dumbbell" /><span>Sesión vacía: puedes quitarla o regenerar el plan.</span></div>}
    </div>
  </article>
}

export default function HomeMode({ onSaved }) {
  const nav = useNavigate()
  const S = useStore(state => state.S)
  const update = useStore(state => state.update)
  const [options, setOptions] = useState({ ...HOME_DEFAULTS })
  const [plan, setPlan] = useState(() => createHomePlan(HOME_DEFAULTS))
  const [notice, setNotice] = useState('')
  const [saving, setSaving] = useState(false)
  const normalized = useMemo(() => normalizeHomeOptions(options), [options])
  const minutes = useMemo(() => estimatePlanMinutes(plan), [plan])
  const activeProfile = (S.equipProfiles || []).find(profile => profile.id === S.activeEquipId)

  const choose = (key, value) => {
    const next = normalizeHomeOptions({ ...options, [key]: value })
    setOptions(next)
    setPlan(createHomePlan(next))
    setNotice('')
  }

  const removeExercise = (routineId, exerciseId) => {
    setPlan(current => ({
      ...current,
      routines: current.routines.map(routine => routine.id === routineId
        ? { ...routine, ex: routine.ex.filter(entry => entry.id !== exerciseId) }
        : routine),
    }))
    setNotice('Ejercicio quitado de la vista previa.')
  }

  const regenerate = () => {
    setPlan(createHomePlan(options))
    setNotice('Plan actualizado con tus preferencias.')
  }

  const save = () => {
    if (saving) return
    if (!plan.routines.some(routine => routine.ex?.length)) {
      setNotice('Deja al menos un ejercicio para guardar el plan.')
      return
    }
    setSaving(true); setNotice('')
    let result
    try {
      update(state => { result = applyHomePlanToState(state, plan) })
      const scheduled = result?.scheduled?.length || 0
      const unscheduled = result?.unscheduled?.length || 0
      setNotice(unscheduled ? `Guardado: ${result.added} rutinas. ${scheduled} asignadas; ${unscheduled} esperan un día libre.` : `Guardado: ${result?.added || plan.routines.length} rutinas añadidas a tu semana.`)
      onSaved?.(result)
      window.setTimeout(() => nav('/plan'), 500)
    } catch (error) {
      setNotice(error?.message || 'No se pudo guardar el plan.')
      setSaving(false)
    }
  }

  return <main className="ec-page ec-home-mode">
    <header className="ec-home-header">
      <button type="button" className="ec-home-back" onClick={() => nav(-1)} aria-label="Volver"><Icon name="chevronLeft" /></button>
      <div><p className="ec-home-eyebrow"><Icon name="house" /> Entrenamiento en casa</p><h1>Modo Casa</h1><p>Un plan que cabe en tu espacio y en tu día.</p></div>
      <span className="ec-home-header-mark"><Icon name="sparkles" /></span>
    </header>

    <section className="ec-home-hero">
      <div className="ec-home-hero-orbit"><Icon name="house" /><span /></div>
      <div><p className="ec-home-eyebrow">Tu espacio, tu ritmo</p><h2>Entrena sin salir</h2><p>Elige lo esencial. Nosotros ordenamos una semana clara, silenciosa y lista para empezar.</p></div>
    </section>

    <section className="ec-home-section">
      <div className="ec-home-section-title"><span className="ec-home-step">01</span><div><p>Tiempo disponible</p><h2>¿Cuánto tienes?</h2></div><strong>{normalized.duration} min</strong></div>
      <div className="ec-home-duration" role="group" aria-label="Duración del entrenamiento">
        {HOME_DURATIONS.map(duration => <button type="button" key={duration} aria-pressed={normalized.duration === duration} className={normalized.duration === duration ? 'is-selected' : ''} onClick={() => choose('duration', duration)}><b>{duration}</b><small>min</small></button>)}
      </div>
    </section>

    <section className="ec-home-section">
      <div className="ec-home-section-title"><span className="ec-home-step">02</span><div><p>Intención</p><h2>¿Qué quieres sentir?</h2></div></div>
      <div className="ec-home-choice-grid ec-home-choice-grid-3">
        {HOME_OBJECTIVES.map(value => { const copy = OBJECTIVE_COPY[value]; return <OptionButton key={value} selected={normalized.objective === value} onClick={() => choose('objective', value)} icon={copy.icon} label={copy.label} hint={copy.hint} /> })}
      </div>
    </section>

    <section className="ec-home-section">
      <div className="ec-home-section-title"><span className="ec-home-step">03</span><div><p>Ajuste personal</p><h2>Hazlo tuyo</h2></div></div>
      <div className="ec-home-subsection"><div className="ec-home-label"><Icon name="target" /><span>Nivel</span></div><div className="ec-home-choice-grid ec-home-choice-grid-3">{HOME_LEVELS.map(value => { const copy = LEVEL_COPY[value]; return <OptionButton key={value} selected={normalized.level === value} onClick={() => choose('level', value)} label={copy.label} hint={copy.hint} /> })}</div></div>
      <div className="ec-home-subsection"><div className="ec-home-label"><Icon name="bolt" /><span>Impacto</span></div><div className="ec-home-choice-grid ec-home-choice-grid-2">{HOME_IMPACTS.map(value => { const copy = IMPACT_COPY[value]; return <OptionButton key={value} selected={normalized.impact === value} onClick={() => choose('impact', value)} icon={copy.icon} label={copy.label} hint={copy.hint} /> })}</div></div>
      <div className="ec-home-subsection"><div className="ec-home-label"><Icon name="moon" /><span>Ruido</span></div><div className="ec-home-choice-grid ec-home-choice-grid-2">{HOME_NOISES.map(value => { const copy = NOISE_COPY[value]; return <OptionButton key={value} selected={normalized.noise === value} onClick={() => choose('noise', value)} icon={copy.icon} label={copy.label} hint={copy.hint} /> })}</div></div>
      <div className="ec-home-subsection"><div className="ec-home-label"><Icon name="dumbbell" /><span>Equipo</span></div><div className="ec-home-choice-grid ec-home-choice-grid-2">{HOME_EQUIPMENT.map(value => { const copy = EQUIPMENT_COPY[value]; return <OptionButton key={value} selected={normalized.equipment === value} onClick={() => choose('equipment', value)} icon={copy.icon} label={copy.label} hint={copy.hint} /> })}</div></div>
    </section>

    <section className="ec-home-preview-section">
      <div className="ec-home-preview-head"><div><p className="ec-home-eyebrow">Vista previa</p><h2>Tu semana en casa</h2><p>{plan.routines.length} sesiones · {minutes.join(' / ')} min · {activeProfile?.name || 'perfil de casa al guardar'}</p></div><button type="button" className="ec-home-refresh" onClick={regenerate} aria-label="Regenerar plan"><Icon name="refresh" /></button></div>
      <ScheduleHint week={S.week} sessions={plan.routines.length} />
      <div className="ec-home-routines">{plan.routines.map((routine, index) => <HomeRoutineCard key={routine.id} routine={routine} routineIndex={index} onRemove={removeExercise} />)}</div>
      <p className="ec-home-preview-note"><Icon name="info" /> Puedes quitar ejercicios antes de guardar. Nada de tu plan actual se reemplaza.</p>
    </section>

    {notice && <p className="ec-home-notice" role="status"><Icon name={notice.startsWith('Guardado') ? 'checkCircle' : 'info'} />{notice}</p>}
    <div className="ec-home-actions"><button type="button" className="ec-home-primary" disabled={saving} onClick={save}><Icon name={saving ? 'timer' : 'checkCircle'} />{saving ? 'Guardando…' : 'Guardar plan en mi semana'}</button><button type="button" className="ec-home-secondary" onClick={() => nav('/train')}>Volver a Entrenamiento</button></div>
  </main>
}
