import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL?.trim()
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY?.trim()

export const supabaseConfigured = Boolean(url && anonKey)
export const supabase = supabaseConfigured
  ? createClient(url, anonKey, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
    })
  : null

export function requireSupabase() {
  if (!supabase) throw new Error('Falta configurar VITE_SUPABASE_URL y VITE_SUPABASE_ANON_KEY.')
  return supabase
}

export function competitionDate() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: import.meta.env.VITE_COMPETITION_TZ || 'America/Santiago',
    year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(new Date())
}
