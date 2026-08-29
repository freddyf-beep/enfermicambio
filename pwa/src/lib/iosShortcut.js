export const IOS_HEALTH_SHORTCUT_NAME = 'EnfermiCambio Salud'

export function buildIosHealthConfiguration(endpoint, token) {
  const normalizedEndpoint = String(endpoint || '').trim()
  const normalizedToken = String(token || '').trim()
  if (!normalizedEndpoint || !normalizedToken) throw new Error('Faltan el endpoint o el token del Atajo.')

  return JSON.stringify({
    endpoint: normalizedEndpoint,
    token: normalizedToken,
    source_platform: 'ios',
    shortcut: IOS_HEALTH_SHORTCUT_NAME,
  })
}

export function buildShortcutRunUrl(name = IOS_HEALTH_SHORTCUT_NAME) {
  return `shortcuts://run-shortcut?name=${encodeURIComponent(name)}&input=clipboard`
}

export function normalizeSharedShortcutUrl(value) {
  const candidate = String(value || '').trim()
  if (!candidate) return ''

  try {
    const url = new URL(candidate)
    const sharedId = url.pathname.match(/^\/shortcuts\/([a-zA-Z0-9]+)\/?$/)?.[1]
    return url.protocol === 'https:' && url.hostname === 'www.icloud.com' && sharedId
      ? `https://www.icloud.com/shortcuts/${sharedId}`
      : ''
  } catch {
    return ''
  }
}
