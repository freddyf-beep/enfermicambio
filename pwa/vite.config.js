import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

const backend = process.env.API_TARGET || 'http://127.0.0.1:3000'
// The API refuses a state-changing request that a browser sent from anywhere other than its own
// ORIGIN (the CSRF guard in api/server.js). The dev server is on a different port, so the page's
// real Origin is not ORIGIN — modern browsers get through on Sec-Fetch-Site: same-origin, and
// presenting the expected Origin here covers the ones that don't send it. Match your .env if you
// changed ORIGIN: API_ORIGIN=https://gym.example.com npm run dev
const apiOrigin = process.env.API_ORIGIN || 'http://localhost:8080'
const media = process.env.MEDIA_TARGET || 'http://127.0.0.1:8888'

// Optional web analytics (Umami). Injected only when BOTH vars are set at build time,
// so a plain `npm run build` — and every self-hosted install — stays telemetry-free.
// Set for the public instance: VITE_UMAMI_SRC=https://stats.example/script.js VITE_UMAMI_ID=<uuid>
const umamiSrc = process.env.VITE_UMAMI_SRC
const umamiId = process.env.VITE_UMAMI_ID

const umami = {
  name: 'opengym-umami',
  transformIndexHtml() {
    if (!umamiSrc || !umamiId) return
    return [{
      tag: 'script',
      attrs: { defer: true, src: umamiSrc, 'data-website-id': umamiId },
      injectTo: 'head'
    }]
  }
}

// The version people are asked for in #install-help and on every bug report. Read from
// package.json so it cannot drift from the release it was built in, and inlined at build
// time so no runtime fetch is involved.
const pkgVersion = JSON.parse(readFileSync(new URL('./package.json', import.meta.url), 'utf8')).version

export default defineConfig(({ mode }) => {
  // Local development reuses the repository-root Flutter/Supabase environment
  // without copying credentials into another file. Production hosts should set
  // the VITE_* variables directly. Tests always stay in isolated demo mode.
  const shared = mode === 'test' ? {} : loadEnv(mode, resolve(process.cwd(), '..'), '')
  const supabaseUrl = process.env.VITE_SUPABASE_URL || shared.SUPABASE_URL
  const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY || shared.SUPABASE_ANON_KEY
  const competitionTz = process.env.VITE_COMPETITION_TZ || shared.COMPETITION_TZ || 'America/Santiago'
  const envDefines = {
    'import.meta.env.VITE_COMPETITION_TZ': JSON.stringify(competitionTz),
  }
  if (supabaseUrl) envDefines['import.meta.env.VITE_SUPABASE_URL'] = JSON.stringify(supabaseUrl)
  if (supabaseAnonKey) envDefines['import.meta.env.VITE_SUPABASE_ANON_KEY'] = JSON.stringify(supabaseAnonKey)

  return {
    define: { __APP_VERSION__: JSON.stringify(pkgVersion), ...envDefines },
    plugins: [react(), umami],
    base: './',
    server: {
      proxy: {
        '/api': { target: backend, changeOrigin: true, headers: { Origin: apiOrigin } },
        '/img': { target: media, changeOrigin: true },
        '/gif': { target: media, changeOrigin: true }
      }
    },
    build: {
      chunkSizeWarningLimit: 1600,
      rollupOptions: {
        output: {
          manualChunks(id) {
            if (id.includes('node_modules/react') || id.includes('node_modules/react-router')) {
              return 'react'
            }
            if (id.includes('node_modules/@supabase/supabase-js')) {
              return 'supabase'
            }
            return undefined
          },
        },
      },
    }
  }
})
