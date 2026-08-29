import { useEffect, useState } from 'react'
import { missionProgress, repairMojibake } from '../lib/social-domain.js'
import { useSocial } from '../store/useSocial.js'
import Icon from '../components/Icon.jsx'
import PulseCoach from '../components/PulseCoach.jsx'

const missionType = { individual: 'Individual', cooperative: 'Equipo', competitive: 'Competitiva' }
const streakName = value => ({ steps: 'Meta de pasos', step_goal: 'Meta de pasos', workout: 'Entrenamientos', nutrition: 'Nutrición', calorie_target: 'Meta de calorías', daily_goal: 'Meta diaria' }[value] || value)
const achievementIcon = value => ({
  fitness_center: 'dumbbell', directions_walk: 'figureRun', directions_run: 'figureRun', wb_twilight: 'sun',
  nightlight: 'moon', emoji_events: 'trophy', local_fire_department: 'flame', weekend: 'moon', star: 'star',
  workspace_premium: 'medal', route: 'route', military_tech: 'medal', flag: 'flag', auto_awesome: 'sparkles',
  sentiment_satisfied: 'personCircle', '⚡': 'bolt', '🔥': 'flame', '🏆': 'trophy', '🎖️': 'medal',
}[value] || 'medal')

export default function SocialGame() {
  const standings = useSocial(state => state.standings)
  const profiles = useSocial(state => state.profiles)
  const profile = useSocial(state => state.profile)
  const game = useSocial(state => state.game)
  const loading = useSocial(state => state.gameLoading)
  const error = useSocial(state => state.error)
  const loadGame = useSocial(state => state.loadGame)
  const claimBattlePass = useSocial(state => state.claimBattlePass)
  const [message, setMessage] = useState('')
  useEffect(() => { loadGame() }, [loadGame])

  const rows = standings.length ? standings : profiles.map((item, index) => ({ ...item, total_points: 0, position: index + 1 }))
  const mine = rows.find(row => row.user_id === profile?.id || row.id === profile?.id)
  const claimed = new Set(game.claims.map(claim => claim.tier))
  const unlocked = new Set(game.unlocked.map(item => item.achievement_id))
  const unlockedContext = new Map(game.unlocked.map(item => [item.achievement_id, item.context]))
  const missionRows = game.missions.map(mission => ({ mission, progress: missionProgress(mission, game.missionProgress, profile?.id) }))
  const completedMissions = missionRows.filter(item => item.progress.completed).length
  const mineStreaks = game.streaks.filter(streak => streak.user_id === profile?.id)
  const bestCurrentStreak = mineStreaks.reduce((best, streak) => Math.max(best, Number(streak.current_count || 0)), 0)
  const points = Number(mine?.total_points || 0)
  const nextTier = game.tiers.find(tier => tier.threshold_points > points)
  const previousThreshold = [...game.tiers].reverse().find(tier => tier.threshold_points <= points)?.threshold_points || 0
  const levelProgress = nextTier ? Math.min(1, Math.max(0, (points - previousThreshold) / Math.max(1, nextTier.threshold_points - previousThreshold))) : 1
  const claim = async tier => {
    try { await claimBattlePass(tier); setMessage('Recompensa añadida a tu perfil.') }
    catch (claimError) { setMessage(claimError.message) }
  }

  return <div className="social-page ec-game-native">
    <header className="social-head"><div><p className="eyebrow">{game.season?.name || 'TEMPORADA ACTUAL'}</p><h1>Temporada</h1></div>{loading && <span className="live-pill">Actualizando</span>}</header>
    {error && <div className="social-error">{error}</div>}
    <section className="ec-game-hero">
      <div className="ec-game-score"><small>TUS PUNTOS</small><strong>{points.toLocaleString('es-CL')}</strong><p>{nextTier ? `${nextTier.threshold_points - points} para ${repairMojibake(nextTier.reward_name)}` : 'Completaste todos los niveles'}</p><div><span style={{ width: `${levelProgress * 100}%` }} /></div></div>
      <PulseCoach state={completedMissions === missionRows.length && missionRows.length ? 'celebrate' : 'ready'} compact />
      <p className="ec-game-coach">{completedMissions ? `Ya completaste ${completedMissions}. Sigue sumando sin romper tu ritmo.` : 'Elige una misión corta y deja que el resto del día sume.'}</p>
    </section>
    <section className="ec-game-summary" aria-label="Tu progreso de juego">
      <article><Icon name="target" /><b>{completedMissions}/{game.missions.length}</b><small>misiones hoy</small></article>
      <article><Icon name="flame" /><b>{bestCurrentStreak}</b><small>mejor racha activa</small></article>
      <article><Icon name="medal" /><b>{unlocked.size}</b><small>logros</small></article>
    </section>

    <section className="social-card ec-missions-native"><div className="section-title"><div><small>HOY</small><h2>Misiones</h2></div><span>{completedMissions}/{game.missions.length}</span></div>
      <div className="mission-list">{missionRows.length ? missionRows.map(({ mission, progress }) => {
        return <article className={`mission-card${progress.completed ? ' done' : ''}`} key={mission.id}>
          <div className="mission-head"><div><small>{missionType[mission.mission_type] || mission.mission_type}</small><b>{mission.name}</b></div><strong>+{mission.reward_points} pts</strong></div>
          <p>{repairMojibake(mission.description)}</p><div className="mission-bar"><span style={{ width: `${progress.ratio * 100}%` }} /></div><small>{progress.completed ? 'Completada' : `${progress.current.toLocaleString('es-CL')} / ${progress.target.toLocaleString('es-CL')}`}</small>
        </article>
      }) : <div className="empty-state">No hay misiones activas para hoy.</div>}</div>
    </section>

    <section className="social-card ec-battle-pass"><div className="section-title"><div><small>RUTA DE RECOMPENSAS</small><h2>Pase de temporada</h2></div><span>{claimed.size} obtenidas</span></div><div className="ec-tier-path">{game.tiers.map(tier => {
      const canClaim = points >= tier.threshold_points
      const isClaimed = claimed.has(tier.tier)
      return <article className={`${canClaim ? 'unlocked' : ''}${isClaimed ? ' claimed' : ''}`} key={tier.tier}>
        <div className="ec-tier-node"><span>{tier.tier}</span><Icon name={isClaimed ? 'checkCircle' : achievementIcon(tier.reward_icon)} /></div>
        <b>{repairMojibake(tier.reward_name)}</b><small>{tier.threshold_points} pts</small>
        <button disabled={!canClaim || isClaimed} onClick={() => claim(tier.tier)}>{isClaimed ? 'Lista' : canClaim ? 'Reclamar' : 'Bloqueada'}</button>
      </article>
    })}</div></section>

    <section className="social-card"><div className="section-title"><h2>Tabla de temporada</h2></div>{rows.map((row, index) => <div className="rank-row" key={row.user_id || row.id}>
      <span className={`rank-pos p${index + 1}`}>{row.position || index + 1}</span><span className="avatar">{row.display_name?.[0]}</span><div className="grow"><b>{row.display_name}</b><small>{index === 0 ? 'Defendiendo el primer lugar' : `${Math.max(0, (rows[0]?.total_points || 0) - (row.total_points || 0))} pts del líder`}</small></div><strong>{row.total_points || 0} pts</strong>
    </div>)}</section>

    <section className="social-card"><div className="section-title"><div><h2>Rachas verificadas</h2><p className="ec-section-note">Se actualizan al cierre del día con datos sincronizados.</p></div></div><div className="streak-grid">{game.streaks.length ? game.streaks.map((streak, index) => <article key={`${streak.user_id}-${streak.streak_type}-${index}`}>
      <span className="ec-streak-icon"><Icon name="flame" /></span><div><b>{repairMojibake(streak.profiles?.display_name || profiles.find(item => item.id === streak.user_id)?.display_name || 'Integrante')}</b><small>{streakName(streak.streak_type)} · mejor {streak.longest_count || streak.current_count || 0}</small></div><strong>{streak.current_count} <small>días</small></strong>
    </article>) : <div className="empty-state">La primera racha aparecerá al cerrar un día con una meta válida.</div>}</div></section>

    <section className="social-card"><h2>Logros</h2><div className="achievement-grid">{game.achievements.filter(item => !item.hidden || unlocked.has(item.id)).map(item => {
      const isUnlocked = unlocked.has(item.id)
      const context = unlockedContext.get(item.id)
      return <article className={isUnlocked ? 'unlocked' : ''} key={item.id}>
        <span><Icon name={isUnlocked ? achievementIcon(item.icon) : 'lock'} /></span>
        <b>{isUnlocked ? repairMojibake(item.name) : item.hidden ? 'Logro oculto' : repairMojibake(item.name)}</b>
        <small>{isUnlocked ? repairMojibake(item.description) : item.hidden ? 'Se revela al cumplir su objetivo.' : repairMojibake(item.description)}</small>
        {!!item.season_points && <em className="achievement-points">+{item.season_points} pts</em>}
        {isUnlocked && context?.value != null && <i className="achievement-check">Obtenido</i>}
      </article>
    })}</div></section>
    {message && <div className="toast-inline">{message}</div>}
  </div>
}
