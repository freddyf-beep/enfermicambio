import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import Icon from '../components/Icon.jsx'
import { applyTrainingPlace } from '../lib/equipment.js'
import { effectiveRoutine } from '../lib/history.js'
import { todayISO } from '../lib/format.js'
import { useSocial } from '../store/useSocial.js'
import { useStore } from '../store/useStore.js'
import { equipmentProfileSheet, startFlow } from '../sheets.jsx'

const validHeight = value => Number(value) >= 100 && Number(value) <= 250
const validWeight = value => Number(value) >= 20 && Number(value) <= 400

function TrainingProfile({ onReady }) {
  const nutritionProfile = useSocial(state => state.nutritionProfile)
  const latestWeight = useSocial(state => state.weightEntries[0]?.weight_kg)
  const savePhysicalProfile = useSocial(state => state.savePhysicalProfile)
  const S = useStore(state => state.S)
  const update = useStore(state => state.update)
  const [height, setHeight] = useState(nutritionProfile?.height_cm || '')
  const [weight, setWeight] = useState(latestWeight || '')
  const [editing, setEditing] = useState(!validHeight(nutritionProfile?.height_cm) || !validWeight(latestWeight) || !S.trainingPlace)
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')

  const remoteHeight = nutritionProfile?.height_cm
  useEffect(() => { if (validHeight(remoteHeight)) setHeight(remoteHeight) }, [remoteHeight])
  useEffect(() => { if (validWeight(latestWeight)) setWeight(latestWeight) }, [latestWeight])

  const choosePlace = place => update(state => { applyTrainingPlace(state, place) })
  const currentProfile = (S.equipProfiles || []).find(profile => profile.id === S.activeEquipId)
  const ready = validHeight(height) && validWeight(weight) && Boolean(S.trainingPlace)
  const reveal = useCallback(() => { setEditing(true); setMessage('Completa tu altura, peso y lugar de entrenamiento antes de empezar.') }, [])

  useEffect(() => { onReady(ready, reveal) }, [ready, onReady, reveal])

  const save = async () => {
    if (!ready) { setMessage('Completa los tres datos para continuar.'); return }
    setBusy(true); setMessage('')
    try {
      await savePhysicalProfile(height, weight)
      setEditing(false)
      setMessage('Perfil guardado de forma privada.')
    } catch (error) { setMessage(error.message || 'No se pudo guardar el perfil.') }
    finally { setBusy(false) }
  }

  return <section className={`ec-training-profile ${ready ? 'ready' : 'needs-data'}`}>
    <div className="ec-training-profile-head"><span><Icon name={ready ? 'checkCircle' : 'personCircle'} /></span><div><p className="ec-kicker">Antes de entrenar</p><h2>{ready ? 'Tu perfil está listo' : 'Completa tu perfil'}</h2><p>{ready ? `${height} cm · ${Number(weight).toLocaleString('es-CL')} kg · ${S.trainingPlace === 'home' ? 'Casa' : 'Gimnasio'}` : 'La altura, el peso y el lugar ajustan tu experiencia y quedan vinculados a tu cuenta.'}</p></div><button onClick={() => setEditing(value => !value)}>{editing ? 'Cerrar' : 'Editar'}</button></div>
    {editing && <div className="ec-training-profile-form">
      <div className="ec-form-row"><label><span>Altura (cm)</span><input aria-label="Altura en centímetros" type="number" inputMode="numeric" min="100" max="250" value={height} onChange={event => setHeight(event.target.value)} /></label><label><span>Peso (kg)</span><input aria-label="Peso en kilogramos" type="number" inputMode="decimal" min="20" max="400" step="0.1" value={weight} onChange={event => setWeight(event.target.value)} /></label></div>
      <fieldset className="ec-place-picker"><legend>¿Dónde entrenas hoy?</legend><button type="button" className={S.trainingPlace === 'home' ? 'on' : ''} aria-pressed={S.trainingPlace === 'home'} onClick={() => choosePlace('home')}><Icon name="house" /><span><b>Casa</b><small>Peso corporal y tu equipo</small></span></button><button type="button" className={S.trainingPlace === 'gym' ? 'on' : ''} aria-pressed={S.trainingPlace === 'gym'} onClick={() => choosePlace('gym')}><Icon name="dumbbell" /><span><b>Gimnasio</b><small>Máquinas, barras y poleas</small></span></button></fieldset>
      {currentProfile && <button className="ec-secondary ec-configure-equipment" onClick={() => equipmentProfileSheet(currentProfile)}><Icon name="sliders" /> Configurar equipo de {currentProfile.name}</button>}
      <button className="ec-primary" disabled={!ready || busy} onClick={save}>{busy ? 'Guardando…' : 'Guardar perfil y continuar'}</button>
    </div>}
    {message && <div className="ec-profile-message" role="status">{message}</div>}
  </section>
}

export default function TrainingHub() {
  const nav = useNavigate()
  const S = useStore(state => state.S)
  const routine = effectiveRoutine(S, todayISO())
  const recent = S.workouts.filter(workout => Date.now() - new Date(workout.d).getTime() < 7 * 86400000).length
  const [profileGate, setProfileGate] = useState({ ready: false, reveal: () => {} })
  const receiveProfileState = useCallback((ready, reveal) => setProfileGate(current => current.ready === ready && current.reveal === reveal ? current : { ready, reveal }), [])
  const start = () => {
    if (!profileGate.ready) { profileGate.reveal(); return }
    if (S.active) nav('/workout')
    else if (routine) startFlow(routine.id)
    else nav('/workout')
  }
  const actions = [
    ['house', 'Modo Casa', 'Plan según tiempo, ruido y equipo', '/home-mode', 'lime'],
    ['calendar', 'Plan', 'Rutinas y semana', '/plan', 'lime'],
    ['magnifier', 'Ejercicios', 'Buscar y aprender', '/library', 'blue'],
    ['chartLine', 'Progreso', 'Fuerza y músculos', '/stats', 'violet'],
    ['history', 'Historial', 'Sesiones anteriores', '/history', 'coral'],
  ]

  return <div className="ec-page ec-training-page">
    <header className="ec-topbar"><div><p className="ec-kicker">Entrenamiento</p><h1>Muévete a tu manera</h1><p className="ec-subtitle">Tu plan, tus ejercicios y tu progreso comparten el mismo lugar.</p></div></header>
    <TrainingProfile onReady={receiveProfileState} />
    <section className="ec-training-main">
      <span className="ec-training-symbol"><Icon name={S.active ? 'activity' : 'dumbbell'} /></span>
      <div><p className="ec-kicker">{S.active ? 'Sesión en curso' : routine ? 'Rutina de hoy' : 'Empieza cuando quieras'}</p><h2>{S.active?.name || routine?.name || 'Entrenamiento libre'}</h2><p>{S.active ? 'Continúa exactamente donde quedaste.' : routine ? 'Tu rutina planificada está lista.' : 'Elige ejercicios sobre la marcha o carga un plan.'}</p></div>
      <button className="ec-primary" onClick={start}>{S.active ? 'Continuar sesión' : routine ? 'Empezar rutina' : 'Empezar libre'}</button>
      {!routine && !S.active && <button className="ec-text-button" onClick={() => nav('/plan')}>Prefiero preparar una rutina</button>}
    </section>
    <div className="ec-training-links">{actions.map(([icon, title, subtitle, to, tone]) => <button key={title} onClick={() => nav(to)}><span className={tone}><Icon name={icon} /></span><p><b>{title}</b><small>{subtitle}</small></p><Icon name="chevronRight" /></button>)}</div>
    <section className="ec-week-summary"><div><small>Últimos 7 días</small><strong>{recent}</strong><span>sesiones</span></div><div><small>Tu biblioteca</small><strong>{S.routines.length}</strong><span>rutinas</span></div><div><small>Histórico</small><strong>{S.workouts.length}</strong><span>entrenos</span></div></section>
  </div>
}
