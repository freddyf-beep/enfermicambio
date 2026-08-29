import { supabase } from './supabase.js'

export async function loadTrainingState() {
  if (!supabase) return null
  const { data: auth } = await supabase.auth.getUser()
  if (!auth.user) return null
  const { data, error } = await supabase.from('training_states').select('state,updated_at').eq('user_id', auth.user.id).maybeSingle()
  if (error) throw error
  return data?.state || null
}

export async function saveTrainingState(state) {
  if (!supabase) return
  const { data: auth } = await supabase.auth.getUser()
  if (!auth.user) return
  const { error } = await supabase.from('training_states').upsert({ user_id: auth.user.id, state }, { onConflict: 'user_id' })
  if (error) throw error
}
