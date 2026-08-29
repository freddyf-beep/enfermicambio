export async function validateHealthBridgeToken(endpoint, token, platform, fetchImpl = fetch) {
  if (!endpoint || !token || !['ios', 'android'].includes(platform)) throw new Error('La conexión de salud está incompleta.')
  const response = await fetchImpl(endpoint, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ source_platform: platform, validate_only: true }),
  })
  let body = null
  try { body = await response.json() } catch { /* readable fallback below */ }
  if (!response.ok || body?.validated !== true) {
    throw new Error(body?.error || `El servidor rechazó el token (${response.status}).`)
  }
  return body
}
