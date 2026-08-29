// @vitest-environment happy-dom
import { beforeEach, describe, expect, it, vi } from 'vitest'

describe('PWA install bridge', () => {
  beforeEach(() => { vi.resetModules() })

  it('captures the browser prompt and reports an accepted installation', async () => {
    const bridge = await import('./pwa-install.js')
    const prompt = vi.fn()
    const event = new Event('beforeinstallprompt')
    Object.defineProperties(event, {
      prompt: { value: prompt },
      userChoice: { value: Promise.resolve({ outcome: 'accepted' }) },
    })
    window.dispatchEvent(event)
    expect(bridge.installAvailable()).toBe(true)
    await expect(bridge.requestInstall()).resolves.toBe(true)
    expect(prompt).toHaveBeenCalledOnce()
    expect(bridge.installAvailable()).toBe(false)
  })

  it('recognizes standalone mode without prompting again', async () => {
    window.matchMedia = vi.fn(() => ({ matches: true }))
    const bridge = await import('./pwa-install.js')
    expect(bridge.isInstalled()).toBe(true)
  })
})
