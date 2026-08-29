import { describe, expect, it } from 'vitest'
import { fitImageDimensions } from './image-file.js'

describe('fitImageDimensions', () => {
  it('keeps a small photo unchanged', () => expect(fitImageDimensions(1200, 900)).toEqual({ width: 1200, height: 900 }))
  it('limits landscape and portrait photos without changing their ratio', () => {
    expect(fitImageDimensions(4000, 3000)).toEqual({ width: 1800, height: 1350 })
    expect(fitImageDimensions(2000, 4000)).toEqual({ width: 900, height: 1800 })
  })
})
