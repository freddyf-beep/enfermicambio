import { describe, expect, it, vi } from 'vitest'
import { validateHealthBridgeToken } from './healthBridge.js'

describe('validateHealthBridgeToken', () => {
  it('proves a generated Android token against the receiver', async () => {
    const fetchImpl = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ ok: true, validated: true, platform: 'android' }),
    })
    await expect(validateHealthBridgeToken('https://example.test/ingest', 'x'.repeat(64), 'android', fetchImpl))
      .resolves.toMatchObject({ validated: true })
    expect(fetchImpl).toHaveBeenCalledWith('https://example.test/ingest', expect.objectContaining({
      method: 'POST',
      headers: expect.objectContaining({ Authorization: `Bearer ${'x'.repeat(64)}` }),
      body: JSON.stringify({ source_platform: 'android', validate_only: true }),
    }))
  })

  it('surfaces a server-side token rejection', async () => {
    const fetchImpl = vi.fn().mockResolvedValue({
      ok: false,
      status: 401,
      json: async () => ({ error: 'Invalid token' }),
    })
    await expect(validateHealthBridgeToken('https://example.test/ingest', 'x'.repeat(64), 'ios', fetchImpl))
      .rejects.toThrow('Invalid token')
  })
})
