import { useState } from 'react'
import { useSocial } from '../store/useSocial.js'

export default function SocialLogin() {
  const signIn = useSocial(s => s.signIn)
  const google = useSocial(s => s.signInWithGoogle)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const submit = async e => {
    e.preventDefault(); setBusy(true); setError('')
    try { await signIn(email, password) } catch (err) { setError(err.message) } finally { setBusy(false) }
  }
  return <main className="login-page">
    <section className="login-card">
      <div className="brand-mark"><img src="icon-pulse-192.png" alt="" /></div>
      <p className="eyebrow">COMPETENCIA PRIVADA</p>
      <h1>EnfermiCambio</h1>
      <p className="muted">Actividad, nutrición y entrenamiento. Tu grupo, tu ranking.</p>
      <button className="social-primary" onClick={() => google().catch(e => setError(e.message))}>Continuar con Google</button>
      <div className="login-divider"><span>o con correo</span></div>
      <form onSubmit={submit} className="social-form">
        <label>Correo<input type="email" autoComplete="email" value={email} onChange={e => setEmail(e.target.value)} required /></label>
        <label>Contraseña<input type="password" autoComplete="current-password" value={password} onChange={e => setPassword(e.target.value)} required /></label>
        {error && <div className="social-error">{error}</div>}
        <button className="social-primary" disabled={busy}>{busy ? 'Entrando…' : 'Entrar'}</button>
      </form>
      <p className="tiny muted">No existe registro público. Solo acceden las cuentas autorizadas.</p>
      <a className="install-login-link" href="#/install">Instalar EnfermiCambio en este dispositivo</a>
    </section>
  </main>
}
