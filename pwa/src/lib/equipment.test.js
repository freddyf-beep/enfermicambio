import { describe, expect, it } from 'vitest'
import { ALL_EQUIPMENT, HOME_REPERTOIRE, applyTrainingPlace, exAvailable, homeReplacementFor } from './equipment.js'

describe('training place presets', () => {
  it('creates a bodyweight-first home profile', () => {
    const state = { equipProfiles: [] }
    const profile = applyTrainingPlace(state, 'home')
    expect(profile).toMatchObject({ id: 'eq-home', kind: 'home', name: 'Casa', equipment: [] })
    expect(state).toMatchObject({ trainingPlace: 'home', activeEquipId: 'eq-home', equipFilterOn: true })
    expect(exAvailable(state, { eq: 'body weight' })).toBe(true)
    expect(exAvailable(state, { eq: 'barbell' })).toBe(false)
  })

  it('offers equipment-free replacements for common gym movements', () => {
    expect(homeReplacementFor({ tg: 'pectorals', bp: 'chest', eq: 'barbell' })).toMatchObject({ id: '0662', eq: 'body weight' })
    expect(homeReplacementFor({ tg: 'quads', bp: 'upper legs', eq: 'leverage machine' })).toMatchObject({ id: '1685', eq: 'body weight' })
    expect(HOME_REPERTOIRE.length).toBeGreaterThanOrEqual(10)
    expect(HOME_REPERTOIRE.every(exercise => exercise.eq === 'body weight')).toBe(true)
  })

  it('creates a gym profile without deleting custom profiles', () => {
    const custom = { id: 'custom', name: 'Mi equipo', equipment: ['dumbbell'] }
    const state = { equipProfiles: [custom] }
    const profile = applyTrainingPlace(state, 'gym')
    expect(profile.equipment).toEqual(ALL_EQUIPMENT)
    expect(state.equipProfiles).toContain(custom)
    expect(exAvailable(state, { eq: ALL_EQUIPMENT[0] })).toBe(true)
  })

  it('ignores unknown places safely', () => {
    const state = { equipProfiles: [] }
    expect(applyTrainingPlace(state, 'park')).toBeNull()
    expect(state.equipProfiles).toEqual([])
  })
})
