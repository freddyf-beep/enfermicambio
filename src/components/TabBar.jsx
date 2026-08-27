import { useLocation, useNavigate } from 'react-router-dom'

const tabs = [
  ['today', '⌂', 'Hoy'], ['ranking', '↗', 'Ranking'], ['train', '●', 'Entrenar'],
  ['register', '+', 'Registrar'], ['game', '♛', 'Juego'], ['profiles', '◎', 'Nosotros'],
]
export default function TabBar() {
  const nav = useNavigate(); const loc = useLocation()
  const secondary = ['/plan', '/workout', '/stats', '/history', '/library', '/settings', '/health-import', '/licenses']
  const current = secondary.some(x => loc.pathname.startsWith(x)) ? 'train' : loc.pathname.split('/')[1]
  return <nav id="social-tabbar">{tabs.map(([key, icon, label]) => <button key={key} className={current === key ? 'on' : ''} onClick={() => nav(`/${key}`)}><span>{icon}</span><small>{label}</small></button>)}</nav>
}
