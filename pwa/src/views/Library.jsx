import { useMemo, useState } from 'react'
import { useStore } from '../store/useStore.js'
import { EXDB, BODYPARTS, allExercises, equipmentOf, matchExercise } from '../lib/exercises.js'
import { activeProfile, exAvailable, HOME_REPERTOIRE } from '../lib/equipment.js'
import { bestWeightFor } from '../lib/history.js'
import { fmtNum } from '../lib/format.js'
import { t, exerciseNameFor } from '../lib/i18n.js'
import { Thumb } from '../components/Media.jsx'
import { exerciseDetailSheet, addToRoutineSheet, customExSheet } from '../sheets.jsx'
import Icon from '../components/Icon.jsx'
import { Button } from '../components/ui.jsx'

export default function Library() {
  const S = useStore(s => s.S)
  const update = useStore(s => s.update)
  const [q, setQ] = useState('')
  const [bp, setBp] = useState('')
  const [eq, setEq] = useState('')
  const [mode, setMode] = useState('recommended')
  const [filtersOpen, setFiltersOpen] = useState(false)
  const [showAll, setShowAll] = useState(false)   // ignore the active equipment profile for this session
  const [shown, setShown] = useState(40)
  const profile = activeProfile(S)
  const favoriteIds = S.favoriteEx || []
  const gymRecommendedIds = ['0025', '0047', '0426', '0334', '0241', '0251', '2330', '0027', '1323', '0031', '0313', '0043', '0085', '0739', '0585', '0586', '0605']
  const recommendedIds = S.trainingPlace === 'home' ? HOME_REPERTOIRE.map(exercise => exercise.id) : gymRecommendedIds
  const recentIds = useMemo(() => {
    const ids = []
    ;[...(S.workouts || [])].sort((a, b) => (b.start || b.end || 0) - (a.start || a.end || 0)).forEach(w => {
      ;(w.entries || []).forEach(entry => { if (!ids.includes(entry.id)) ids.push(entry.id) })
    })
    return ids
  }, [S.workouts])
  const base = allExercises(S).filter(e => (!bp || e.bp === bp) && matchExercise(e, q))
  const eqFiltered = (profile && !showAll) ? base.filter(e => exAvailable(S, e)) : base
  const eqOpts = equipmentOf(eqFiltered)
  // Drop the equipment filter if the search narrowed it away, so you never hit a dead end.
  const eqOn = eqOpts.includes(eq) ? eq : ''
  const filtered = eqOn ? eqFiltered.filter(e => e.eq === eqOn) : eqFiltered
  const priority = mode === 'favorites' ? favoriteIds : mode === 'recent' ? recentIds : recommendedIds
  const scoped = q || mode === 'all' ? filtered : filtered.filter(e => priority.includes(e.id))
  const f = [...scoped].sort((a, b) => {
    const ai = priority.indexOf(a.id), bi = priority.indexOf(b.id)
    if (ai >= 0 || bi >= 0) return (ai < 0 ? 9999 : ai) - (bi < 0 ? 9999 : bi)
    return exerciseNameFor(a).localeCompare(exerciseNameFor(b), 'es')
  })
  const toggleFavorite = id => update(s => {
    const current = s.favoriteEx || (s.favoriteEx = [])
    const at = current.indexOf(id)
    if (at >= 0) current.splice(at, 1)
    else current.push(id)
  })

  return <main className="ec-page ec-library">
    <header className="ec-page-head"><div><span className="ec-kicker">ENTRENAMIENTO</span><h1>Ejercicios</h1><p>{EXDB.length.toLocaleString('es-CL')} movimientos con guía visual</p></div></header>
    <div className="search ec-library-search"><Icon name="magnifier" />
      <input className="input" aria-label="Buscar ejercicios" placeholder="Buscar ejercicio, músculo o equipo" value={q} onChange={e => { setQ(e.target.value); setShown(40) }} /></div>
    <div className="ec-segment" role="tablist" aria-label="Vista de ejercicios">
      {[['recommended', 'Para ti'], ['recent', 'Recientes'], ['favorites', 'Favoritos'], ['all', 'Todos']].map(([id, label]) =>
        <button key={id} role="tab" aria-selected={!q && mode === id} className={!q && mode === id ? 'on' : ''} onClick={() => { setQ(''); setMode(id); setShown(40) }}>{label}</button>)}
    </div>
    <button className={'ec-filter-trigger' + (filtersOpen || bp || eqOn ? ' on' : '')} onClick={() => setFiltersOpen(v => !v)} aria-expanded={filtersOpen}>
      <Icon name="sliders" /><span>Filtros</span>{(bp || eqOn) && <small>{[bp && t(bp), eqOn && t(eqOn)].filter(Boolean).join(' · ')}</small>}<Icon name={filtersOpen ? 'chevronUp' : 'chevronDown'} />
    </button>
    {filtersOpen && <div className="ec-filter-panel">
    {profile && <div className="small dim row" style={{ margin: '-4px 2px 10px', gap: 6, alignItems: 'center' }}>
      <Icon name="dumbbell" style={{ fontSize: 13 }} />
      {showAll ? t('Showing all equipment') : t('Showing what you have in "{0}"', profile.name)}
      <button className="chip nocap" style={{ marginLeft: 'auto', padding: '3px 10px', fontSize: 12 }} onClick={() => setShowAll(v => !v)}>
        {showAll ? t('Filter by "{0}"', profile.name) : t('Show all equipment')}
      </button>
    </div>}
    <div className="chips" style={{ marginBottom: eqOpts.length > 1 ? 8 : 12 }}>
      <button className={'chip nocap' + (!bp ? ' on' : '')} onClick={() => { setBp(''); setEq(''); setShown(40) }}>{t('All')}</button>
      {BODYPARTS.map(b => <button key={b} className={'chip' + (bp === b ? ' on' : '')} onClick={() => { setBp(b); setEq(''); setShown(40) }}>{t(b)}</button>)}
    </div>
    {eqOpts.length > 1 && <div className="chips" style={{ marginBottom: 12 }}>
      <button className={'chip nocap' + (!eqOn ? ' on' : '')} onClick={() => { setEq(''); setShown(40) }}>{t('Any equipment')}</button>
      {eqOpts.map(x => <button key={x} className={'chip' + (eqOn === x ? ' on' : '')} onClick={() => { setEq(x); setShown(40) }}>{t(x)}</button>)}
    </div>}
    </div>}
    <div className="ec-library-meta"><strong>{f.length}</strong> resultados{mode === 'recommended' && !q ? ' seleccionados para comenzar' : ''}</div>
    <div className="list">
      <div className="item" onClick={() => customExSheet(null, ex => exerciseDetailSheet(ex), q.trim())}>
        <div className="thumb thumb-x"><Icon name="sparkles" /></div>
        <div className="grow"><div className="tt">{t('Create your own exercise')}</div><div className="ss">{t('name + body part, no animation')}</div></div><Icon name="plus" className="chev" />
      </div>
      {f.slice(0, shown).map(e => {
        const best = bestWeightFor(S, e.id)
        const favorite = favoriteIds.includes(e.id)
        return <div key={e.id} className="item" onClick={() => exerciseDetailSheet(e)}>
          <Thumb ex={e} />
          <div className="grow"><div className="tt capitalize">{exerciseNameFor(e)}</div><div className="ss capitalize">{t(e.tg || e.bp)} · {t(e.eq)}</div></div>
          {best > 0 && <span className="tag acc">{fmtNum(best)}</span>}
          <button className={'ec-favorite' + (favorite ? ' on' : '')} aria-label={favorite ? 'Quitar de favoritos' : 'Agregar a favoritos'} onClick={ev => { ev.stopPropagation(); toggleFavorite(e.id) }}><Icon name={favorite ? 'starFill' : 'star'} /></button>
          <Button size="sm" variant="tinted" icon="plus" onClick={ev => { ev.stopPropagation(); addToRoutineSheet(e) }}>{t('Plan')}</Button>
        </div>
      })}
      {f.length === 0 && <div className="empty"><div className="ico"><Icon name={mode === 'favorites' ? 'star' : 'magnifier'} /></div>{mode === 'favorites' ? 'Guarda ejercicios con la estrella para verlos aquí.' : mode === 'recent' ? 'Tus ejercicios aparecerán aquí después de entrenar.' : t('No match')}</div>}
    </div>
    {f.length > shown && <><div style={{ height: 10 }} /><Button onClick={() => setShown(s => s + 40)}>{t('Show more')}</Button></>}
  </main>
}
