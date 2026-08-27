import { useState } from 'react'
import { useSocial } from '../store/useSocial.js'

const categories = {
  daily_steps: ['Pasos', 'pasos'], active_calories: ['Calorías', 'kcal'],
  distance_meters: ['Distancia', 'm'], exercise_minutes: ['Ejercicio', 'min'],
}
export default function SocialRanking() {
  const { profiles, activity } = useSocial()
  const [category, setCategory] = useState('daily_steps')
  const rows = profiles.map(p => ({ ...p, ...(activity.find(a => a.user_id === p.id) || {}) }))
    .sort((a, b) => (b[category] || 0) - (a[category] || 0))
  return <div className="social-page"><header className="social-head"><div><p className="eyebrow">COMPETENCIA</p><h1>Ranking</h1></div></header>
    <div className="segment-scroll">{Object.entries(categories).map(([key, [label]]) => <button key={key} className={category === key ? 'active' : ''} onClick={() => setCategory(key)}>{label}</button>)}</div>
    <section className="podium">{rows.slice(0, 3).map((r, i) => <div className={`podium-person place-${i + 1}`} key={r.id}><span className="podium-avatar">{r.display_name?.[0]}</span><b>{r.display_name}</b><strong>{Math.round(r[category] || 0).toLocaleString('es-CL')}</strong><small>{categories[category][1]}</small></div>)}</section>
    <section className="social-card rank-list">{rows.map((r, i) => <div className="rank-row" key={r.id}><span className={`rank-pos p${i + 1}`}>{i + 1}</span><span className="avatar">{r.display_name?.[0]}</span><div className="grow"><b>{r.display_name}</b><small>{r.synced_at ? new Date(r.synced_at).toLocaleTimeString('es-CL', { hour: '2-digit', minute: '2-digit' }) : 'Sin datos'}</small></div><strong>{Math.round(r[category] || 0).toLocaleString('es-CL')}</strong></div>)}</section>
  </div>
}
