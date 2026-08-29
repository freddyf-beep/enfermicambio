import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import Icon from '../components/Icon.jsx'
import { currentPushState, disablePush, enablePush, sendTestPush } from '../lib/push.js'
import { useSocial } from '../store/useSocial.js'

const PRESENTATION = {
  feed_post: { icon: 'camera', tone: 'violet', label: 'Nueva publicación', action: 'Ver publicación', destination: '/today' },
  comment: { icon: 'people', tone: 'blue', label: 'Conversación', action: 'Ver comentario', destination: '/today' },
  reaction: { icon: 'flame', tone: 'coral', label: 'Motivación', action: 'Ver publicación', destination: '/today' },
  workout: { icon: 'dumbbell', tone: 'lime', label: 'Entrenamiento', action: 'Ver entrenamiento', destination: '/train' },
  achievement: { icon: 'medal', tone: 'violet', label: 'Nuevo logro', action: 'Ver logro', destination: '/game' },
  mission: { icon: 'target', tone: 'coral', label: 'Misión', action: 'Ver misión', destination: '/game' },
  ranking: { icon: 'chart', tone: 'blue', label: 'Ranking', action: 'Ver ranking', destination: '/ranking' },
  overtake: { icon: 'chart', tone: 'blue', label: 'Ranking', action: 'Ver ranking', destination: '/ranking' },
  leader_change: { icon: 'crown', tone: 'violet', label: 'Ranking', action: 'Ver ranking', destination: '/ranking' },
  round_result: { icon: 'trophy', tone: 'violet', label: 'Resultado', action: 'Ver resultado', destination: '/game' },
  season: { icon: 'trophy', tone: 'violet', label: 'Temporada', action: 'Ver temporada', destination: '/game' },
  daily_goal: { icon: 'checkCircle', tone: 'lime', label: 'Meta diaria', action: 'Ver tu día', destination: '/today' },
  steps_milestone: { icon: 'figureRun', tone: 'lime', label: 'Actividad', action: 'Ver tu día', destination: '/today' },
  personal_record: { icon: 'bolt', tone: 'coral', label: 'Marca personal', action: 'Ver progreso', destination: '/train' },
  weight_entry_goal: { icon: 'scale', tone: 'blue', label: 'Peso', action: 'Ver evolución', destination: '/weight' },
  weight_change: { icon: 'scale', tone: 'blue', label: 'Peso', action: 'Ver evolución', destination: '/weight' },
}

const fallback = { icon: 'bell', tone: 'lime', label: 'Actualización', action: 'Abrir', destination: '/today' }

const DELIVERY = {
  checking: { title: 'Revisando este dispositivo…', copy: 'Confirmando permiso y registro seguro.', action: '' },
  enabled: { title: 'Avisos activos', copy: 'Este dispositivo está registrado para recibir novedades.', action: 'Probar ahora' },
  desynced: { title: 'Hay que reconectar', copy: 'El navegador conserva el permiso, pero el dispositivo no figura activo.', action: 'Reconectar' },
  off: { title: 'Avisos desactivados', copy: 'Actívalos para recibir metas, logros y actividad importante.', action: 'Activar' },
  blocked: { title: 'Permiso bloqueado', copy: 'Habilita las notificaciones desde los ajustes del navegador o del teléfono.', action: '' },
  unsupported: { title: 'No disponibles aquí', copy: 'Instala la app o usa un navegador compatible con notificaciones push.', action: '' },
}

const relativeTime = iso => {
  const minutes = Math.max(0, Math.round((Date.now() - new Date(iso).getTime()) / 60000))
  if (minutes < 1) return 'Ahora'
  if (minutes < 60) return `Hace ${minutes} min`
  if (minutes < 1440) return `Hace ${Math.round(minutes / 60)} h`
  if (minutes < 2880) return 'Ayer'
  return new Date(iso).toLocaleDateString('es-CL', { day: 'numeric', month: 'short' })
}

export default function Notifications() {
  const nav = useNavigate()
  const notifications = useSocial(state => state.notifications)
  const markRead = useSocial(state => state.markNotificationRead)
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const [delivery, setDelivery] = useState('checking')
  const [deliveryNote, setDeliveryNote] = useState('')
  const unreadItems = notifications.filter(item => !item.is_read)
  const readItems = notifications.filter(item => item.is_read)

  const refreshDelivery = async () => {
    try { setDelivery((await currentPushState()).code) }
    catch { setDelivery('off') }
  }

  useEffect(() => { refreshDelivery() }, [])

  const updateDelivery = async action => {
    if (busy) return
    setBusy(true); setError(''); setDeliveryNote('')
    try {
      if (action === 'disable') await disablePush()
      else if (action === 'test') {
        await sendTestPush()
        setDeliveryNote('Prueba solicitada. Puede tardar unos segundos en aparecer.')
      } else await enablePush()
      await refreshDelivery()
    } catch (reason) { setError(reason.message || 'No se pudo actualizar este dispositivo.') }
    finally { setBusy(false) }
  }

  const markAll = async () => {
    if (busy || !unreadItems.length) return
    setBusy(true)
    try { setError(''); await markRead() }
    catch (reason) { setError(reason.message) }
    finally { setBusy(false) }
  }

  const open = async item => {
    const view = PRESENTATION[item.type] || fallback
    try {
      setError('')
      if (!item.is_read) await markRead(item.id)
      nav(view.destination, { state: item.payload?.post_id ? { postId: item.payload.post_id } : undefined })
    } catch (reason) { setError(reason.message) }
  }

  const list = (items, label) => items.length > 0 && <section className="ec-notification-group" aria-labelledby={`notice-${label}`}>
    <div className="ec-section-head"><div><p className="ec-kicker">{label}</p><h2 id={`notice-${label}`}>{label === 'Nuevas' ? `${items.length} por revisar` : 'Ya revisadas'}</h2></div></div>
    <div className="ec-notification-list">{items.map(item => {
      const view = PRESENTATION[item.type] || fallback
      return <button className={item.is_read ? '' : 'unread'} key={item.id} onClick={() => open(item)}>
        <span className={`ec-notification-icon ${view.tone}`}><Icon name={view.icon} /></span>
        <span className="ec-notification-copy"><small>{view.label} · {relativeTime(item.created_at)}</small><b>{item.title}</b><em>{item.body}</em><strong>{view.action}<Icon name="chevronRight" /></strong></span>
        {!item.is_read && <i aria-label="Sin leer" />}
      </button>
    })}</div>
  </section>

  const deliveryView = DELIVERY[delivery] || DELIVERY.off

  return <div className="ec-page ec-notifications-page">
    <header className="ec-topbar"><button className="ec-icon-button" onClick={() => nav(-1)} aria-label="Volver"><Icon name="chevronLeft" /></button><div className="grow"><p className="ec-kicker">Centro de actividad</p><h1>Notificaciones</h1><p className="ec-subtitle">Avisos útiles del grupo, tus metas y la competencia.</p></div></header>
    <section className={`ec-push-device ${delivery}`} aria-live="polite">
      <span><Icon name={delivery === 'enabled' ? 'checkCircle' : 'bell'} /></span>
      <p><b>{deliveryView.title}</b><small>{deliveryView.copy}</small>{deliveryNote && <em>{deliveryNote}</em>}</p>
      <div>
        {deliveryView.action && <button disabled={busy} onClick={() => updateDelivery(delivery === 'enabled' ? 'test' : 'enable')}>{busy ? 'Espera…' : deliveryView.action}</button>}
        {delivery === 'enabled' && <button className="quiet" disabled={busy} onClick={() => updateDelivery('disable')}>Desactivar</button>}
      </div>
    </section>
    {unreadItems.length > 0 && <div className="ec-notification-summary"><span><Icon name="bell" /></span><p><b>{unreadItems.length === 1 ? 'Tienes una novedad' : `Tienes ${unreadItems.length} novedades`}</b><small>Al abrir un aviso quedará marcado como revisado.</small></p><button disabled={busy} onClick={markAll}>{busy ? 'Marcando…' : 'Leer todas'}</button></div>}
    {error && <div className="ec-result" role="alert">{error}</div>}
    {notifications.length ? <>{list(unreadItems, 'Nuevas')}{list(readItems, 'Anteriores')}</> : <div className="ec-empty ec-notification-empty"><Icon name="bell" /><b>Todo al día</b><span>Las publicaciones, comentarios y avances importantes aparecerán aquí.</span></div>}
  </div>
}
