import { useSocial } from '../store/useSocial.js'

export default function SocialGame() {
  const { standings, profiles } = useSocial()
  const rows = standings.length ? standings : profiles.map((p, i) => ({ ...p, total_points: 0, position: i + 1 }))
  return <div className="social-page"><header className="social-head"><div><p className="eyebrow">TEMPORADA ACTUAL</p><h1>Juego</h1></div></header>
    <section className="season-hero"><span>🏆</span><div><small>LÍDER ACTUAL</small><h2>{rows[0]?.display_name || 'Sin líder'}</h2><p>{rows[0]?.total_points || 0} puntos</p></div></section>
    <section className="social-card"><div className="section-title"><h2>Tabla de temporada</h2></div>{rows.map((r, i) => <div className="rank-row" key={r.user_id || r.id}><span className={`rank-pos p${i + 1}`}>{r.position || i + 1}</span><span className="avatar">{r.display_name?.[0]}</span><div className="grow"><b>{r.display_name}</b><small>{i === 0 ? 'Defendiendo el primer lugar' : `${(rows[0]?.total_points || 0) - (r.total_points || 0)} pts del líder`}</small></div><strong>{r.total_points || 0} pts</strong></div>)}</section>
    <section className="social-card"><h2>Cómo sumar</h2><div className="reward-grid"><span>🥇 Día<b>10 pts</b></span><span>🏋️ Entreno<b>3 pts</b></span><span>🎯 Meta pasos<b>2 pts</b></span><span>🥗 Nutrición<b>2 pts</b></span></div></section>
  </div>
}
