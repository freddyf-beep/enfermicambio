import { lazy, Suspense, useEffect } from 'react'
import { HashRouter, Navigate, Route, Routes, useLocation } from 'react-router-dom'
import { useSocial } from './store/useSocial.js'
import { useStore } from './store/useStore.js'
import { setLang } from './lib/i18n.js'
import { applyInstallIcon } from './lib/install-icon.js'
import { initBackButton } from './lib/back.js'
import ErrorBoundary from './components/ErrorBoundary.jsx'
import TabBar from './components/TabBar.jsx'
import SocialLogin from './views/SocialLogin.jsx'
import Today from './views/Today.jsx'
import SocialRanking from './views/SocialRanking.jsx'

const Register = lazy(() => import('./views/Register.jsx'))
const ActivityRecorder = lazy(() => import('./views/ActivityRecorder.jsx'))
const SocialGame = lazy(() => import('./views/SocialGame.jsx'))
const SocialProfiles = lazy(() => import('./views/SocialProfiles.jsx'))
const Notifications = lazy(() => import('./views/Notifications.jsx'))
const WeightLog = lazy(() => import('./views/WeightLog.jsx'))
const HealthImport = lazy(() => import('./views/HealthImport.jsx'))
const InstallPwa = lazy(() => import('./views/InstallPwa.jsx'))
const Licenses = lazy(() => import('./views/Licenses.jsx'))
const TrainingRuntime = lazy(() => import('./components/TrainingRuntime.jsx'))
const TrainingHub = lazy(() => import('./views/TrainingHub.jsx'))
const HomeMode = lazy(() => import('./views/HomeMode.jsx'))
const Plan = lazy(() => import('./views/Plan.jsx'))
const RoutineEdit = lazy(() => import('./views/RoutineEdit.jsx'))
const Workout = lazy(() => import('./views/Workout.jsx'))
const Stats = lazy(() => import('./views/Stats.jsx'))
const History = lazy(() => import('./views/History.jsx'))
const Library = lazy(() => import('./views/Library.jsx'))
const Settings = lazy(() => import('./views/Settings.jsx'))

function applyTheme(theme = 'dark', accent = 'lime') {
  document.documentElement.dataset.theme = theme === 'light' ? 'light' : 'dark'
  document.documentElement.dataset.accent = accent
  document.documentElement.lang = 'es'
}

function initialAppearance() {
  try {
    const state = JSON.parse(localStorage.getItem('gym_state_v1') || '{}')
    return { theme: state.theme, accent: state.accent }
  } catch { return {} }
}

const loading = <div className="app-loader"><span><img src="icon-pulse-192.png" alt="" /></span><p>EnfermiCambio</p></div>
const page = Component => <Suspense fallback={loading}><Component /></Suspense>
const trainingPage = Component => <Suspense fallback={loading}><TrainingRuntime><Component /></TrainingRuntime></Suspense>

function Shell() {
  const loc = useLocation()
  const installIcon = useStore(s => s.S.installIcon || 'pulse')
  const socialReady = useSocial(s => s.ready)
  const session = useSocial(s => s.session)
  const demo = useSocial(s => s.demo)
  useEffect(() => { const appearance = initialAppearance(); applyTheme(appearance.theme, appearance.accent); setLang('es') }, [])
  useEffect(() => { applyInstallIcon(installIcon) }, [installIcon])
  useEffect(() => { window.scrollTo(0, 0) }, [loc.pathname])

  if (!socialReady) return <div className="app-loader"><span><img src="icon-pulse-192.png" alt="" /></span><p>Preparando EnfermiCambio…</p></div>
  if (!session && !demo) return loc.pathname === '/install' ? page(() => <InstallPwa publicView />) : <SocialLogin />

  return <>
    <div id="app" className="vfade" key={loc.pathname}>
      <ErrorBoundary><Routes>
        <Route path="/today" element={<Today />} />
        <Route path="/ranking" element={<SocialRanking />} />
        <Route path="/register" element={page(Register)} />
        <Route path="/activity" element={page(ActivityRecorder)} />
        <Route path="/game" element={page(SocialGame)} />
        <Route path="/profiles" element={page(SocialProfiles)} />
        <Route path="/notifications" element={page(Notifications)} />
        <Route path="/weight" element={page(WeightLog)} />
        <Route path="/install" element={page(InstallPwa)} />
        <Route path="/health-import" element={page(HealthImport)} />
        <Route path="/licenses" element={page(Licenses)} />
        <Route path="/train" element={trainingPage(TrainingHub)} />
        <Route path="/home-mode" element={trainingPage(HomeMode)} />
        <Route path="/plan" element={trainingPage(Plan)} />
        <Route path="/plan/r/:id" element={trainingPage(RoutineEdit)} />
        <Route path="/workout" element={trainingPage(Workout)} />
        <Route path="/stats" element={trainingPage(Stats)} />
        <Route path="/history" element={trainingPage(History)} />
        <Route path="/library" element={trainingPage(Library)} />
        <Route path="/settings" element={trainingPage(Settings)} />
        <Route path="*" element={<Navigate to="/today" replace />} />
      </Routes></ErrorBoundary>
    </div>
    <TabBar />
  </>
}

export default function App() {
  const bootSocial = useSocial(s => s.boot)
  useEffect(() => { let stop; bootSocial().then(fn => { stop = fn }); return () => stop?.() }, [bootSocial])
  useEffect(() => { let stop; initBackButton().then(fn => { stop = fn }); return () => stop?.() }, [])
  return <HashRouter><Shell /></HashRouter>
}
