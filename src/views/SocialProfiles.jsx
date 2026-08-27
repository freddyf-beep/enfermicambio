import { useNavigate } from 'react-router-dom'
import { useSocial } from '../store/useSocial.js'

export default function SocialProfiles() {
  const nav = useNavigate()
  const { profiles, activity, profile, signOut, demo } = useSocial()
  return <div className="social-page"><header className="social-head"><div><p className="eyebrow">EL EQUIPO</p><h1>Nosotros</h1></div></header>
    <div className="profile-grid">{profiles.map(p => { const a = activity.find(x => x.user_id === p.id) || {}; return <article className="profile-card" key={p.id}><span className="profile-avatar">{p.display_name?.[0]}</span><h2>{p.display_name}</h2><p>{Math.round(a.daily_steps || 0).toLocaleString('es-CL')} pasos hoy</p><div><span>{Math.round((a.distance_meters || 0) / 1000)} km</span><span>{Math.round(a.exercise_minutes || 0)} min</span></div></article> })}</div>
    <section className="social-card settings-list"><button onClick={() => nav('/health-import')}>⚡ Importación automática de salud <span>›</span></button><button onClick={() => nav('/settings')}>⚙️ Preferencias de entrenamiento <span>›</span></button><button onClick={() => nav('/licenses')}>📄 Licencias y atribución <span>›</span></button>{!demo && profile && <button className="danger" onClick={signOut}>Cerrar sesión <span>›</span></button>}</section>
  </div>
}
