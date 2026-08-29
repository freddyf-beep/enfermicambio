// PWA compatibility helpers for the imported openGym training engine.
export const MOBILE = false

export async function nativeLoad() { return null }
export async function nativeSave() {}
export async function loadRemoteFile() { return null }
export async function saveRemoteFile() {}
export async function syncReminder() { return true }
export async function writeAutoBackup() {}

export async function shareExport(json, filename) {
  const blob = new Blob([json], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  link.click()
  URL.revokeObjectURL(url)
}
