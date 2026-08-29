import { describe, expect, it } from 'vitest'
import { aggregateRanking, missionProgress, repairMojibake, splitStorageReference } from './social-domain.js'

const profiles = [
  { id: 'a', display_name: 'Ana' },
  { id: 'b', display_name: 'Beto' },
  { id: 'c', display_name: 'Cata' },
  { id: 'd', display_name: 'Dani' },
]

describe('aggregateRanking', () => {
  it('keeps all four profiles and sums an activity period', () => {
    const rows = aggregateRanking({ profiles, category: 'daily_steps', activity: [
      { user_id: 'a', daily_steps: 1000 }, { user_id: 'a', daily_steps: 500 }, { user_id: 'b', daily_steps: 1200 },
    ] })
    expect(rows.map(row => [row.id, row.value])).toEqual([['a', 1500], ['b', 1200], ['c', 0], ['d', 0]])
  })

  it('counts workouts and sorts deterministically', () => {
    const rows = aggregateRanking({ profiles, category: 'workouts', workouts: [
      { user_id: 'd' }, { user_id: 'd' }, { user_id: 'b' },
    ] })
    expect(rows[0]).toMatchObject({ id: 'd', value: 2, position: 1 })
    expect(rows[1]).toMatchObject({ id: 'b', value: 1, position: 2 })
  })

  it('uses standings for season points without double counting ledger rows', () => {
    const rows = aggregateRanking({ profiles, category: 'points', points: [{ user_id: 'a', points: 99 }], standings: [{ user_id: 'b', total_points: 30 }] })
    expect(rows.find(row => row.id === 'a').value).toBe(0)
    expect(rows.find(row => row.id === 'b').value).toBe(30)
  })
})

it('normalizes mission progress', () => {
  expect(missionProgress({ id: 'm', mission_type: 'individual', rules: { target: 10 } }, [
    { mission_id: 'm', user_id: 'a', progress: { current: 4 }, completed: false },
  ], 'a')).toMatchObject({ current: 4, target: 10, ratio: .4, completed: false })
})

it('parses private storage references only', () => {
  expect(splitStorageReference('feed-media/u/photo.jpg')).toEqual({ bucket: 'feed-media', path: 'u/photo.jpg' })
  expect(splitStorageReference('https://example.com/photo.jpg')).toBeNull()
})

it('repairs legacy mojibake without touching clean text', () => {
  expect(repairMojibake('BicampeÃ³n')).toBe('Bicampeón')
  expect(repairMojibake('Rey del sofÃ¡')).toBe('Rey del sofá')
  expect(repairMojibake('Campeón de temporada')).toBe('Campeón de temporada')
})
