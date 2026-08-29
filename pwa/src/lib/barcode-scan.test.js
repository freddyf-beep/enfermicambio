import { describe, expect, it } from 'vitest'
import { normalizeBarcodeValue } from './barcode-scan.js'

describe('barcode scanner', () => {
  it('keeps only the product-code digits', () => {
    expect(normalizeBarcodeValue(' 780-123 456 ')).toBe('780123456')
    expect(normalizeBarcodeValue()).toBe('')
  })
})
