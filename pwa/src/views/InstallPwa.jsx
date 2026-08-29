import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import Icon from '../components/Icon.jsx'
import { installAvailable, installPlatform, isInstalled, requestInstall, subscribeInstall } from '../lib/pwa-install.js'
import { useStore } from '../store/useStore.js'
import { INSTALL_ICONS } from '../lib/install-icon.js'

const HEALTH_CONNECT = 'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata'
const CONDUIT_APP_STORE = 'https://apps.apple.com/cl/app/conduit-health-sync/id6786544769'
const LIFE_DASHBOARD_APK = 'https://github.com/owen282000/life-dashboard-companion-app/releases/download/1.8.0/app-release.apk'

const steps = {
  ios: [
    ['share', 'Abre Compartir', 'En Safari, toca el cuadrado con la flecha hacia arriba.'],
    ['plus', 'Agregar a inicio', 'Desliza y elige “Agregar a pantalla de inicio”.'],
    ['checkCircle', 'Confirma EnfermiCambio', 'Toca Agregar. El icono aparecerá como una app normal.'],
  ],
  android: [
    ['download', 'Instala la PWA', 'Toca el botón de instalación; Chrome crea una app verificada por el navegador.'],
    ['checkCircle', 'Confirma', 'Acepta el diálogo del sistema. No necesitas habilitar orígenes desconocidos.'],
    ['house', 'Ábrela desde inicio', 'Las siguientes mejoras llegarán automáticamente.'],
  ],
}

export default function InstallPwa({ publicView = false }) {
  const nav = useNavigate()
  const installIcon = useStore(state => state.S.installIcon || 'pulse')
  const update = useStore(state => state.update)
  const [, refresh] = useState(0)
  const detected = installPlatform()
  const [selected, setSelected] = useState(detected === 'android' ? 'android' : 'ios')
  const [message, setMessage] = useState('')
  useEffect(() => subscribeInstall(() => refresh(value => value + 1)), [])
  const installed = isInstalled()
  const available = installAvailable()

  const install = async () => {
    if (!available) {
      setMessage('Chrome todavía no ofreció la instalación automática. Usa el menú ⋮ → Instalar aplicación; si ya está instalada, ábrela desde la pantalla de inicio.')
      return
    }
    const accepted = await requestInstall()
    setMessage(accepted ? 'Instalación iniciada. Busca EnfermiCambio en tu pantalla de inicio.' : 'El diálogo se cerró. Puedes intentarlo de nuevo cuando quieras.')
  }

  return <main className={publicView ? 'ec-install public' : 'ec-page ec-install'}>
    <header className="ec-topbar"><div><p className="ec-kicker">Configuración guiada</p><h1>Instala una vez</h1><p className="ec-subtitle">Sin APK, IPA ni actualizaciones manuales.</p></div>{!publicView && <button className="ec-icon-button" onClick={() => nav(-1)} aria-label="Cerrar"><Icon name="xmark" /></button>}</header>
    <section className={`ec-install-status ${installed ? 'done' : ''}`}><span><Icon name={installed ? 'checkCircle' : 'download'} /></span><div><p className="ec-kicker">EnfermiCambio</p><h2>{installed ? 'Ya está instalada' : 'Lista para tu pantalla de inicio'}</h2><p>{installed ? 'La estás usando como aplicación. Las mejoras se actualizan al volver a abrirla.' : 'Funciona a pantalla completa, conserva tu sesión y no necesita archivos externos.'}</p></div></section>

    {!installed && <>
      <section className="ec-install-icon-picker"><div><b>Elige tu icono</b><p>La pantalla de inicio usará la variante seleccionada.</p></div><div className="ec-icon-options" aria-label="Icono que se instalará">{INSTALL_ICONS.map(icon => <button key={icon.id} className={installIcon === icon.id ? 'on' : ''} aria-label={icon.label} aria-pressed={installIcon === icon.id} onClick={() => update(state => { state.installIcon = icon.id })}><img src={`icon-${icon.id}-180.png`} alt="" /></button>)}</div></section>
      <div className="ec-platform-tabs" role="tablist" aria-label="Elige tu teléfono"><button role="tab" aria-selected={selected === 'ios'} className={selected === 'ios' ? 'on' : ''} onClick={() => setSelected('ios')}>iPhone</button><button role="tab" aria-selected={selected === 'android'} className={selected === 'android' ? 'on' : ''} onClick={() => setSelected('android')}>Android</button></div>
      {selected === 'android' && <button className="ec-primary ec-install-now" onClick={install}><Icon name="download" /> Instalar EnfermiCambio ahora</button>}
      {selected === 'android' && !available && <div className="ec-install-hint"><Icon name="info" /><span>Si el botón no aparece, abre esta página en Chrome y usa el menú ⋮ → Instalar aplicación.</span></div>}
      {selected === 'ios' && detected !== 'ios' && <div className="ec-install-hint"><Icon name="info" /><span>Estas instrucciones se activan en el iPhone. Abre la URL oficial en Safari.</span></div>}
      <ol className="ec-install-steps">{steps[selected].map(([icon, title, body], index) => <li key={title}><span className="number">{index + 1}</span><span className="icon"><Icon name={icon} /></span><div><b>{title}</b><p>{body}</p></div></li>)}</ol>
    </>}

    <section className="ec-bridge">
      <div className="ec-section-head"><div><p className="ec-kicker">Después de instalar</p><h2>Conecta la salud del teléfono</h2></div></div>
      {selected === 'ios' ? <>
        <div className="ec-store-card"><span className="ios"><Icon name="activity" /></span><div><b>Conduit Health Sync</b><p>Conecta Apple Salud directamente con tu webhook privado.</p><small>Gratis, sin prueba, suscripción ni compras internas.</small></div><a href={CONDUIT_APP_STORE} target="_blank" rel="noreferrer">App Store</a></div>
        <button className="ec-secondary" onClick={() => nav('/health-import')}>Generar y verificar token de iPhone</button>
      </> : <>
        <div className="ec-store-card"><span className="android"><Icon name="heart" /></span><div><b>Health Connect</b><p>En Android 14 o superior viene en Ajustes; en versiones anteriores se instala desde Google Play.</p></div><a href={HEALTH_CONNECT} target="_blank" rel="noreferrer">Abrir</a></div>
        <div className="ec-store-card"><span className="android"><Icon name="refresh" /></span><div><b>Life Dashboard Companion 1.8.0</b><p>Envía Health Connect directamente al webhook privado de EnfermiCambio.</p><small>APK gratuito y de código abierto; sin cuenta, nube ni versión de prueba.</small></div><a href={LIFE_DASHBOARD_APK} target="_blank" rel="noreferrer">Descargar APK</a></div>
        <button className="ec-secondary" onClick={() => nav('/health-import')}>Generar y verificar token de Android</button>
      </>}
    </section>
    {message && <div className="ec-result" role="status">{message}</div>}
    {publicView && <button className="ec-text-button" onClick={() => nav('/today')}>Volver al inicio de sesión</button>}
  </main>
}
