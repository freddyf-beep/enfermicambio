import { useLocation, useNavigate } from 'react-router-dom'
import Icon from './Icon.jsx'

// Same five-destination shell as the original Flutter app: HOY, RANKING,
// REGISTRAR, JUEGO, NOSOTROS. Training lives under HOY, exactly like the
// original bottom navigation, and the secondary training pages keep their
// routes but inherit the active tab from their section.
const tabs = [
  ['today', 'house', 'Hoy'],
  ['ranking', 'chart', 'Ranking'],
  ['register', 'plus', 'Registrar'],
  ['game', 'trophy', 'Juego'],
  ['profiles', 'people', 'Nosotros'],
]

// All routes that belong to each tab, so the underline follows subpages.
const routesOf = {
  today: ['/today', '/train', '/plan', '/workout', '/stats', '/history', '/library', '/settings'],
  ranking: ['/ranking'],
  register: ['/register'],
  game: ['/game'],
  profiles: ['/profiles', '/notifications', '/weight', '/install', '/health-import', '/licenses'],
}

export default function TabBar() {
  const nav = useNavigate(); const loc = useLocation()
  const path = loc.pathname.split('/')[1] || 'today'
  const current = Object.entries(routesOf).find(([, paths]) =>
    paths.some(p => loc.pathname === p || loc.pathname.startsWith(p + '/'))
  )?.[0] || path
  return <nav id="social-tabbar" aria-label="Secciones principales">{tabs.map(([key, icon, label]) => <button key={key} aria-current={current === key ? 'page' : undefined} className={current === key ? 'on' : ''} onClick={() => nav(`/${key}`)}><span><Icon name={icon} /></span><small>{label}</small></button>)}</nav>
}
