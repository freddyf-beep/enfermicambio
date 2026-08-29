import { readFileSync, renameSync, writeFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

const input = process.argv[2]?.trim() || ''
let shortcutUrl
try {
  const candidate = new URL(input)
  const sharedId = candidate.pathname.match(/^\/shortcuts\/([a-zA-Z0-9]+)\/?$/)?.[1]
  if (candidate.protocol !== 'https:' || candidate.hostname !== 'www.icloud.com' || !sharedId) throw new Error()
  shortcutUrl = `https://www.icloud.com/shortcuts/${sharedId}`
} catch {
  console.error('Uso: npm run shortcut:configure -- https://www.icloud.com/shortcuts/ID')
  process.exit(2)
}

const envPath = fileURLToPath(new URL('../.env.production', import.meta.url))
const temporaryPath = `${envPath}.shortcut-update`
const original = readFileSync(envPath, 'utf8')
const key = 'VITE_IOS_HEALTH_SHORTCUT_URL'
const line = `${key}=${shortcutUrl}`
const lines = original.replace(/\r\n/g, '\n').split('\n')
const index = lines.findIndex(value => value.startsWith(`${key}=`))
if (index >= 0) lines[index] = line
else {
  if (lines.at(-1) !== '') lines.push('')
  lines.push(line)
}

writeFileSync(temporaryPath, lines.join('\n'), { encoding: 'utf8', mode: 0o600 })
renameSync(temporaryPath, envPath)
console.log(`Plantilla configurada: ${shortcutUrl}`)
console.log('Siguiente paso: npm test && npm run build')
