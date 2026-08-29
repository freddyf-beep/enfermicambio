import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase.js'
import {
  buildIosHealthConfiguration,
  buildShortcutRunUrl,
  IOS_HEALTH_SHORTCUT_NAME,
  normalizeSharedShortcutUrl,
} from '../lib/iosShortcut.js'
import Icon from '../components/Icon.jsx'

const HEALTH_CONNECT = 'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata'
const HEALTH_CONNECT_WEBHOOK = 'https://play.google.com/store/apps/details?id=com.hcwebhook.app'
const IOS_SHORTCUT_URL = normalizeSharedShortcutUrl(import.meta.env.VITE_IOS_HEALTH_SHORTCUT_URL)
const IOS_SHORTCUT_RUN_URL = buildShortcutRunUrl()
const dateTime = value => value ? new Intl.DateTimeFormat('es-CL', { dateStyle: 'short', timeStyle: 'short' }).format(new Date(value)) : 'todavía no'

async function copyText(value) {
  if (navigator.clipboard?.writeText) return navigator.clipboard.writeText(value)
  const input = document.createElement('textarea')
  input.value = value
  input.setAttribute('readonly', '')
  input.style.cssText = 'position:fixed;opacity:0;pointer-events:none'
  document.body.appendChild(input)
  input.select()
  const copied = document.execCommand('copy')
  input.remove()
  if (!copied) throw new Error('Mantén presionada la configuración para copiarla manualmente.')
}

export default function HealthImport() {
  const [platform, setPlatform] = useState('ios')
  const [status, setStatus] = useState(null)
  const [generic, setGeneric] = useState(null)
  const [busy, setBusy] = useState('')
  const [error, setError] = useState('')
  const [copied, setCopied] = useState('')
  const genericEndpoint = import.meta.env.VITE_SUPABASE_URL ? `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/ingest_health` : 'https://TU-PROYECTO.supabase.co/functions/v1/ingest_health'

  const refresh = async () => {
    if (!supabase) return
    setBusy('status'); setError('')
    try {
      const source = platform === 'ios' ? 'ios_shortcut' : 'android_health_connect'
      const { data, error: rpcError } = await supabase.rpc('get_platform_health_ingest_status', { p_source: source })
      if (rpcError) throw rpcError
      setStatus(data || null)
    }
    catch (reason) { setError(reason.message || 'No se pudo comprobar el puente.') }
    finally { setBusy('') }
  }
  useEffect(() => {
    refresh()
    const refreshWhenVisible = () => { if (document.visibilityState !== 'hidden') refresh() }
    window.addEventListener('focus', refreshWhenVisible)
    document.addEventListener('visibilitychange', refreshWhenVisible)
    return () => {
      window.removeEventListener('focus', refreshWhenVisible)
      document.removeEventListener('visibilitychange', refreshWhenVisible)
    }
  }, [platform])

  const prepareGeneric = async () => {
    if (!supabase) return
    setBusy('generic'); setError('')
    try {
      const { data, error: rpcError } = await supabase.rpc('rotate_platform_health_ingest_token', { p_source: 'android_health_connect' })
      if (rpcError) throw rpcError
      setGeneric({ ...data, platform: 'android' })
    } catch (reason) { setError(reason.message || 'No se pudo generar el token.') }
    finally { setBusy('') }
  }
  const prepareIosShortcut = async () => {
    if (!supabase) return
    setBusy('shortcut'); setError('')
    try {
      const { data, error: rpcError } = await supabase.rpc('rotate_platform_health_ingest_token', { p_source: 'ios_shortcut' })
      if (rpcError) throw rpcError
      const configuration = buildIosHealthConfiguration(genericEndpoint, data.token)
      await copyText(configuration)
      setGeneric({ ...data, configuration, platform: 'ios' })
      setCopied('shortcut')
      if (IOS_SHORTCUT_URL) window.location.assign(IOS_SHORTCUT_URL)
    } catch (reason) { setError(reason.message || 'No se pudo preparar el Atajo.') }
    finally { setBusy('') }
  }
  const copy = async (value, label) => {
    try {
      await copyText(value); setCopied(label)
      window.setTimeout(() => setCopied(''), 1800)
    } catch (reason) { setError(reason.message || 'No se pudo copiar.') }
  }
  const runIosShortcut = async () => {
    if (!generic?.configuration) return
    setBusy('shortcut-run'); setError('')
    try {
      await copyText(generic.configuration)
      setCopied('shortcut')
      window.location.assign(IOS_SHORTCUT_RUN_URL)
    } catch (reason) { setError(reason.message || 'No se pudo abrir el Atajo instalado.') }
    finally { setBusy('') }
  }

  const connected = status?.last_run_status === 'success'
  return <main className="ec-page ec-health">
    <header className="ec-topbar"><div><p className="ec-kicker">DATOS PRIVADOS</p><h1>Salud del teléfono</h1><p className="ec-subtitle">Conecta una vez; después la sincronización es automática.</p></div><button className="ec-icon-button" onClick={() => history.back()} aria-label="Cerrar"><Icon name="xmark" /></button></header>
    <section className={`ec-health-status ${connected ? 'ok' : ''}`}><span><Icon name={connected ? 'checkCircle' : 'activity'} /></span><div><small>{connected ? 'CONECTADO' : status?.configured ? 'CONFIGURADO' : 'AÚN SIN DATOS'}</small><h2>{connected ? 'Recepción confirmada' : 'Tu puente de salud'}</h2><p>{connected ? `Última recepción ${dateTime(status.last_run_received_at)} · ${status.last_run_metric_samples || 0} métricas · ${status.last_run_workouts || 0} entrenamientos.` : 'Los datos pertenecen a tu cuenta y cada enlace o token es privado.'}</p></div><button onClick={refresh} disabled={!supabase || busy === 'status'} aria-label="Actualizar estado"><Icon name="refresh" /></button></section>
    <div className="ec-platform-tabs" role="tablist" aria-label="Elige tu teléfono"><button role="tab" aria-selected={platform === 'ios'} className={platform === 'ios' ? 'on' : ''} onClick={() => { setPlatform('ios'); setGeneric(null) }}>iPhone</button><button role="tab" aria-selected={platform === 'android'} className={platform === 'android' ? 'on' : ''} onClick={() => { setPlatform('android'); setGeneric(null) }}>Android</button></div>
    {!supabase && <div className="ec-install-hint"><Icon name="info" /><span>Esta es la demostración. Con una cuenta activa, aquí se crean enlaces y tokens privados.</span></div>}

    {platform === 'ios' ? <section className="ec-health-flow">
      <div className="ec-store-card"><span className="ios"><Icon name="heart" /></span><div><b>1. Usa Atajos, incluido en iPhone</b><p>Atajos puede leer los datos de Apple Salud que tú elijas y enviarlos por internet.</p><small>Esta opción es gratuita y no vence después de una prueba.</small></div><a href="shortcuts://" rel="noreferrer">Abrir Atajos</a></div>
      <article className="ec-health-step"><span>2</span><div><b>Instala el Atajo configurado</b><p>Generamos el token, copiamos la configuración y abrimos la plantilla. En iPhone solo tendrás que aceptar y ejecutarla una vez.</p><button className="ec-primary" onClick={prepareIosShortcut} disabled={!supabase || Boolean(busy)}>{busy === 'shortcut' ? 'Preparando Atajo…' : 'Generar token e instalar Atajo'}</button>{!IOS_SHORTCUT_URL && <small>La conexión quedará copiada; falta vincular la plantilla compartida de Apple para abrirla automáticamente.</small>}</div></article>
      {generic?.platform === 'ios' && generic?.configuration && <article className="ec-health-result"><Icon name="shield" /><div><b>{copied === 'shortcut' ? 'Configuración lista en el portapapeles' : 'Conexión privada preparada'}</b><p>La plantilla usa esta configuración al ejecutarse por primera vez y guarda el token dentro del Atajo.</p><button onClick={() => copy(generic.configuration, 'shortcut')}>{copied === 'shortcut' ? 'Configuración copiada' : 'Copiar configuración completa'}</button><label>Token</label><code>{generic.token}</code><button onClick={() => copy(generic.token, 'token')}>{copied === 'token' ? 'Copiado' : 'Copiar token'}</button><label>Endpoint</label><code>{genericEndpoint}</code><button onClick={() => copy(genericEndpoint, 'endpoint')}>{copied === 'endpoint' ? 'Copiado' : 'Copiar endpoint'}</button><div>{IOS_SHORTCUT_URL ? <a className="ec-secondary" href={IOS_SHORTCUT_URL}>Instalar plantilla otra vez</a> : <a className="ec-secondary" href="shortcuts://create-shortcut">Abrir editor de Atajos</a>}<button className="ec-primary" onClick={runIosShortcut} disabled={busy === 'shortcut-run'}>{busy === 'shortcut-run' ? 'Abriendo…' : 'Configurar y probar Atajo'}</button></div><small>Primero instala la plantilla. Después, “Configurar y probar” vuelve a copiar la conexión y ejecuta {IOS_HEALTH_SHORTCUT_NAME}. El token de Android permanece independiente.</small></div></article>}
      <details className="ec-health-advanced"><summary>Pasos del atajo gratuito</summary><ol><li>Busca muestras de Salud de hoy: pasos, distancia y energía activa.</li><li>Suma cada tipo de muestra.</li><li>Crea un diccionario con <code>activity_date</code>, <code>source_platform: ios</code>, <code>daily_steps</code>, <code>distance_meters</code> y <code>active_calories</code>.</li><li>Envíalo como JSON con “Obtener contenido de URL”.</li></ol></details>
    </section> : <section className="ec-health-flow">
      <div className="ec-store-card"><span className="android"><Icon name="heart" /></span><div><b>1. Activa Health Connect</b><p>En Android 14 está en Ajustes; en versiones anteriores se instala.</p></div><a href={HEALTH_CONNECT} target="_blank" rel="noreferrer">Abrir</a></div>
      <div className="ec-store-card"><span className="android"><Icon name="refresh" /></span><div><b>2. Instala el puente</b><p>Health Connect Webhook envía solo los datos que autorizas.</p><small>Es una app de pago único; el precio depende de la tienda.</small></div><a href={HEALTH_CONNECT_WEBHOOK} target="_blank" rel="noreferrer">Google Play</a></div>
      <article className="ec-health-step"><span>3</span><div><b>Genera la conexión privada</b><p>El token anterior se revoca cuando creas uno nuevo.</p><button className="ec-primary" onClick={prepareGeneric} disabled={!supabase || Boolean(busy)}>{busy === 'generic' ? 'Generando…' : 'Generar endpoint y token'}</button></div></article>
      {generic?.platform === 'android' && generic?.token && <article className="ec-health-result"><Icon name="shield" /><div><b>Cópialo ahora</b><p>Por seguridad el token completo no volverá a mostrarse. El token del Atajo de iPhone permanece activo.</p><label>Token</label><code>{generic.token}</code><button onClick={() => copy(generic.token, 'token')}>{copied === 'token' ? 'Copiado' : 'Copiar token'}</button><label>Endpoint</label><code>{genericEndpoint}</code><button onClick={() => copy(genericEndpoint, 'endpoint')}>{copied === 'endpoint' ? 'Copiado' : 'Copiar endpoint'}</button></div></article>}
      <details className="ec-health-advanced"><summary>Configuración avanzada del webhook</summary><pre>{`{
  "activity_date": "2026-08-27",
  "source_platform": "android",
  "daily_steps": 8420,
  "active_calories": 510,
  "distance_meters": 6120,
  "exercise_minutes": 44,
  "workouts": []
}`}</pre><p>Usa <code>Authorization: Bearer TOKEN</code>. Reenviar el mismo día reemplaza el total y no duplica pasos.</p></details>
    </section>}
    {error && <div className="social-error" role="alert">{error}</div>}
  </main>
}
