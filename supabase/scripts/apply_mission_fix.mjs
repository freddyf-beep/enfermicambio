// Applies the evaluate_missions fix migration and runs the smoke test.
//
// Usage:
//   node supabase/scripts/apply_mission_fix.mjs "postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:6543/postgres"
//
// The connection string must use the transaction pooler (port 6543) or the
// direct connection from Supabase > Connect > Connection string.
import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const url = process.argv[2]
if (!url) {
  console.error('Missing connection string')
  process.exit(1)
}

const { Client } = await import('pg')
const client = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } })
await client.connect()

const __dirname = dirname(fileURLToPath(import.meta.url))
const migrationPath = join(__dirname, '..', 'migrations', '20260827100001_fix_evaluate_missions_ambiguity.sql')
const smokePath = join(__dirname, 'mission_close_day_smoke_test.sql')
const migration = await readFile(migrationPath, 'utf8')
const smoke = await readFile(smokePath, 'utf8')

console.log('applying migration...')
await client.query('begin')
try {
  await client.query(migration)
  await client.query('commit')
  console.log('migration applied')
} catch (error) {
  await client.query('rollback')
  console.error('migration failed:', error.message)
  await client.end()
  process.exit(1)
}

console.log('running smoke test...')
await client.query('begin')
try {
  const rows = await client.query(smoke)
  console.log('smoke test output rows:', rows.rows?.length ?? 0)
  await client.query('commit')
  console.log('smoke test passed')
} catch (error) {
  await client.query('rollback')
  console.error('smoke test failed:', error.message)
  await client.end()
  process.exit(1)
}

await client.end()
console.log('DONE')
