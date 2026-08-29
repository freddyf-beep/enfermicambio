import { describe, expect, it } from 'vitest'
import { distanceBetween, formatDuration, routeDistance } from './activity-route.js'

describe('activity route helpers', () => {
  it('calculates realistic GPS distance in meters', () => {
    const distance = distanceBetween(
      { latitude: 0, longitude: 0 },
      { latitude: 0, longitude: 0.001 },
    )
    expect(distance).toBeGreaterThan(110)
    expect(distance).toBeLessThan(112)
  })

  it('adds every segment without inventing distance', () => {
    const points = [
      { latitude: 0, longitude: 0 },
      { latitude: 0, longitude: 0.001 },
      { latitude: 0, longitude: 0.002 },
    ]
    expect(routeDistance(points)).toBeCloseTo(222.39, 1)
    expect(routeDistance([])).toBe(0)
  })

  it('formats short and long activities', () => {
    expect(formatDuration(65)).toBe('01:05')
    expect(formatDuration(3661)).toBe('01:01:01')
    expect(formatDuration(-10)).toBe('00:00')
  })
})
