const EARTH_RADIUS_METERS = 6371000
const radians = degrees => degrees * Math.PI / 180

export function distanceBetween(a, b) {
  if (!a || !b) return 0
  const lat1 = radians(Number(a.latitude))
  const lat2 = radians(Number(b.latitude))
  const dLat = lat2 - lat1
  const dLon = radians(Number(b.longitude) - Number(a.longitude))
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2
  return EARTH_RADIUS_METERS * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h))
}

export function routeDistance(points = []) {
  let total = 0
  for (let index = 1; index < points.length; index += 1) total += distanceBetween(points[index - 1], points[index])
  return total
}

export function formatDuration(seconds = 0) {
  const safe = Math.max(0, Math.round(seconds))
  const hours = Math.floor(safe / 3600)
  const minutes = Math.floor((safe % 3600) / 60)
  const rest = safe % 60
  return hours ? `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(rest).padStart(2, '0')}` : `${String(minutes).padStart(2, '0')}:${String(rest).padStart(2, '0')}`
}
