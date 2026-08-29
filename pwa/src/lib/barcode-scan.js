const PRODUCT_FORMATS = ['ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_128']

export const normalizeBarcodeValue = value => String(value || '').replace(/\D/g, '')

async function nativeScan(file) {
  if (!('BarcodeDetector' in window)) return ''
  const supported = typeof window.BarcodeDetector.getSupportedFormats === 'function'
    ? await window.BarcodeDetector.getSupportedFormats()
    : PRODUCT_FORMATS
  const formats = PRODUCT_FORMATS.filter(format => supported.includes(format))
  if (!formats.length) return ''
  const detector = new window.BarcodeDetector({ formats })
  const bitmap = await createImageBitmap(file)
  try {
    const [result] = await detector.detect(bitmap)
    return normalizeBarcodeValue(result?.rawValue)
  } finally { bitmap.close?.() }
}

const imageFromFile = file => new Promise((resolve, reject) => {
  const url = URL.createObjectURL(file)
  const image = new Image()
  image.decoding = 'async'
  image.onload = () => resolve({ image, url })
  image.onerror = () => { URL.revokeObjectURL(url); reject(new Error('No se pudo leer la foto.')) }
  image.src = url
})

async function zxingScan(file) {
  const [{ BrowserMultiFormatReader }, { BarcodeFormat, DecodeHintType }] = await Promise.all([
    import('@zxing/browser'),
    import('@zxing/library'),
  ])
  const hints = new Map()
  hints.set(DecodeHintType.POSSIBLE_FORMATS, [BarcodeFormat.EAN_13, BarcodeFormat.EAN_8, BarcodeFormat.UPC_A, BarcodeFormat.UPC_E, BarcodeFormat.CODE_128])
  hints.set(DecodeHintType.TRY_HARDER, true)
  const reader = new BrowserMultiFormatReader(hints)
  const { image, url } = await imageFromFile(file)
  try {
    const result = await reader.decodeFromImageElement(image)
    return normalizeBarcodeValue(result?.getText?.() || result?.text)
  } finally { URL.revokeObjectURL(url) }
}

export async function scanBarcodeFile(file) {
  if (!file?.type?.startsWith('image/')) throw new Error('Elige una foto del código de barras.')
  try {
    const native = await nativeScan(file)
    if (native) return native
  } catch { /* ZXing is the cross-browser fallback. */ }
  try {
    const decoded = await zxingScan(file)
    if (decoded) return decoded
  } catch { /* Present one stable message instead of decoder internals. */ }
  throw new Error('No pude leer el código. Acerca la cámara, evita reflejos y prueba otra vez.')
}
