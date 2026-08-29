import { requireSupabase } from './supabase.js'

// Public VAPID keys identify the sender and are intentionally safe to ship to clients.
const VAPID_PUBLIC_KEY = import.meta.env.VITE_WEB_PUSH_VAPID_PUBLIC_KEY

export const pushSupported = () => 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window
export const pushPermission = () => (pushSupported() ? Notification.permission : 'unsupported')

async function pushRegistration({ create = false } = {}) {
  if (!pushSupported()) return null
  const existing = await navigator.serviceWorker.getRegistration()
  if (existing || !create) return existing || null
  if (!window.isSecureContext) throw new Error('Las notificaciones requieren instalar la app desde una conexión segura.')
  return navigator.serviceWorker.register('sw.js')
}

const urlBase64ToUint8Array = b64 => {
  const padded = (b64 + '='.repeat((4 - b64.length % 4) % 4)).replace(/-/g, '+').replace(/_/g, '/')
  const raw = atob(padded)
  return Uint8Array.from([...raw].map(c => c.charCodeAt(0)))
}

const subscriptionKeys = subscription => {
  const json = subscription.toJSON()
  if (!json.keys?.p256dh || !json.keys?.auth) throw new Error('El navegador no entregó las claves de notificación.')
  return json.keys
}

export async function currentPushSubscription() {
  if (!pushSupported()) return null
  const registration = await pushRegistration()
  if (!registration) return null
  return registration.pushManager.getSubscription()
}

export async function currentPushState() {
  if (!pushSupported()) return { code: 'unsupported', permission: 'unsupported', subscription: null }
  const permission = pushPermission()
  if (permission === 'denied') return { code: 'blocked', permission, subscription: null }
  const subscription = await currentPushSubscription()
  if (!subscription) return { code: 'off', permission, subscription: null }

  const client = requireSupabase()
  const { data: { user } } = await client.auth.getUser()
  if (!user) throw new Error('Inicia sesión para comprobar este dispositivo.')
  const { data, error } = await client
    .from('web_push_devices')
    .select('id,enabled')
    .eq('user_id', user.id)
    .eq('endpoint', subscription.endpoint)
    .maybeSingle()
  if (error) throw error
  return { code: data?.enabled ? 'enabled' : 'desynced', permission, subscription }
}

export async function enablePush() {
  if (!pushSupported()) throw new Error('Este navegador no admite notificaciones push.')
  if (!VAPID_PUBLIC_KEY) throw new Error('Las notificaciones aún no están configuradas en este entorno.')
  const permission = await Notification.requestPermission()
  if (permission !== 'granted') throw new Error('Activa las notificaciones en los permisos del navegador para continuar.')
  const client = requireSupabase()
  const registration = await pushRegistration({ create: true })
  const subscription = await registration.pushManager.getSubscription()
    || await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY) })
  const keys = subscriptionKeys(subscription)
  const { error } = await client.rpc('register_web_push_device', {
    p_endpoint: subscription.endpoint,
    p_p256dh: keys.p256dh,
    p_auth: keys.auth,
    p_user_agent: navigator.userAgent,
  })
  if (error) {
    await subscription.unsubscribe().catch(() => {})
    throw error
  }
  return subscription
}

export async function disablePush() {
  const subscription = await currentPushSubscription()
  if (!subscription) return
  const client = requireSupabase()
  const { error } = await client.rpc('unregister_web_push_device', { p_endpoint: subscription.endpoint })
  if (error) throw error
  await subscription.unsubscribe()
}

export async function sendTestPush() {
  const client = requireSupabase()
  const { data: { user } } = await client.auth.getUser()
  if (!user) throw new Error('Inicia sesión para probar las notificaciones.')
  const { error } = await client.rpc('insert_notification', {
    p_user_id: user.id,
    p_type: 'daily_goal',
    p_title: 'Notificaciones activadas',
    p_body: 'EnfermiCambio ya puede avisarte aunque la aplicación esté cerrada.',
    p_payload: { route: '/notifications', test: true },
  })
  if (error) throw error
  return { queued: true }
}
