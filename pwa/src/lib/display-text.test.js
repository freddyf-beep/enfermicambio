import { describe, expect, it } from 'vitest'
import { readableSocialText } from './display-text.js'

describe('readableSocialText', () => {
  it('repairs historical UTF-8 mojibake and keeps emoji intact', () => {
    expect(readableSocialText('DÃ­a perfecto ðŸ”¥')).toBe('Día perfecto 🔥')
  })

  it('normalizes the old English empty winner label', () => {
    expect(readableSocialText('No one ganó el día')).toBe('Nadie ganó el día')
  })
})
