import { describe, expect, it } from 'vitest'
import {
  buildIosHealthConfiguration,
  buildShortcutRunUrl,
  IOS_HEALTH_SHORTCUT_NAME,
  normalizeSharedShortcutUrl,
} from './iosShortcut.js'

describe('Apple Shortcuts integration', () => {
  it('builds the private configuration expected by the shared shortcut', () => {
    expect(JSON.parse(buildIosHealthConfiguration(' https://example.test/ingest ', ' secret-token '))).toEqual({
      endpoint: 'https://example.test/ingest',
      token: 'secret-token',
      source_platform: 'ios',
      shortcut: IOS_HEALTH_SHORTCUT_NAME,
    })
  })

  it('runs the installed shortcut with the clipboard as input', () => {
    expect(buildShortcutRunUrl()).toBe('shortcuts://run-shortcut?name=EnfermiCambio%20Salud&input=clipboard')
  })

  it('accepts only canonical shared iCloud shortcut links', () => {
    expect(normalizeSharedShortcutUrl('https://www.icloud.com/shortcuts/AbC123/')).toBe('https://www.icloud.com/shortcuts/AbC123')
    expect(normalizeSharedShortcutUrl('https://example.com/shortcuts/AbC123')).toBe('')
    expect(normalizeSharedShortcutUrl('https://www.icloud.com/drive/AbC123')).toBe('')
  })

  it('rejects incomplete private configuration', () => {
    expect(() => buildIosHealthConfiguration('', 'token')).toThrow('Faltan el endpoint o el token')
  })
})
