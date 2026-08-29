export const INSTALL_ICONS = [
  { id: 'pulse', label: 'Original', color: '#0A96C5' },
  { id: 'ember', label: 'Rojo', color: '#0A84FF' },
  { id: 'ocean', label: 'Médico', color: '#12AFC0' },
  { id: 'night', label: 'Retrato', color: '#087DAF' },
]

export function installIconId(value) {
  return INSTALL_ICONS.some(icon => icon.id === value) ? value : 'pulse'
}

export function applyInstallIcon(value) {
  const id = installIconId(value)
  const manifest = document.querySelector('link[rel="manifest"]')
  const apple = document.querySelector('link[rel="apple-touch-icon"]')
  const favicon = document.querySelector('link[rel="icon"]')
  if (manifest) manifest.href = `manifest-${id}.json`
  if (apple) apple.href = `icon-${id}-180.png`
  if (favicon) favicon.href = `icon-${id}-192.png`
}
