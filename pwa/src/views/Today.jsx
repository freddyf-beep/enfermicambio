import { useEffect, useMemo, useState } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import Icon from '../components/Icon.jsx'
import PulseCoach from '../components/PulseCoach.jsx'
import SocialPost from '../components/SocialPost.jsx'
import { useSocial } from '../store/useSocial.js'

const fmt = n => new Intl.NumberFormat('es-CL').format(Math.round(Number(n) || 0))
const fmtKcal = n => `${fmt(n)} kcal`
const ago = iso => {
  const min = Math.max(0, Math.round((Date.now() - new Date(iso).getTime()) / 60000))
  return min < 1 ? 'ahora' : min < 60 ? `hace ${min} min` : min < 1440 ? `hace ${Math.round(min / 60)} h` : `hace ${Math.round(min / 1440)} d`
}

const FEED_FILTERS = [
  ['all', 'Todo'],
  ['movement', 'Movimiento'],
  ['food', 'Comidas'],
  ['wins', 'Logros'],
]

const postGroup = type => type === 'meal' ? 'food'
  : ['workout', 'route', 'steps'].includes(type) ? 'movement'
    : ['achievement', 'mission', 'ranking_change', 'round_result', 'season'].includes(type) ? 'wins'
      : 'social'

function WeekPulse({ rows, goal }) {
  const recent = rows.slice(-7)
  const max = Math.max(goal, ...recent.map(row => Number(row.daily_steps) || 0), 1)
  return <div className="ec-week-pulse" aria-label="Pasos de los últimos siete días">
    {recent.map(row => {
      const day = new Date(`${row.activity_date}T12:00:00`)
      const label = day.toLocaleDateString('es-CL', { weekday: 'narrow' })
      const value = Number(row.daily_steps) || 0
      return <span key={row.activity_date} className={value >= goal ? 'goal' : ''} title={`${fmt(value)} pasos`}>
        <i><b style={{ height: `${Math.max(12, value / max * 100)}%` }} /></i><small>{label}</small>
      </span>
    })}
  </div>
}

export default function Today() {
  const nav = useNavigate()
  const location = useLocation()
  const { profile, profiles, activity, activityHistory, foodEntries, posts, notifications, demo, toggleReaction, addComment } = useSocial()
  const [message, setMessage] = useState('')
  const [feedFilter, setFeedFilter] = useState('all')
  const [showAll, setShowAll] = useState(false)
  const linkedPostId = location.state?.postId || new URLSearchParams(location.search).get('post')
  const [highlightedPost, setHighlightedPost] = useState(linkedPostId || null)
  const mine = activity.find(row => row.user_id === profile?.id) || {}
  const name = id => profiles.find(person => person.id === id)?.display_name || 'Integrante'
  const ranked = profiles.map(person => ({ ...person, ...(activity.find(row => row.user_id === person.id) || {}) }))
    .sort((a, b) => (b.daily_steps || 0) - (a.daily_steps || 0))
  const myPosition = ranked.findIndex(row => row.id === profile?.id) + 1 || 1
  const goal = Number(profile?.daily_step_target) || 10000
  const progress = Math.min(100, (Number(mine.daily_steps) || 0) / goal * 100)
  const stepsLeft = Math.max(0, goal - (Number(mine.daily_steps) || 0))
  const unread = notifications.filter(item => !item.is_read).length
  const consumed = foodEntries.reduce((total, entry) => total + (Number(entry.calories) || 0), 0)
  const calorieGoal = Number(profile?.daily_calorie_target) || 2200
  const remaining = Math.max(0, calorieGoal - consumed)
  const macros = foodEntries.reduce((total, entry) => ({
    protein: total.protein + (Number(entry.protein_g) || 0),
    carbs: total.carbs + (Number(entry.carbs_g) || 0),
    fat: total.fat + (Number(entry.fat_g) || 0),
  }), { protein: 0, carbs: 0, fat: 0 })
  const coachState = progress >= 100 ? 'celebrate' : progress >= 75 ? 'close' : consumed > 0 ? 'food' : 'ready'
  const coachMessage = progress >= 100 ? 'Hoy ya cumpliste. Lo demás es bonus.'
    : stepsLeft > 0 ? `${fmt(stepsLeft)} pasos y cerramos la meta.` : 'Tu día está en marcha.'
  const filteredPosts = useMemo(() => feedFilter === 'all' ? posts : posts.filter(post => postGroup(post.post_type) === feedFilter), [feedFilter, posts])
  const visiblePosts = showAll ? filteredPosts : filteredPosts.slice(0, 4)
  const quickActions = [
    ['dumbbell', 'Entrenar', '/train'],
    ['house', 'Modo Casa', '/home-mode'],
    ['food', 'Comida', '/register?mode=meal'],
    ['camera', 'Publicar', '/register?mode=post'],
  ]

  useEffect(() => {
    const postId = location.state?.postId || new URLSearchParams(location.search).get('post')
    if (!postId || !posts.some(post => post.id === postId)) return undefined
    setFeedFilter('all')
    setShowAll(true)
    setHighlightedPost(postId)
    const scrollTimer = window.setTimeout(() => document.getElementById(`post-${postId}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' }), 80)
    const highlightTimer = window.setTimeout(() => setHighlightedPost(null), 2600)
    return () => { window.clearTimeout(scrollTimer); window.clearTimeout(highlightTimer) }
  }, [location.state, location.search, posts])

  return <main className="ec-page ec-today-native">
    <header className="ec-native-head">
      <div><p>{new Date().toLocaleDateString('es-CL', { weekday: 'long', day: 'numeric', month: 'long' })}</p><h1>Hola, {profile?.display_name?.split(' ')[0] || 'equipo'}</h1></div>
      <button className="ec-icon-button ec-bell-button" onClick={() => nav('/notifications')} aria-label={unread ? `Notificaciones, ${unread} sin leer` : 'Notificaciones'}><Icon name="bell" />{unread > 0 && <span>{unread > 9 ? '9+' : unread}</span>}</button>
    </header>

    {demo && <div className="ec-demo-ribbon">Vista de demostración</div>}

    <section className="ec-day-stage" aria-label="Tu progreso de hoy">
      <div className="ec-stage-copy"><span>Pasos</span><strong>{fmt(mine.daily_steps)}</strong><p>Meta {fmt(goal)} · puesto #{myPosition}</p></div>
      <div className="ec-step-orbit" style={{ '--day-progress': `${progress * 3.6}deg` }} aria-label={`${Math.round(progress)} por ciento de la meta`}>
        <div><b>{Math.round(progress)}%</b><small>hoy</small></div>
      </div>
      <PulseCoach state={coachState} message={coachMessage} />
      <WeekPulse rows={activityHistory.length ? activityHistory : mine.activity_date ? [mine] : []} goal={goal} />
      <button className="ec-sync-line" onClick={() => nav('/health-import')}><Icon name="refresh" /><span>{mine.synced_at ? `Salud actualizada ${ago(mine.synced_at)}` : 'Conectar los datos de salud'}</span><Icon name="chevronRight" /></button>
    </section>

    <nav className="ec-action-dock" aria-label="Acciones del día">
      {quickActions.map(([icon, label, to]) => <button key={label} onClick={() => nav(to)}><span><Icon name={icon} /></span><small>{label}</small></button>)}
    </nav>

    <section className="ec-energy-section">
      <div className="ec-native-section-head"><div><span>Energía</span><h2>Lo que comiste hoy</h2></div><button onClick={() => nav('/register?mode=meal')}><Icon name="plus" /> Añadir</button></div>
      <button className="ec-energy-main" onClick={() => nav('/register?mode=meal')}>
        <span className="ec-energy-ring" style={{ '--energy-progress': `${Math.min(100, consumed / calorieGoal * 100) * 3.6}deg` }}><Icon name="food" /></span>
        <p><strong>{fmtKcal(consumed)}</strong><small>de {fmtKcal(calorieGoal)} · {fmtKcal(remaining)} disponibles</small></p>
        <Icon name="chevronRight" />
      </button>
      <div className="ec-energy-details"><span><b>{fmt(mine.active_calories)}</b><small>kcal activas</small></span><span><b>{fmt(macros.protein)} g</b><small>proteína</small></span><span><b>{fmt(foodEntries.length)}</b><small>registros</small></span></div>
    </section>

    <section className="ec-team-ribbon">
      <div className="ec-native-section-head"><div><span>EnfermiCambio</span><h2>El equipo ahora</h2></div><button onClick={() => nav('/ranking')}>Ver ranking</button></div>
      <div>{ranked.map((row, index) => <button key={row.id} className={row.id === profile?.id ? 'mine' : ''} onClick={() => nav('/ranking')}>
        <span className="ec-team-place">{index + 1}</span><span className="ec-avatar">{row.display_name?.[0]}</span><p><b>{row.id === profile?.id ? 'Tú' : row.display_name}</b><small>{fmt(row.daily_steps)}</small></p>
      </button>)}</div>
    </section>

    <section className="ec-native-feed">
      <div className="ec-native-section-head"><div><span>Actividad</span><h2>Entre nosotros</h2></div><button onClick={() => nav('/register?mode=post')}><Icon name="plus" /> Publicar</button></div>
      <div className="ec-feed-tabs" role="tablist" aria-label="Filtrar actividad">{FEED_FILTERS.map(([key, label]) => <button key={key} role="tab" aria-selected={feedFilter === key} className={feedFilter === key ? 'on' : ''} onClick={() => { setFeedFilter(key); setShowAll(false) }}>{label}</button>)}</div>
      <div className="ec-feed">{visiblePosts.length ? visiblePosts.map(post => <SocialPost key={post.id} post={post} authorName={name(post.author_id)} currentUserId={profile?.id} nameFor={name} ago={ago} onReact={toggleReaction} onComment={addComment} onError={setMessage} highlighted={highlightedPost === post.id} />) : <div className="ec-feed-empty"><PulseCoach compact state="rest" /><b>Aquí todavía no pasa nada</b><span>Cambia el filtro o comparte la primera actividad.</span></div>}</div>
      {filteredPosts.length > 4 && <button className="ec-feed-more" onClick={() => setShowAll(value => !value)}>{showAll ? 'Ver menos' : `Ver ${filteredPosts.length - 4} más`}<Icon name={showAll ? 'chevronUp' : 'chevronDown'} /></button>}
    </section>
    {message && <div className="toast-inline">{message}</div>}
  </main>
}
