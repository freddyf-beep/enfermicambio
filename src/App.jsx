import { useEffect } from 'react'
import { HashRouter, Navigate, Route, Routes, useLocation } from 'react-router-dom'
import { useStore } from './store/useStore.js'
import { useSocial } from './store/useSocial.js'
import { useUI } from './store/useUI.js'
import { bindUI } from './components/ui.jsx'
import { setLang } from './lib/i18n.js'
import { initBackButton } from './lib/back.js'
import { useWakeLock } from './lib/wakelock.js'
import ErrorBoundary from './components/ErrorBoundary.jsx'
import TabBar from './components/TabBar.jsx'
import Modals from './components/Modals.jsx'
import Toast from './components/Toast.jsx'
import RestTimer from './components/RestTimer.jsx'
import SocialLogin from './views/SocialLogin.jsx'
import Today from './views/Today.jsx'
import SocialRanking from './views/SocialRanking.jsx'
import Register from './views/Register.jsx'
import SocialGame from './views/SocialGame.jsx'
import SocialProfiles from './views/SocialProfiles.jsx'
import TrainingHub from './views/TrainingHub.jsx'
import HealthImport from './views/HealthImport.jsx'
import Licenses from './views/Licenses.jsx'
import Plan from './views/Plan.jsx'
import RoutineEdit from './views/RoutineEdit.jsx'
import Workout from './views/Workout.jsx'
import Stats from './views/Stats.jsx'
import History from './views/History.jsx'
import Library from './views/Library.jsx'
import Settings from './views/Settings.jsx'

bindUI(useUI)

function applyTheme(theme = 'dark', accent = 'lime') {
  document.documentElement.dataset.theme = theme === 'light' ? 'light' : 'dark'
  document.documentElement.dataset.accent = accent
  document.documentElement.lang = 'es'
}

function Shell() {
  const loc = useLocation()
  const S = useStore(s => s.S)
  const socialReady = useSocial(s => s.ready)
  const session = useSocial(s => s.session)
  const profile = useSocial(s => s.profile)
  const demo = useSocial(s => s.demo)
  const setTrainingUser = useStore(s => s.setUser)
  const pullTraining = useStore(s => s.pullState)
  useEffect(() => { applyTheme(S.theme, S.accent); setLang('es') }, [S.theme, S.accent])
  useEffect(() => { window.scrollTo(0, 0) }, [loc.pathname])
  useEffect(() => {
    if (session?.user) {
      setTrainingUser({ id: session.user.id, name: profile?.display_name || 'Atleta' })
      pullTraining()
    } else if (!demo) setTrainingUser(null)
  }, [session?.user?.id, profile?.display_name, demo, setTrainingUser, pullTraining])
  useWakeLock(Boolean(S.active && S.keepAwake !== false))

  if (!socialReady) return <div className="app-loader"><span>EC</span><p>Preparando el club…</p></div>
  if (!session && !demo) return <SocialLogin />

  return <>
    <div id="app" className="vfade" key={loc.pathname}>
      <ErrorBoundary><Routes>
        <Route path="/today" element={<Today />} />
        <Route path="/ranking" element={<SocialRanking />} />
        <Route path="/register" element={<Register />} />
        <Route path="/game" element={<SocialGame />} />
        <Route path="/profiles" element={<SocialProfiles />} />
        <Route path="/train" element={<TrainingHub />} />
        <Route path="/health-import" element={<HealthImport />} />
        <Route path="/licenses" element={<Licenses />} />
        <Route path="/plan" element={<Plan />} />
        <Route path="/plan/r/:id" element={<RoutineEdit />} />
        <Route path="/workout" element={<Workout />} />
        <Route path="/stats" element={<Stats />} />
        <Route path="/history" element={<History />} />
        <Route path="/library" element={<Library />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="*" element={<Navigate to="/today" replace />} />
      </Routes></ErrorBoundary>
    </div>
    <TabBar />
    <RestTimer /><Modals /><Toast />
  </>
}

export default function App() {
  const bootTraining = useStore(s => s.boot)
  const bootSocial = useSocial(s => s.boot)
  useEffect(() => { bootTraining() }, [bootTraining])
  useEffect(() => { let stop; bootSocial().then(fn => { stop = fn }); return () => stop?.() }, [bootSocial])
  useEffect(() => { let stop; initBackButton().then(fn => { stop = fn }); return () => stop?.() }, [])
  return <HashRouter><Shell /></HashRouter>
}
