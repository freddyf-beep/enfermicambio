import { useEffect, useState } from 'react'
import Icon from '../components/Icon.jsx'
import { rankingCategories, rankingPeriods } from '../lib/social-domain.js'
import { useSocial } from '../store/useSocial.js'

const formatValue = (value, category) => category === 'distance_meters'
  ? Number(value || 0).toLocaleString('es-CL', { maximumFractionDigits: 1 })
  : Math.round(Number(value) || 0).toLocaleString('es-CL')

export default function SocialRanking() {
  const rows = useSocial(state => state.rankingRows)
  const loading = useSocial(state => state.rankingLoading)
  const error = useSocial(state => state.error)
  const loadRanking = useSocial(state => state.loadRanking)
  const [category, setCategory] = useState('daily_steps')
  const [period, setPeriod] = useState('today')

  useEffect(() => { loadRanking(category, period) }, [category, period, loadRanking])
  const meta = rankingCategories[category]
  return <div className="social-page">
    <header className="social-head"><div><p className="eyebrow">COMPETENCIA</p><h1>Ranking</h1></div>{loading && <span className="live-pill">Actualizando</span>}</header>
    <div className="segment-scroll period-tabs" role="tablist" aria-label="Período del ranking">{Object.entries(rankingPeriods).map(([key, label]) => <button role="tab" aria-selected={period === key} key={key} className={period === key ? 'active' : ''} onClick={() => setPeriod(key)}>{label}</button>)}</div>
    <div className="rank-metric-tabs" role="tablist" aria-label="Métrica del ranking">{Object.entries(rankingCategories).map(([key, item]) => <button role="tab" aria-selected={category === key} aria-label={item.label} title={item.label} key={key} className={category === key ? 'active' : ''} onClick={() => setCategory(key)}><Icon name={item.icon} /><span>{item.shortLabel}</span></button>)}</div>
    {error && <div className="social-error">{error}</div>}
    <section className="podium">{rows.slice(0, 3).map((row, index) => <div className={`podium-person place-${index + 1}`} key={row.id}>
      <span className="podium-avatar">{row.display_name?.[0]}</span><b>{row.display_name}</b><strong>{formatValue(row.value, category)}</strong><small>{meta.unit}</small>
    </div>)}</section>
    <section className="social-card rank-list">{rows.map(row => <div className="rank-row" key={row.id}>
      <span className={`rank-pos p${row.position}`}>{row.position}</span><span className="avatar">{row.display_name?.[0]}</span>
      <div className="grow"><b>{row.display_name}</b><small>{row.synced_at ? `Sincronizado ${new Date(row.synced_at).toLocaleTimeString('es-CL', { hour: '2-digit', minute: '2-digit' })}` : 'Sin datos en el período'}</small></div>
      <strong style={{ color: row.position === 1 ? '#FFD700' : row.position === 2 ? '#C0C0C0' : row.position === 3 ? '#CD7F32' : 'var(--club)' }}>{formatValue(row.value, category)} <small>{meta.unit}</small></strong>
    </div>)}</section>
  </div>
}
