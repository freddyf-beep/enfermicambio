let deferredPrompt = null
const listeners = new Set()

const notify = () => listeners.forEach(listener => listener())

if (typeof window !== 'undefined') {
  window.addEventListener('beforeinstallprompt', event => {
    event.preventDefault()
    deferredPrompt = event
    notify()
  })
  window.addEventListener('appinstalled', () => {
    deferredPrompt = null
    notify()
  })
}

export function isInstalled() {
  if (typeof window === 'undefined') return false
  return window.matchMedia?.('(display-mode: standalone)').matches
    || window.navigator.standalone === true
}

export function installAvailable() {
  return Boolean(deferredPrompt)
}

export function installPlatform() {
  if (typeof navigator === 'undefined') return 'other'
  const agent = navigator.userAgent || ''
  if (/iPad|iPhone|iPod/.test(agent)) return 'ios'
  if (/Android/.test(agent)) return 'android'
  return 'desktop'
}

export function subscribeInstall(listener) {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

export async function requestInstall() {
  if (!deferredPrompt) return false
  const prompt = deferredPrompt
  deferredPrompt = null
  notify()
  await prompt.prompt()
  const result = await prompt.userChoice
  return result?.outcome === 'accepted'
}
