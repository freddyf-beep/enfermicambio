/* Enfermicambio service worker — runtime caching (works with Vite's hashed asset names).
   Media (img/gif) cache-first; everything else network-first with offline fallback. */
const CACHE = 'enfermicambio-pwa-v9'

// V9 refreshes the native-first shell and keeps malformed push payloads from
// disappearing silently. Manifest and icons use the same network-first path.
self.addEventListener('install', () => self.skipWaiting())
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys =>
    Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
  ).then(() => self.clients.claim()))
})
self.addEventListener('push', e => {
  let data = {}
  if (e.data) {
    try { data = e.data.json() }
    catch { data = { body: e.data.text() } }
  }
  e.waitUntil(self.registration.showNotification(data.title || 'EnfermiCambio', {
    body: data.body || '',
    icon: 'icon-512.png',
    badge: 'icon-180.png',
    tag: data.tag || data.data?.notification_id || 'enfermicambio',
    renotify: true,
    data: data.data || {}
  }))
})
self.addEventListener('notificationclick', e => {
  e.notification.close()
  const payload = e.notification.data || {}
  const route = payload.route || (payload.post_id ? `/today?post=${encodeURIComponent(payload.post_id)}` : '/notifications')
  const target = new URL(`#${route}`, self.registration.scope).href
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clients => {
    const c = clients.find(client => 'focus' in client)
    if (c) return c.focus().then(() => c.navigate(target))
    return self.clients.openWindow(target)
  }))
})

self.addEventListener('fetch', e => {
  const url = new URL(e.request.url)
  if (e.request.method !== 'GET' || url.origin !== location.origin) return
  if (url.pathname.startsWith('/api/')) return    // never cache auth/data

  const isMedia = url.pathname.includes('/workout-guide/')
  if (isMedia) {
    e.respondWith(caches.open(CACHE).then(c => c.match(e.request).then(hit =>
      hit || fetch(e.request).then(res => { if (res.ok) c.put(e.request, res.clone()); return res })
    )))
  } else {
    e.respondWith(fetch(e.request).then(res => {
      if (res.ok) caches.open(CACHE).then(c => c.put(e.request, res.clone()))
      return res
    }).catch(() => caches.match(e.request).then(hit => hit || caches.match('./index.html'))))
  }
})
