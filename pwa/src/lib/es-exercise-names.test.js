import { afterEach, describe, expect, it } from 'vitest'
import { _setLangState, exerciseNameFor, exerciseNameSearchText } from './i18n-core.js'

describe('Spanish exercise names', () => {
  afterEach(() => _setLangState('en', {}, null, null))

  it('shows the concise Spanish name while keeping English searchable', () => {
    const exercise = { id: '0025', n: 'barbell bench press' }
    _setLangState('es', {}, null, { '0025': 'press de banca con barra' })
    expect(exerciseNameFor(exercise)).toBe('press de banca con barra')
    expect(exerciseNameSearchText(exercise)).toBe('press de banca con barra barbell bench press')
  })
})
