import { beforeEach, describe, expect, it, vi } from 'vitest'

const mocks = vi.hoisted(() => ({
  getUser: vi.fn(), maybeSingle: vi.fn(), upsert: vi.fn(),
}))

vi.mock('./supabase.js', () => ({
  supabase: {
    auth: { getUser: mocks.getUser },
    from: vi.fn(() => ({
      select: vi.fn(() => ({ eq: vi.fn(() => ({ maybeSingle: mocks.maybeSingle })) })),
      upsert: mocks.upsert,
    })),
  },
}))

import { loadTrainingState, saveTrainingState } from './training-cloud.js'

describe('authenticated training cloud', () => {
  beforeEach(() => vi.clearAllMocks())

  it('loads the signed-in user state', async () => {
    mocks.getUser.mockResolvedValue({ data: { user: { id: 'user-1' } } })
    mocks.maybeSingle.mockResolvedValue({ data: { state: { routines: [1] } }, error: null })
    await expect(loadTrainingState()).resolves.toEqual({ routines: [1] })
  })

  it('upserts state under the authenticated user id', async () => {
    mocks.getUser.mockResolvedValue({ data: { user: { id: 'user-1' } } })
    mocks.upsert.mockResolvedValue({ error: null })
    await saveTrainingState({ active: null })
    expect(mocks.upsert).toHaveBeenCalledWith({ user_id: 'user-1', state: { active: null } }, { onConflict: 'user_id' })
  })

  it('does not write when there is no authenticated user', async () => {
    mocks.getUser.mockResolvedValue({ data: { user: null } })
    await saveTrainingState({ active: true })
    expect(mocks.upsert).not.toHaveBeenCalled()
  })
})
