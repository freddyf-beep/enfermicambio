import { useMemo, useState } from 'react'
import { useSocial } from '../store/useSocial.js'

export default function WeightLog() {
  const profile = useSocial(state => state.profile)
  const entries = useSocial(state => state.weightEntries)
  const saveWeight = useSocial(state => state.saveWeight)
  const [weight, setWeight] = useState(entries[0]?.weight_kg || '')
  const [goal, setGoal] = useState(profile?.weight_goal_kg || '')
  const [message, setMessage] = useState('')
  const ordered = useMemo(() => [...entries].sort((a, b) => a.entry_date.localeCompare(b.entry_date)), [entries])
  const first = ordered[0]?.weight_kg
  const latest = ordered.at(-1)?.weight_kg
  const delta = first != null && latest != null ? Number(latest) - Number(first) : 0
  const save = async () => { try { await saveWeight(weight, goal); setMessage('Peso y meta guardados de forma privada.') } catch (error) { setMessage(error.message) } }
  return <div className="social-page"><header className="social-head"><div><p className="eyebrow">SOLO TÚ</p><h1>Peso</h1></div></header>
    <section className="social-card weight-summary"><div><small>ÚLTIMO REGISTRO</small><strong>{latest != null ? `${Number(latest).toLocaleString('es-CL')} kg` : 'Sin datos'}</strong></div><div><small>CAMBIO</small><strong>{delta > 0 ? '+' : ''}{delta.toLocaleString('es-CL', { maximumFractionDigits: 2 })} kg</strong></div><div><small>META</small><strong>{profile?.weight_goal_kg ? `${Number(profile.weight_goal_kg).toLocaleString('es-CL')} kg` : 'Sin meta'}</strong></div></section>
    <section className="social-card"><h2>Registro de hoy</h2><div className="social-form grid-form"><label>Peso (kg)<input type="number" inputMode="decimal" min="20" max="400" step="0.1" value={weight} onChange={event => setWeight(event.target.value)} /></label><label>Meta (kg)<input type="number" inputMode="decimal" min="20" max="400" step="0.1" value={goal} onChange={event => setGoal(event.target.value)} /></label></div><button className="social-primary" disabled={!weight} onClick={save}>Guardar registro privado</button></section>
    <section className="social-card"><h2>Historial</h2><div className="weight-history">{[...entries].sort((a, b) => b.entry_date.localeCompare(a.entry_date)).map(item => <div key={item.id}><span>{new Date(`${item.entry_date}T12:00:00`).toLocaleDateString('es-CL', { day: 'numeric', month: 'short', year: 'numeric' })}</span><b>{Number(item.weight_kg).toLocaleString('es-CL')} kg</b></div>)}</div></section>
    {message && <div className="toast-inline">{message}</div>}
  </div>
}
