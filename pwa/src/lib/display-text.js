const CP1252 = new Map([
  ['€', 0x80], ['‚', 0x82], ['ƒ', 0x83], ['„', 0x84], ['…', 0x85], ['†', 0x86], ['‡', 0x87],
  ['ˆ', 0x88], ['‰', 0x89], ['Š', 0x8a], ['‹', 0x8b], ['Œ', 0x8c], ['Ž', 0x8e], ['‘', 0x91],
  ['’', 0x92], ['“', 0x93], ['”', 0x94], ['•', 0x95], ['–', 0x96], ['—', 0x97], ['˜', 0x98],
  ['™', 0x99], ['š', 0x9a], ['›', 0x9b], ['œ', 0x9c], ['ž', 0x9e], ['Ÿ', 0x9f],
])

const byteOf = char => char.charCodeAt(0) <= 255 ? char.charCodeAt(0) : CP1252.get(char)

// Old generated posts contain a small amount of UTF-8 that was interpreted as
// Latin-1 before it reached Supabase. Repair it at presentation time so history
// becomes readable without rewriting rows that belong to the users.
export function readableSocialText(value = '') {
  let raw = ''
  let bytes = []
  let output = ''
  const flush = () => {
    if (!raw) return
    if (/[ÃÂð]/.test(raw)) {
      try { output += new TextDecoder('utf-8', { fatal: true }).decode(Uint8Array.from(bytes)) }
      catch { output += raw }
    } else output += raw
    raw = ''; bytes = []
  }
  for (const char of String(value)) {
    const byte = byteOf(char)
    if (byte == null) { flush(); output += char }
    else { raw += char; bytes.push(byte) }
  }
  flush()
  return output.replace(/\bNo one\b/g, 'Nadie')
}
