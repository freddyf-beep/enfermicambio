import { create } from 'zustand'
import { competitionDate, supabase } from '../lib/supabase.js'

const demoProfiles = [
  { id: 'demo-1', display_name: 'Freddy', daily_step_target: 10000 },
  { id: 'demo-2', display_name: 'Felipe', daily_step_target: 10000 },
  { id: 'demo-3', display_name: 'Cristian', daily_step_target: 10000 },
  { id: 'demo-4', display_name: 'Samir', daily_step_target: 10000 },
]
const demoActivity = [8420, 8950, 7310, 9800].map((daily_steps, i) => ({
  user_id: demoProfiles[i].id, activity_date: competitionDate(), daily_steps,
  active_calories: 380 + i * 55, distance_meters: daily_steps * .73,
  exercise_minutes: 25 + i * 8, synced_at: new Date(Date.now() - i * 180000).toISOString(),
}))

export const useSocial = create((set, get) => ({
  session: null, profile: null, profiles: [], activity: [], posts: [],
  standings: [], notifications: [], ready: false, demo: !supabase, error: null,

  async boot() {
    if (!supabase) {
      set({
        ready: true, demo: true, profiles: demoProfiles, activity: demoActivity,
        profile: demoProfiles[0],
        posts: [
          { id: 'demo-post-1', author_id: 'demo-4', post_type: 'workout', caption: 'Carrera completada · 6,2 km', created_at: new Date().toISOString() },
          { id: 'demo-post-2', author_id: 'demo-1', post_type: 'steps', caption: 'Alcanzó 8.000 pasos', created_at: new Date(Date.now() - 3600000).toISOString() },
        ],
        standings: demoProfiles.map((p, i) => ({ user_id: p.id, display_name: p.display_name, total_points: 42 - i * 6, position: i + 1 })),
      })
      return () => {}
    }
    const { data } = await supabase.auth.getSession()
    set({ session: data.session, ready: true, demo: false })
    if (data.session) await get().refresh()
    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
      set({ session, profile: null })
      if (session) setTimeout(() => get().refresh(), 0)
    })
    return () => listener.subscription.unsubscribe()
  },

  async signIn(email, password) {
    if (!supabase) return
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error
  },
  async signInWithGoogle() {
    if (!supabase) return
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google', options: { redirectTo: window.location.origin + window.location.pathname },
    })
    if (error) throw error
  },
  async signOut() {
    if (supabase) await supabase.auth.signOut()
    set({ session: null, profile: null })
  },

  async refresh() {
    if (!supabase) return
    const uid = get().session?.user?.id
    if (!uid) return
    set({ error: null })
    const day = competitionDate()
    const [profiles, activity, posts, standings, notifications] = await Promise.all([
      supabase.from('profiles').select('id,display_name,avatar_url,daily_step_target,daily_calorie_target,weekly_workout_target,weight_goal_kg'),
      supabase.from('daily_activity').select('user_id,activity_date,daily_steps,morning_steps,afternoon_steps,night_steps,active_calories,distance_meters,exercise_minutes,synced_at').eq('activity_date', day),
      supabase.from('posts').select('id,author_id,post_type,caption,created_at,system_generated').order('created_at', { ascending: false }).limit(30),
      supabase.from('season_standings').select('season_id,user_id,display_name,total_points,position').order('position'),
      supabase.from('notifications').select('id,type,title,body,is_read,created_at').order('created_at', { ascending: false }).limit(20),
    ])
    const error = [profiles, activity, posts, standings, notifications].find(x => x.error)?.error
    const list = profiles.data || []
    set({
      profiles: list, profile: list.find(p => p.id === uid) || null,
      activity: activity.data || [], posts: posts.data || [],
      standings: standings.data || [], notifications: notifications.data || [],
      error: error?.message || null,
    })
  },

  async createPost(caption) {
    const uid = get().session?.user?.id
    if (!caption.trim()) return
    if (!supabase) {
      set({ posts: [{ id: crypto.randomUUID(), author_id: get().profile?.id, post_type: 'text', caption: caption.trim(), created_at: new Date().toISOString() }, ...get().posts] })
      return
    }
    if (!uid) return
    const { error } = await supabase.from('posts').insert({ author_id: uid, post_type: 'text', caption: caption.trim(), system_generated: false })
    if (error) throw error
    await get().refresh()
  },
  async logFood(entry) {
    const mealLabel = { breakfast: 'Desayuno', lunch: 'Almuerzo', dinner: 'Cena', snack: 'Snack', other: 'Otro' }[entry.meal_type] || 'Comida'
    const uid = get().session?.user?.id
    if (!supabase) {
      set({ posts: [{ id: crypto.randomUUID(), author_id: get().profile?.id, post_type: 'meal', caption: `${mealLabel}: ${Math.round(entry.calories)} kcal`, created_at: new Date().toISOString() }, ...get().posts] })
      return
    }
    if (!uid) return
    const payload = { ...entry, user_id: uid, logged_at: new Date().toISOString(), source: 'manual_pwa' }
    const { data, error } = await supabase.from('food_entries').insert(payload).select('id').single()
    if (error) throw error
    await supabase.from('posts').insert({ author_id: uid, post_type: 'meal', caption: `${mealLabel}: ${Math.round(entry.calories)} kcal`, food_entry_id: data.id, system_generated: false })
    await get().refresh()
  },
}))
