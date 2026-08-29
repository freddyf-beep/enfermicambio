import { useEffect } from 'react'
import { useStore } from '../store/useStore.js'
import { useSocial } from '../store/useSocial.js'
import { useUI } from '../store/useUI.js'
import { setLang } from '../lib/i18n.js'
import { useWakeLock } from '../lib/wakelock.js'
import { bindUI } from './ui.jsx'
import Modals from './Modals.jsx'
import RestTimer from './RestTimer.jsx'
import Toast from './Toast.jsx'

bindUI(useUI)

export default function TrainingRuntime({ children }) {
  const S = useStore(state => state.S)
  const boot = useStore(state => state.boot)
  const setUser = useStore(state => state.setUser)
  const pullState = useStore(state => state.pullState)
  const session = useSocial(state => state.session)
  const profile = useSocial(state => state.profile)
  const demo = useSocial(state => state.demo)

  useEffect(() => { boot() }, [boot])
  useEffect(() => {
    document.documentElement.dataset.theme = S.theme === 'light' ? 'light' : 'dark'
    document.documentElement.dataset.accent = S.accent || 'lime'
    setLang('es')
  }, [S.theme, S.accent])
  useEffect(() => {
    if (session?.user) {
      setUser({ id: session.user.id, name: profile?.display_name || 'Atleta' })
      pullState()
    } else if (!demo) setUser(null)
  }, [session?.user?.id, profile?.display_name, demo, setUser, pullState])
  useWakeLock(Boolean(S.active && S.keepAwake !== false))

  return <>{children}<RestTimer /><Modals /><Toast /></>
}
