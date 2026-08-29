import { useNavigate } from 'react-router-dom'
import { useSocial } from '../store/useSocial.js'
import Icon from '../components/Icon.jsx'

export default function SocialProfiles() {
  const nav = useNavigate()
  const { profiles, activity, profile, notifications, weightEntries, signOut, demo } = useSocial()
  const unread = notifications.filter(item => !item.is_read).length
  return <div className="social-page"><header className="social-head"><div><p className="eyebrow">EL EQUIPO</p><h1>Nosotros</h1></div></header>
    <div className="profile-grid">{profiles.map(p => { const a = activity.find(x => x.user_id === p.id) || {}; return <article className="profile-card" key={p.id}><span className="profile-avatar">{p.display_name?.[0]}</span><h2>{p.display_name}</h2><p>{Math.round(a.daily_steps || 0).toLocaleString('es-CL')} pasos hoy</p><div><span>{Math.round((a.distance_meters || 0) / 1000)} km</span><span>{Math.round(a.exercise_minutes || 0)} min</span></div></article> })}</div>
    <section className="social-card settings-list ec-profile-links">
      <button onClick={() => nav('/notifications')}><span><i><Icon name="bell" /></i>Notificaciones</span><em>{unread ? `${unread} nuevas` : <Icon name="chevronRight" />}</em></button>
      <button onClick={() => nav('/weight')}><span><i><Icon name="scale" /></i>Peso privado</span><em>{weightEntries[0] ? `${Number(weightEntries[0].weight_kg).toLocaleString('es-CL')} kg` : <Icon name="chevronRight" />}</em></button>
      <button onClick={() => nav('/install')}><span><i><Icon name="download" /></i>Instalar en este dispositivo</span><em><Icon name="chevronRight" /></em></button>
      <button onClick={() => nav('/health-import')}><span><i><Icon name="activity" /></i>Importación automática de salud</span><em><Icon name="chevronRight" /></em></button>
      <button onClick={() => nav('/settings')}><span><i><Icon name="gear" /></i>Preferencias de entrenamiento</span><em><Icon name="chevronRight" /></em></button>
      <button onClick={() => nav('/licenses')}><span><i><Icon name="clipboard" /></i>Licencias y atribución</span><em><Icon name="chevronRight" /></em></button>
      {!demo && profile && <button className="danger" onClick={signOut}><span><i><Icon name="signOut" /></i>Cerrar sesión</span><em><Icon name="chevronRight" /></em></button>}
    </section>
  </div>
}
