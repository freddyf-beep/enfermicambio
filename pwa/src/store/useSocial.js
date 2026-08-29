import { create } from 'zustand'
import { competitionDate, supabase } from '../lib/supabase.js'
import { aggregateRanking, dateInCompetitionTimezone, rankingRange, splitStorageReference } from '../lib/social-domain.js'

const demoProfiles = [
  { id: 'demo-1', display_name: 'Freddy', daily_step_target: 10000, daily_calorie_target: 2200 },
  { id: 'demo-2', display_name: 'Felipe', daily_step_target: 10000, daily_calorie_target: 2350 },
  { id: 'demo-3', display_name: 'Cristian', daily_step_target: 10000, daily_calorie_target: 2100 },
  { id: 'demo-4', display_name: 'Samir', daily_step_target: 10000, daily_calorie_target: 2450 },
]
const demoActivity = [8420, 8950, 7310, 9800].map((daily_steps, i) => ({
  user_id: demoProfiles[i].id, activity_date: competitionDate(), daily_steps,
  morning_steps: Math.round(daily_steps * .3), afternoon_steps: Math.round(daily_steps * .45), night_steps: Math.round(daily_steps * .25),
  active_calories: 380 + i * 55, distance_meters: daily_steps * .73,
  exercise_minutes: 25 + i * 8, synced_at: new Date(Date.now() - i * 180000).toISOString(),
}))
const demoStandings = demoProfiles.map((profile, index) => ({ user_id: profile.id, display_name: profile.display_name, total_points: 42 - index * 6, position: index + 1 }))
const demoFoodEntries = [
  { id: 'demo-food-1', user_id: 'demo-1', meal_type: 'breakfast', food_name_snapshot: 'Avena con fruta', notes: 'Avena con fruta', calories: 430, protein_g: 18, carbs_g: 64, fat_g: 11, logged_at: new Date(Date.now() - 6 * 3600000).toISOString() },
  { id: 'demo-food-2', user_id: 'demo-1', meal_type: 'lunch', food_name_snapshot: 'Pollo, arroz y ensalada', notes: 'Pollo, arroz y ensalada', calories: 720, protein_g: 46, carbs_g: 82, fat_g: 19, logged_at: new Date(Date.now() - 2 * 3600000).toISOString() },
]
const demoActivityHistory = Array.from({ length: 7 }, (_, index) => ({
  ...demoActivity[0],
  activity_date: dateInCompetitionTimezone(new Date(Date.now() - (6 - index) * 86400000)),
  daily_steps: [7100, 9650, 8200, 10400, 6800, 11200, 8420][index],
}))
const emptyGame = { season: null, missions: [], missionProgress: [], achievements: [], unlocked: [], streaks: [], tiers: [], claims: [], history: [] }

const resultData = result => {
  if (result.error) throw result.error
  return result.data || []
}

async function resolveMediaUrl(reference) {
  if (!reference) return null
  const parsed = splitStorageReference(reference)
  if (!parsed) return reference
  const { data, error } = await supabase.storage.from(parsed.bucket).createSignedUrl(parsed.path, 3600)
  return error ? null : data?.signedUrl || null
}

async function enrichPosts(posts) {
  if (!posts.length) return []
  const ids = posts.map(post => post.id)
  const [mediaResult, reactionsResult, commentsResult] = await Promise.all([
    supabase.from('post_media').select('post_id,url,media_type,sort_order').in('post_id', ids).order('sort_order'),
    supabase.from('reactions').select('post_id,user_id,emoji').in('post_id', ids),
    supabase.from('comments').select('id,post_id,author_id,body,created_at').in('post_id', ids).order('created_at'),
  ])
  const resolved = await Promise.all((mediaResult.data || []).map(async item => ({ ...item, resolved_url: await resolveMediaUrl(item.url) })))
  return posts.map(post => ({
    ...post,
    media: resolved.filter(item => item.post_id === post.id && item.resolved_url),
    reactions: (reactionsResult.data || []).filter(item => item.post_id === post.id),
    comments: (commentsResult.data || []).filter(item => item.post_id === post.id),
  }))
}

export const useSocial = create((set, get) => ({
  session: null, profile: null, nutritionProfile: null, profiles: [], activity: [], activityHistory: [], foodEntries: [], posts: [], standings: [], notifications: [], weightEntries: [],
  rankingRows: [], rankingLoading: false, game: emptyGame, gameLoading: false,
  ready: false, demo: !supabase, error: null,

  async boot() {
    if (!supabase) {
      set({
        ready: true, demo: true, profiles: demoProfiles, activity: demoActivity, profile: demoProfiles[0],
        posts: [
          { id: 'demo-post-1', author_id: 'demo-4', post_type: 'workout', caption: 'Carrera completada · 6,2 km. Costó partir, pero salió mejor de lo esperado.', created_at: new Date().toISOString(), media: [], reactions: [{ user_id: 'demo-2', emoji: '🔥' }, { user_id: 'demo-3', emoji: '🔥' }], comments: [{ id: 'demo-comment-1', author_id: 'demo-2', body: '¡Buen ritmo! Mañana me sumo.', created_at: new Date().toISOString() }] },
          { id: 'demo-post-2', author_id: 'demo-1', post_type: 'steps', caption: 'Alcanzó 8.000 pasos y quedó muy cerca de su meta diaria.', created_at: new Date(Date.now() - 3600000).toISOString(), media: [], reactions: [{ user_id: 'demo-2', emoji: '🔥' }], comments: [] },
        ],
        standings: demoStandings,
        activityHistory: demoActivityHistory,
        foodEntries: demoFoodEntries,
        notifications: [
          { id: 'demo-notice-1', type: 'comment', title: 'Felipe comentó tu publicación', body: '“¡Buen ritmo! Mañana me sumo.”', payload: { post_id: 'demo-post-1' }, is_read: false, created_at: new Date().toISOString() },
          { id: 'demo-notice-2', type: 'feed_post', title: 'Samir compartió un entrenamiento', body: 'Carrera completada · 6,2 km', payload: { post_id: 'demo-post-1' }, is_read: false, created_at: new Date(Date.now() - 3600000).toISOString() },
          { id: 'demo-notice-3', type: 'achievement', title: 'Primer impulso', body: 'Tu actividad ya está sumando para el equipo.', payload: {}, is_read: true, created_at: new Date(Date.now() - 86400000).toISOString() },
        ],
        weightEntries: [{ id: 'demo-weight', entry_date: competitionDate(), weight_kg: 78.4, source: 'manual' }],
        nutritionProfile: { user_id: demoProfiles[0].id, height_cm: 176 },
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
    const { error } = await supabase.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: window.location.origin + window.location.pathname } })
    if (error) throw error
  },
  async signOut() {
    if (supabase) await supabase.auth.signOut()
    set({ session: null, profile: null, game: emptyGame })
  },

  async refresh() {
    if (!supabase) return
    const uid = get().session?.user?.id
    if (!uid) return
    set({ error: null })
    const day = competitionDate()
    const historyStart = dateInCompetitionTimezone(new Date(Date.now() - 6 * 86400000))
    const todayRange = rankingRange('today')
    const [profiles, activity, activityHistory, foodEntries, posts, standings, notifications, weightEntries, nutritionProfile] = await Promise.all([
      supabase.from('profiles').select('id,display_name,avatar_url,profile_title,daily_step_target,daily_calorie_target,weekly_workout_target,weight_goal_kg'),
      supabase.from('daily_activity').select('user_id,activity_date,daily_steps,morning_steps,afternoon_steps,night_steps,active_calories,distance_meters,exercise_minutes,synced_at').eq('activity_date', day).eq('manual_entry_detected', false),
      supabase.from('daily_activity').select('user_id,activity_date,daily_steps,active_calories,distance_meters,exercise_minutes,synced_at').eq('user_id', uid).gte('activity_date', historyStart).lte('activity_date', day).eq('manual_entry_detected', false).order('activity_date'),
      supabase.from('food_entries').select('id,user_id,meal_type,logged_at,calories,protein_g,carbs_g,fat_g,notes,source').eq('user_id', uid).gte('logged_at', todayRange.startIso).lt('logged_at', todayRange.endExclusiveIso).order('logged_at'),
      supabase.from('posts').select('id,author_id,post_type,caption,created_at,system_generated').order('created_at', { ascending: false }).limit(30),
      supabase.from('season_standings').select('season_id,user_id,display_name,total_points,position').order('position'),
      supabase.from('notifications').select('id,type,title,body,payload,is_read,created_at').order('created_at', { ascending: false }).limit(20),
      supabase.from('weight_entries').select('id,entry_date,weight_kg,source,created_at').eq('user_id', uid).order('entry_date', { ascending: false }).limit(30),
      supabase.from('nutrition_profiles').select('user_id,height_cm').eq('user_id', uid).maybeSingle(),
    ])
    const error = [profiles, activity, activityHistory, foodEntries, posts, standings, notifications, weightEntries, nutritionProfile].find(item => item.error)?.error
    const list = profiles.data || []
    const enrichedPosts = await enrichPosts(posts.data || [])
    set({
      profiles: list, profile: list.find(profile => profile.id === uid) || null,
      activity: activity.data || [], activityHistory: activityHistory.data || [], foodEntries: foodEntries.data || [], posts: enrichedPosts, standings: standings.data || [], notifications: notifications.data || [],
      weightEntries: weightEntries.data || [], nutritionProfile: nutritionProfile.data || null, error: error?.message || null,
    })
  },

  async saveWeight(weightKg, goalKg) {
    const uid = get().session?.user?.id || get().profile?.id
    const weight = Number(weightKg)
    const goal = goalKg === '' || goalKg == null ? null : Number(goalKg)
    if (!uid || weight < 20 || weight > 400) throw new Error('Ingresa un peso entre 20 y 400 kg.')
    if (goal != null && (goal < 20 || goal > 400)) throw new Error('La meta debe estar entre 20 y 400 kg.')
    if (!supabase) {
      const row = { id: crypto.randomUUID(), entry_date: competitionDate(), weight_kg: weight, source: 'manual' }
      set({ weightEntries: [row, ...get().weightEntries.filter(item => item.entry_date !== row.entry_date)], profile: { ...get().profile, weight_goal_kg: goal } })
      return
    }
    const weightResult = await supabase.from('weight_entries').upsert({ user_id: uid, entry_date: competitionDate(), weight_kg: weight, source: 'manual' }, { onConflict: 'user_id,entry_date' })
    if (weightResult.error) throw weightResult.error
    const goalResult = await supabase.from('profiles').update({ weight_goal_kg: goal }).eq('id', uid)
    if (goalResult.error) throw goalResult.error
    await supabase.rpc('notify_weight_goal', { p_user_id: uid })
    await get().refresh()
  },

  async savePhysicalProfile(heightCm, weightKg) {
    const uid = get().session?.user?.id || get().profile?.id
    const height = Number(heightCm)
    const weight = Number(weightKg)
    if (!uid || height < 100 || height > 250) throw new Error('Ingresa una altura entre 100 y 250 cm.')
    if (weight < 20 || weight > 400) throw new Error('Ingresa un peso entre 20 y 400 kg.')
    if (!supabase) {
      const row = { id: crypto.randomUUID(), entry_date: competitionDate(), weight_kg: weight, source: 'manual' }
      set({ nutritionProfile: { user_id: uid, height_cm: height }, weightEntries: [row, ...get().weightEntries.filter(item => item.entry_date !== row.entry_date)] })
      return
    }
    const [heightResult, weightResult] = await Promise.all([
      supabase.from('nutrition_profiles').upsert({ user_id: uid, height_cm: height }, { onConflict: 'user_id' }),
      supabase.from('weight_entries').upsert({ user_id: uid, entry_date: competitionDate(), weight_kg: weight, source: 'manual' }, { onConflict: 'user_id,entry_date' }),
    ])
    if (heightResult.error) throw heightResult.error
    if (weightResult.error) throw weightResult.error
    await get().refresh()
  },

  async saveOutdoorActivity(activity) {
    const uid = get().session?.user?.id || get().profile?.id
    if (!uid) throw new Error('Inicia sesión para guardar la actividad.')
    const duration = Math.max(1, Math.round(Number(activity.durationSeconds) || 0))
    const points = Array.isArray(activity.points) ? activity.points : []
    if (!supabase) return { id: crypto.randomUUID(), demo: true }
    const workoutId = crypto.randomUUID()
    const workout = {
      id: workoutId,
      user_id: uid,
      external_id: `pwa-gps-${workoutId}`,
      source: 'pwa_gps',
      workout_type: activity.type || 'walking',
      started_at: activity.startedAt,
      ended_at: activity.endedAt,
      duration_seconds: duration,
      distance_meters: Math.max(0, Number(activity.distanceMeters) || 0),
      route_available: points.length > 1,
      route_visibility: 'private',
    }
    const inserted = await supabase.from('workouts').insert(workout)
    if (inserted.error) throw inserted.error
    if (points.length) {
      const rows = points.map(point => ({ workout_id: workoutId, timestamp: point.timestamp, latitude: point.latitude, longitude: point.longitude, altitude: point.altitude, accuracy: point.accuracy, bearing: point.heading }))
      const route = await supabase.from('workout_route_points').insert(rows)
      if (route.error) {
        await supabase.from('workouts').delete().eq('id', workoutId)
        throw route.error
      }
    }
    return { id: workoutId }
  },

  async markNotificationRead(id) {
    const targets = id ? get().notifications.filter(item => item.id === id) : get().notifications.filter(item => !item.is_read)
    if (!targets.length) return
    if (!supabase) {
      set({ notifications: get().notifications.map(item => !id || item.id === id ? { ...item, is_read: true } : item) })
      return
    }
    let query = supabase.from('notifications').update({ is_read: true })
    query = id ? query.eq('id', id) : query.in('id', targets.map(item => item.id))
    const { error } = await query
    if (error) throw error
    set({ notifications: get().notifications.map(item => !id || item.id === id ? { ...item, is_read: true } : item) })
  },

  async loadRanking(category = 'daily_steps', period = 'today') {
    set({ rankingLoading: true })
    try {
      if (!supabase) {
        set({ rankingRows: aggregateRanking({ profiles: demoProfiles, activity: demoActivity, standings: period === 'season' && category === 'points' ? demoStandings : [], category }) })
        return
      }
      const activeSeasonResult = await supabase.from('seasons').select('id,name,starts_at,ends_at,status').eq('status', 'active').order('starts_at', { ascending: false }).limit(1).maybeSingle()
      if (activeSeasonResult.error) throw activeSeasonResult.error
      const range = rankingRange(period, activeSeasonResult.data)
      const activityPromise = supabase.from('daily_activity').select('user_id,activity_date,daily_steps,morning_steps,afternoon_steps,night_steps,active_calories,distance_meters,synced_at').gte('activity_date', range.start).lte('activity_date', range.end).eq('manual_entry_detected', false)
      const workoutsPromise = category === 'workouts' ? supabase.from('workouts').select('user_id').gte('started_at', range.startIso).lt('started_at', range.endExclusiveIso) : Promise.resolve({ data: [], error: null })
      const useStandings = category === 'points' && period === 'season'
      const pointsPromise = category === 'points' && !useStandings ? supabase.from('season_points').select('user_id,points,created_at').gte('created_at', range.startIso).lt('created_at', range.endExclusiveIso) : Promise.resolve({ data: [], error: null })
      const standingsPromise = useStandings ? supabase.from('season_standings').select('user_id,total_points,position') : Promise.resolve({ data: [], error: null })
      const [activity, workouts, points, standings] = await Promise.all([activityPromise, workoutsPromise, pointsPromise, standingsPromise])
      const rows = aggregateRanking({ profiles: get().profiles, activity: resultData(activity), workouts: resultData(workouts), points: resultData(points), standings: resultData(standings), category })
      set({ rankingRows: rows, error: null })
    } catch (error) {
      set({ error: error.message || String(error) })
    } finally {
      set({ rankingLoading: false })
    }
  },

  async loadGame() {
    const uid = get().session?.user?.id || get().profile?.id
    set({ gameLoading: true })
    try {
      if (!supabase) {
        set({ game: {
          season: { id: 'demo-season', name: 'Temporada de prueba', starts_at: new Date().toISOString(), ends_at: new Date(Date.now() + 30 * 86400000).toISOString() },
          missions: [{ id: 'demo-mission', name: 'Caminar juntos', description: 'Completen 30.000 pasos entre todos.', mission_type: 'cooperative', reward_points: 5, rules: { target: 30000 } }],
          missionProgress: [{ mission_id: 'demo-mission', user_id: null, progress: { current: 22400, target: 30000 }, completed: false }],
          achievements: [{ id: 'demo-achievement', name: 'Primer impulso', description: 'Cumple tu primera meta diaria.', icon: '⚡' }], unlocked: [],
          streaks: [{ user_id: 'demo-1', streak_type: 'steps', current_count: 4, longest_count: 7 }],
          tiers: [{ tier: 1, threshold_points: 20, reward_name: 'Constancia', reward_icon: '🔥' }], claims: [], history: [],
        } })
        return
      }
      const day = competitionDate()
      const seasonResult = await supabase.from('seasons').select('id,name,starts_at,ends_at,status').eq('status', 'active').order('starts_at', { ascending: false }).limit(1).maybeSingle()
      if (seasonResult.error) throw seasonResult.error
      const season = seasonResult.data
      const [missions, progress, achievements, unlocked, streaks, tiers, claims, history] = await Promise.all([
        supabase.rpc('daily_missions_for_date', { p_date: day }),
        supabase.from('mission_progress').select('mission_id,user_id,progress_date,progress,completed,completed_at').eq('progress_date', day),
        supabase.from('achievements').select('id,code,name,description,icon,hidden,season_points').order('threshold'),
        supabase.from('user_achievements').select('achievement_id,unlocked_at,context').eq('user_id', uid),
        supabase.from('streaks').select('user_id,streak_type,current_count,longest_count,last_qualified_date,profiles(display_name)').order('current_count', { ascending: false }),
        supabase.from('battle_pass_tiers').select('tier,threshold_points,reward_type,reward_key,reward_name,reward_icon').order('tier'),
        season ? supabase.from('battle_pass_claims').select('tier,claimed_at').eq('user_id', uid).eq('season_id', season.id) : Promise.resolve({ data: [], error: null }),
        supabase.from('season_results').select('season_id,user_id,final_rank,final_points,seasons(name),profiles(display_name)').limit(20),
      ])
      set({ game: { season, missions: resultData(missions), missionProgress: resultData(progress), achievements: resultData(achievements), unlocked: resultData(unlocked), streaks: resultData(streaks), tiers: resultData(tiers), claims: resultData(claims), history: resultData(history) }, error: null })
    } catch (error) {
      set({ error: error.message || String(error) })
    } finally {
      set({ gameLoading: false })
    }
  },

  async claimBattlePass(tier) {
    const season = get().game.season
    if (!season || !supabase) return
    const { error } = await supabase.rpc('claim_battle_pass_reward', { p_season_id: season.id, p_tier: tier })
    if (error) throw error
    await get().loadGame()
  },

  async createPost(caption) {
    const text = caption.trim()
    if (!text) return
    const uid = get().session?.user?.id
    if (!supabase) {
      set({ posts: [{ id: crypto.randomUUID(), author_id: get().profile?.id, post_type: 'text', caption: text, created_at: new Date().toISOString(), media: [], reactions: [], comments: [] }, ...get().posts] })
      return
    }
    if (!uid) return
    const { error } = await supabase.from('posts').insert({ author_id: uid, post_type: 'text', caption: text, system_generated: false })
    if (error) throw error
    await get().refresh()
  },

  async createPhotoPost(caption, file) {
    const uid = get().session?.user?.id
    if (!file) return get().createPost(caption)
    if (!supabase) {
      const url = URL.createObjectURL(file)
      set({ posts: [{ id: crypto.randomUUID(), author_id: get().profile?.id, post_type: 'photo', caption: caption.trim() || 'Compartió una foto', created_at: new Date().toISOString(), media: [{ resolved_url: url, media_type: 'image' }], reactions: [], comments: [] }, ...get().posts] })
      return
    }
    if (!uid) return
    const extension = file.name?.split('.').pop()?.toLowerCase() || 'jpg'
    const path = `${uid}/${crypto.randomUUID()}.${extension}`
    const upload = await supabase.storage.from('feed-media').upload(path, file, { contentType: file.type || 'image/jpeg', upsert: false })
    if (upload.error) throw upload.error
    try {
      const post = await supabase.from('posts').insert({ author_id: uid, post_type: 'photo', caption: caption.trim() || 'Compartió una foto', system_generated: false }).select('id').single()
      if (post.error) throw post.error
      const media = await supabase.from('post_media').insert({ post_id: post.data.id, url: `feed-media/${path}`, media_type: 'image', sort_order: 0 })
      if (media.error) throw media.error
    } catch (error) {
      await supabase.storage.from('feed-media').remove([path])
      throw error
    }
    await get().refresh()
  },

  async toggleReaction(postId, emoji = '🔥') {
    const uid = get().session?.user?.id || get().profile?.id
    if (!uid) return
    const post = get().posts.find(item => item.id === postId)
    const exists = post?.reactions?.some(reaction => reaction.user_id === uid && reaction.emoji === emoji)
    const previousReactions = post?.reactions || []
    const nextReactions = exists
      ? previousReactions.filter(reaction => !(reaction.user_id === uid && reaction.emoji === emoji))
      : [...previousReactions, { user_id: uid, emoji }]
    if (!supabase) {
      set({ posts: get().posts.map(item => item.id !== postId ? item : { ...item, reactions: nextReactions }) })
      return
    }
    // Make the tap visible immediately. A network round-trip plus a full feed refresh
    // previously made the button look inert on mobile connections.
    set({ posts: get().posts.map(item => item.id !== postId ? item : { ...item, reactions: nextReactions }) })
    const query = exists ? supabase.from('reactions').delete().eq('post_id', postId).eq('user_id', uid).eq('emoji', emoji) : supabase.from('reactions').insert({ post_id: postId, user_id: uid, emoji })
    const { error } = await query
    if (error) {
      set({ posts: get().posts.map(item => item.id !== postId ? item : { ...item, reactions: previousReactions }) })
      throw error
    }
    await get().refresh()
  },

  async addComment(postId, body, requestId = crypto.randomUUID()) {
    const text = body.trim()
    const uid = get().session?.user?.id || get().profile?.id
    if (!text || !uid) return
    if (!supabase) {
      set({ posts: get().posts.map(item => item.id !== postId ? item : { ...item, comments: [...item.comments, { id: crypto.randomUUID(), author_id: uid, body: text, created_at: new Date().toISOString() }] }) })
      return
    }
    const { error } = await supabase.rpc('create_comment_once', { p_post_id: postId, p_body: text, p_request_id: requestId })
    if (error) throw error
    await get().refresh()
  },

  async logFood(entry, file) {
    const mealLabel = { breakfast: 'Desayuno', lunch: 'Almuerzo', dinner: 'Cena', snack: 'Snack', other: 'Otro' }[entry.meal_type] || 'Comida'
    const uid = get().session?.user?.id
    const quantity = Math.max(.01, Number(entry.quantity) || 1)
    const foodName = String(entry.food_name_snapshot || entry.notes || 'Alimento').trim() || 'Alimento'
    const totals = {
      calories: (Number(entry.calories) || 0) * quantity,
      protein_g: (Number(entry.protein_g) || 0) * quantity,
      carbs_g: (Number(entry.carbs_g) || 0) * quantity,
      fat_g: (Number(entry.fat_g) || 0) * quantity,
    }
    if (!supabase) {
      const media = file ? [{ resolved_url: URL.createObjectURL(file), media_type: 'image' }] : []
      const row = { id: crypto.randomUUID(), user_id: get().profile?.id, meal_type: entry.meal_type, food_name_snapshot: foodName, notes: foodName, ...totals, logged_at: new Date().toISOString(), source: 'manual_pwa' }
      set({
        foodEntries: [...get().foodEntries, row],
        posts: [{ id: crypto.randomUUID(), author_id: get().profile?.id, post_type: 'meal', caption: `${mealLabel}: ${foodName} · ${Math.round(totals.calories)} kcal`, created_at: row.logged_at, media, reactions: [], comments: [] }, ...get().posts],
      })
      return
    }
    if (!uid) return
    let storagePath = null
    let foodEntryId = null
    let postId = null
    try {
      if (file) {
        const extension = file.name?.split('.').pop()?.toLowerCase() || 'jpg'
        storagePath = `${uid}/${crypto.randomUUID()}.${extension}`
        const upload = await supabase.storage.from('meal-media').upload(storagePath, file, { contentType: file.type || 'image/jpeg', upsert: false })
        if (upload.error) throw upload.error
      }
      const payload = { ...entry, ...totals, quantity, food_name_snapshot: foodName, notes: foodName, photo_url: storagePath ? `meal-media/${storagePath}` : null, user_id: uid, logged_at: new Date().toISOString(), source: 'manual_pwa' }
      const foodResult = await supabase.from('food_entries').insert(payload).select('id').single()
      if (foodResult.error) throw foodResult.error
      foodEntryId = foodResult.data.id
      const post = await supabase.from('posts').insert({ author_id: uid, post_type: 'meal', caption: `${mealLabel}: ${foodName} · ${Math.round(totals.calories)} kcal`, food_entry_id: foodEntryId, system_generated: false }).select('id').single()
      if (post.error) throw post.error
      postId = post.data.id
      if (storagePath) {
        const media = await supabase.from('post_media').insert({ post_id: postId, url: `meal-media/${storagePath}`, media_type: 'image', sort_order: 0 })
        if (media.error) throw media.error
      }
    } catch (error) {
      if (postId) await supabase.from('posts').delete().eq('id', postId)
      if (foodEntryId) await supabase.from('food_entries').delete().eq('id', foodEntryId)
      if (storagePath) await supabase.storage.from('meal-media').remove([storagePath])
      throw error
    }
    await get().refresh()
  },
}))
