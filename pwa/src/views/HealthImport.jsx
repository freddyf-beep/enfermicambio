import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase.js'
import { validateHealthBridgeToken } from '../lib/healthBridge.js'
import Icon from '../components/Icon.jsx'

const HEALTH_CONNECT = 'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata'
const CONDUIT_APP_STORE = 'https://apps.apple.com/cl/app/conduit-health-sync/id6786544769'
const CONDUIT_SOURCE = 'https://github.com/noebrito/conduit'
const LIFE_DASHBOARD_RELEASE = 'https://github.com/owen282000/life-dashboard-companion-app/releases/tag/1.8.0'
const LIFE_DASHBOARD_APK = 'https://github.com/owen282000/life-dashboard-companion-app/releases/download/1.8.0/app-release.apk'
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
  if (!copied) throw new Error('Mantén presionado el valor para copiarlo manualmente.')
}

export default function HealthImport() {
  const [platform, setPlatform] = useState('ios')
  const [status, setStatus] = useState(null)
  const [connection, setConnection] = useState(null)
  const [busy, setBusy] = useState('')
  const [error, setError] = useState('')
  const [copied, setCopied] = useState('')
  const endpoint = import.meta.env.VITE_SUPABASE_URL
    ? `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/ingest_health`
    : 'https://TU-PROYECTO.supabase.co/functions/v1/ingest_health'

  const refresh = async () => {
    if (!supabase) return
    setBusy('status'); setError('')
    try {
      const source = platform === 'ios' ? 'ios_shortcut' : 'android_health_connect'
      const { data, error: rpcError } = await supabase.rpc('get_platform_health_ingest_status', { p_source: source })
      if (rpcError) throw rpcError
      setStatus(data || null)
    } catch (reason) { setError(reason.message || 'No se pudo comprobar el puente.') }
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

  const prepare = async selectedPlatform => {
    if (!supabase) return
    setBusy('token'); setError(''); setConnection(null)
    try {
      const source = selectedPlatform === 'ios' ? 'ios_shortcut' : 'android_health_connect'
      const { data, error: rpcError } = await supabase.rpc('rotate_platform_health_ingest_token', { p_source: source })
      if (rpcError) throw rpcError
      setConnection({ ...data, platform: selectedPlatform, verified: false })
      await validateHealthBridgeToken(endpoint, data.token, selectedPlatform)
      setConnection({ ...data, platform: selectedPlatform, verified: true })
    } catch (reason) {
      setError(reason.message || 'El token se generó, pero el servidor no logró validarlo.')
    } finally { setBusy('') }
  }

  const copy = async (value, label) => {
    try {
      await copyText(value); setCopied(label)
      window.setTimeout(() => setCopied(''), 1800)
    } catch (reason) { setError(reason.message || 'No se pudo copiar.') }
  }

  const choosePlatform = next => {
    setPlatform(next)
    setConnection(null)
    setError('')
  }
  const connected = status?.last_run_status === 'success'
  const bearerValue = connection?.token ? `Bearer ${connection.token}` : ''

  return <main className="ec-page ec-health">
    <header className="ec-topbar"><div><p className="ec-kicker">UNA CONEXIÓN · DOS TELÉFONOS</p><h1>Salud del teléfono</h1><p className="ec-subtitle">La misma pantalla configura una app gratuita distinta para iPhone y Android.</p></div><button className="ec-icon-button" onClick={() => history.back()} aria-label="Cerrar"><Icon name="xmark" /></button></header>
    <section className={`ec-health-status ${connected ? 'ok' : ''}`}><span><Icon name={connected ? 'checkCircle' : 'activity'} /></span><div><small>{connected ? 'DATOS RECIBIDOS' : status?.configured ? 'TOKEN CONFIGURADO' : 'AÚN SIN DATOS'}</small><h2>{connected ? 'Sincronización confirmada' : 'Tu puente privado'}</h2><p>{connected ? `Última recepción ${dateTime(status.last_run_received_at)} · ${status.last_run_metric_samples || 0} métricas · ${status.last_run_workouts || 0} entrenamientos.` : 'Cada teléfono usa su propio token. Crear uno no desconecta el otro.'}</p></div><button onClick={refresh} disabled={!supabase || busy === 'status'} aria-label="Actualizar estado"><Icon name="refresh" /></button></section>
    <div className="ec-platform-tabs" role="tablist" aria-label="Elige tu teléfono"><button role="tab" aria-selected={platform === 'ios'} className={platform === 'ios' ? 'on' : ''} onClick={() => choosePlatform('ios')}>iPhone</button><button role="tab" aria-selected={platform === 'android'} className={platform === 'android' ? 'on' : ''} onClick={() => choosePlatform('android')}>Android</button></div>
    {!supabase && <div className="ec-install-hint"><Icon name="info" /><span>Esta es la demostración. Inicia sesión para crear y verificar un token privado.</span></div>}

    {platform === 'ios' ? <section className="ec-health-flow">
      <div className="ec-store-card"><span className="ios"><Icon name="heart" /></span><div><b>1. Instala Conduit Health Sync</b><p>Lee Apple Salud y envía directamente a EnfermiCambio por HTTPS.</p><small>Gratis en App Store Chile · sin prueba, suscripción ni compras internas · código fuente Apache-2.0.</small></div><a href={CONDUIT_APP_STORE} target="_blank" rel="noreferrer">App Store</a></div>
      <article className="ec-health-step"><span>2</span><div><b>Genera y comprueba la conexión</b><p>EnfermiCambio crea un token exclusivo para iPhone y lo prueba contra el receptor antes de mostrártelo.</p><button className="ec-primary" onClick={() => prepare('ios')} disabled={!supabase || Boolean(busy)}>{busy === 'token' ? 'Comprobando token…' : 'Generar y verificar token'}</button></div></article>
      {connection?.platform === 'ios' && <article className="ec-health-result"><Icon name={connection.verified ? 'checkCircle' : 'shield'} /><div><b>{connection.verified ? 'Token verificado por el servidor' : 'Token creado; falta verificarlo'}</b><p>{connection.verified ? 'En Conduit abre Settings. Pega la URL en Webhook URL y el token sin la palabra Bearer en Bearer Token.' : 'Conserva este token. EnfermiCambio no lo marcará como listo hasta que el receptor responda correctamente.'}</p><label>Webhook URL</label><code>{endpoint}</code><button onClick={() => copy(endpoint, 'endpoint')}>{copied === 'endpoint' ? 'Copiado' : 'Copiar URL'}</button><label>Bearer Token</label><code>{connection.token}</code><button onClick={() => copy(connection.token, 'token')}>{copied === 'token' ? 'Copiado' : 'Copiar token'}</button><small>Activa Steps, Walking + Running Distance, Active Energy, Exercise Time y Workouts. Luego toca Test Connection: debe mostrar HTTP 200.</small><small>Importante: si vuelves a generar un token, el anterior de iPhone deja de funcionar. Genera uno y úsalo en Conduit.</small></div></article>}
      <details className="ec-health-advanced"><summary>Por qué esta app sí cumple</summary><p>Conduit está publicada a precio 0, no contiene StoreKit ni sistema de pagos y su repositorio público corresponde a la app enviada a App Store. Usa una cola local, reintentos y UUID de HealthKit para que un reenvío no duplique pasos.</p><a href={CONDUIT_SOURCE} target="_blank" rel="noreferrer">Revisar código fuente</a></details>
    </section> : <section className="ec-health-flow">
      <div className="ec-store-card"><span className="android"><Icon name="heart" /></span><div><b>1. Activa Health Connect</b><p>En Android 14 está en Ajustes; en Android 9–13 se instala desde Google Play.</p></div><a href={HEALTH_CONNECT} target="_blank" rel="noreferrer">Abrir</a></div>
      <div className="ec-store-card"><span className="android"><Icon name="download" /></span><div><b>2. Instala Life Dashboard Companion 1.8.0</b><p>El APK oficial envía Health Connect al webhook privado, con reintentos y sincronización en segundo plano.</p><small>100% gratuito · MIT · sin cuenta, nube, analítica ni versión de prueba.</small></div><a href={LIFE_DASHBOARD_APK} target="_blank" rel="noreferrer">Descargar APK</a></div>
      <article className="ec-health-step"><span>3</span><div><b>Genera y comprueba la conexión</b><p>El token anterior de Android se revoca al crear uno nuevo. El de iPhone no cambia.</p><button className="ec-primary" onClick={() => prepare('android')} disabled={!supabase || Boolean(busy)}>{busy === 'token' ? 'Comprobando token…' : 'Generar y verificar token'}</button></div></article>
      {connection?.platform === 'android' && <article className="ec-health-result"><Icon name={connection.verified ? 'checkCircle' : 'shield'} /><div><b>{connection.verified ? 'Token verificado por el servidor' : 'Token creado; falta verificarlo'}</b><p>{connection.verified ? 'En Life Dashboard abre Health → Webhook. Pega la URL y agrega el encabezado personalizado completo.' : 'Conserva este token. EnfermiCambio no lo marcará como listo hasta que el receptor responda correctamente.'}</p><label>Webhook URL</label><code>{endpoint}</code><button onClick={() => copy(endpoint, 'endpoint')}>{copied === 'endpoint' ? 'Copiado' : 'Copiar URL'}</button><label>Header name</label><code>Authorization</code><button onClick={() => copy('Authorization', 'header')}>{copied === 'header' ? 'Copiado' : 'Copiar nombre'}</button><label>Header value</label><code>{bearerValue}</code><button onClick={() => copy(bearerValue, 'bearer')}>{copied === 'bearer' ? 'Copiado' : 'Copiar valor'}</button><small>Activa Steps, Distance, Active Calories, Exercise y especialmente Daily totals. Después usa Preview Data y Sync Now.</small><small>Importante: si vuelves a generar un token, el anterior de Android deja de funcionar. Genera uno y úsalo en Life Dashboard.</small></div></article>}
      <details className="ec-health-advanced"><summary>Instalación segura y funcionamiento</summary><p>El APK viene del release oficial de GitHub y Android pedirá autorizar esa instalación. Versión fijada: 1.8.0. SHA-256: <code>35a61fa2eec07f13743d8c36e1e08382192eb8e5d1c7d87890a0ba44aa8d0eab</code>.</p><p>Si el fabricante detiene la sincronización, configura Batería → Sin restricciones para Life Dashboard. Android puede retrasar el intervalo mínimo de 15 minutos.</p><a href={LIFE_DASHBOARD_RELEASE} target="_blank" rel="noreferrer">Ver release y código</a></details>
    </section>}
    {error && <div className="social-error" role="alert">{error}</div>}
  </main>
}
