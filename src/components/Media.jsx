import { useEffect, useState } from 'react'
import Icon from './Icon.jsx'
import { exerciseNameFor } from '../lib/i18n.js'

const CDN = 'https://cdn.jsdelivr.net/npm/@bryllim/workout-guide@1.0.0/'
let guidePromise
const normalize = value => String(value || '').toLowerCase().normalize('NFD')
  .replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]+/g, ' ').trim()

function guide() {
  if (import.meta.env.MODE === 'test') return Promise.resolve([])
  guidePromise ||= fetch(`${import.meta.env.BASE_URL}workout-guide/manifest.json`)
    .then(r => r.ok ? r.json() : [])
  return guidePromise
}

function useGuideExercise(ex) {
  const [match, setMatch] = useState(null)
  useEffect(() => {
    let live = true
    guide().then(list => {
      const name = normalize(ex?.n)
      const found = list.find(item => normalize(item.name) === name)
        || list.find(item => name.includes(normalize(item.name)) || normalize(item.name).includes(name))
      if (live) setMatch(found || null)
    })
    return () => { live = false }
  }, [ex?.n])
  return match
}

function frameUrl(match, index = 0) {
  const path = match?.frames?.[index]?.path
  return path ? CDN + path : null
}

export default function Media({ ex, compact }) {
  const match = useGuideExercise(ex)
  const [frame, setFrame] = useState(0)
  useEffect(() => {
    if (!match) return
    const timer = setInterval(() => setFrame(x => (x + 1) % 3), 700)
    return () => clearInterval(timer)
  }, [match])
  if (!match) return null
  return <div className={'exmedia' + (compact ? ' compact' : '')}>
    <img decoding="async" src={frameUrl(match, frame)} alt={exerciseNameFor(ex)} />
    <span className="gifhint"><Icon name="sparkles" />Workout Guide</span>
  </div>
}

export function Thumb({ ex }) {
  const match = useGuideExercise(ex)
  const src = frameUrl(match)
  if (!src) return <div className="thumb thumb-x"><Icon name="dumbbell" /></div>
  return <img className="thumb" loading="lazy" decoding="async" src={src} alt="" />
}
