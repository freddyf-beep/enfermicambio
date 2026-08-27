import { useNavigate } from 'react-router-dom'
import { useStore } from '../store/useStore.js'
import { startFlow } from '../sheets.jsx'
import { effectiveRoutine } from '../lib/history.js'
import { todayISO } from '../lib/format.js'

export default function TrainingHub() {
  const nav = useNavigate(); const S = useStore(s => s.S)
  const routine = effectiveRoutine(S, todayISO())
  const start = () => S.active ? nav('/workout') : routine ? startFlow(routine.id) : nav('/plan')
  return <div className="social-page"><header className="social-head"><div><p className="eyebrow">OPEN GYM × ENFERMICAMBIO</p><h1>Entrenar</h1></div></header>
    <section className="training-hero"><div><small>{S.active ? 'SESIÓN EN CURSO' : routine ? 'RUTINA DE HOY' : 'ENTRENAMIENTO LIBRE'}</small><h2>{S.active?.name || routine?.name || 'Prepara tu primera rutina'}</h2><p>{S.active ? 'Continúa donde quedaste.' : 'Series, repeticiones, peso, descanso y progresión.'}</p></div><button onClick={start}>{S.active ? 'Continuar' : 'Comenzar'}</button></section>
    <div className="action-grid"><button onClick={() => nav('/plan')}><b>📅 Plan</b><span>Rutinas y semana</span></button><button onClick={() => nav('/library')}><b>🏋️ Ejercicios</b><span>Catálogo visual</span></button><button onClick={() => nav('/stats')}><b>📈 Progreso</b><span>1RM, volumen y músculos</span></button><button onClick={() => nav('/history')}><b>🗓️ Historial</b><span>Sesiones anteriores</span></button></div>
    <section className="social-card"><h2>Esta semana</h2><div className="metric-row"><span><b>{S.workouts.filter(w => Date.now() - new Date(w.d).getTime() < 7 * 86400000).length}</b> sesiones</span><span><b>{S.routines.length}</b> rutinas</span><span><b>{S.workouts.length}</b> total</span></div></section>
  </div>
}
