import { useState } from 'react'
import { supabase } from '../lib/supabase.js'

export default function HealthImport() {
  const [token, setToken] = useState('')
  const [error, setError] = useState('')
  const generate = async () => {
    if (!supabase) { setError('Configura Supabase para generar un token real.'); return }
    const { data, error } = await supabase.rpc('rotate_health_ingest_token')
    if (error) setError(error.message); else setToken(data)
  }
  const endpoint = import.meta.env.VITE_SUPABASE_URL ? `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/ingest_health` : 'https://TU-PROYECTO.supabase.co/functions/v1/ingest_health'
  return <div className="social-page"><header className="social-head"><div><p className="eyebrow">SIN APP NATIVA</p><h1>Importación de salud</h1></div></header>
    <section className="social-card prose"><h2>Conecta una app exportadora</h2><p>La aplicación de terceros debe enviar un POST JSON al endpoint. Cada persona tiene un token distinto y puede revocarlo cuando quiera.</p><code>{endpoint}</code><button className="social-primary" onClick={generate}>Generar o rotar token</button>{token && <div className="secret-box"><b>Cópialo ahora; no volverá a mostrarse.</b><code>{token}</code></div>}{error && <div className="social-error">{error}</div>}</section>
    <section className="social-card prose"><h2>Formato esperado</h2><pre>{`{
  "activity_date": "2026-08-27",
  "source_platform": "ios",
  "source_app": "Health Auto Export",
  "daily_steps": 8420,
  "active_calories": 510,
  "distance_meters": 6120,
  "exercise_minutes": 44,
  "workouts": []
}`}</pre><p>Envía el token como <code>Authorization: Bearer TOKEN</code>. Los reenvíos del mismo día reemplazan el total anterior y no duplican pasos.</p></section>
  </div>
}
