import { useSocial } from '../store/useSocial.js'

const fmt = n => new Intl.NumberFormat('es-CL').format(Math.round(Number(n) || 0))
const ago = iso => {
  const min = Math.max(0, Math.round((Date.now() - new Date(iso).getTime()) / 60000))
  return min < 1 ? 'ahora' : min < 60 ? `hace ${min} min` : `hace ${Math.round(min / 60)} h`
}

export default function Today() {
  const { profile, profiles, activity, posts, demo, refresh } = useSocial()
  const mine = activity.find(x => x.user_id === profile?.id) || {}
  const name = id => profiles.find(p => p.id === id)?.display_name || 'Integrante'
  const ranked = profiles.map(p => ({ ...p, ...(activity.find(a => a.user_id === p.id) || {}) }))
    .sort((a, b) => (b.daily_steps || 0) - (a.daily_steps || 0))
  return <div className="social-page">
    <header className="social-head"><div><p className="eyebrow">HOY</p><h1>Hola, {profile?.display_name || 'equipo'}</h1></div><button className="round-button" onClick={refresh}>↻</button></header>
    {demo && <div className="demo-banner">Modo demostración · agrega las variables de Supabase para usar datos reales.</div>}
    <section className="hero-score">
      <div><span className="hero-number">{fmt(mine.daily_steps)}</span><span className="hero-unit">pasos</span></div>
      <div className="hero-progress"><span style={{ width: `${Math.min(100, (mine.daily_steps || 0) / (profile?.daily_step_target || 10000) * 100)}%` }} /></div>
      <div className="metric-row">
        <span><b>{fmt(mine.active_calories)}</b> kcal activas</span>
        <span><b>{fmt((mine.distance_meters || 0) / 1000)}</b> km</span>
        <span><b>{fmt(mine.exercise_minutes)}</b> min</span>
      </div>
    </section>
    <section className="social-card">
      <div className="section-title"><h2>Ranking en vivo</h2><a href="#/ranking">Ver todo</a></div>
      <div className="rank-list">{ranked.map((row, i) => <div className="rank-row" key={row.id}>
        <span className={`rank-pos p${i + 1}`}>{i + 1}</span><span className="avatar">{row.display_name?.[0]}</span>
        <div className="grow"><b>{row.display_name}</b><small>{row.synced_at ? ago(row.synced_at) : 'sin sincronizar'}</small></div>
        <strong>{fmt(row.daily_steps)}</strong>
      </div>)}</div>
    </section>
    <section className="social-card">
      <div className="section-title"><h2>Actividad del grupo</h2></div>
      <div className="feed-list">{posts.length ? posts.map(post => <article className="feed-item" key={post.id}>
        <span className="avatar">{name(post.author_id)[0]}</span><div><p><b>{name(post.author_id)}</b> {post.caption}</p><small>{ago(post.created_at)}</small></div>
      </article>) : <div className="empty-state">Todavía no hay publicaciones.</div>}</div>
    </section>
  </div>
}
