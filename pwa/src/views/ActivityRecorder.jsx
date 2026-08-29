import { useEffect, useRef, useState } from 'react'
import 'leaflet/dist/leaflet.css'
import Icon from '../components/Icon.jsx'
import { distanceBetween, formatDuration, routeDistance } from '../lib/activity-route.js'
import { useSocial } from '../store/useSocial.js'

const TYPES = [
  ['walking', 'Caminata', 'figureRun'],
  ['running', 'Carrera', 'route'],
  ['cycling', 'Bicicleta', 'bike'],
  ['hiking', 'Senderismo', 'mountain'],
]

const gpxFor = (points, type) => `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="EnfermiCambio" xmlns="http://www.topografix.com/GPX/1/1">
  <trk><name>${type}</name><trkseg>
${points.map(point => `    <trkpt lat="${point.latitude}" lon="${point.longitude}">${point.altitude == null ? '' : `<ele>${point.altitude}</ele>`}<time>${point.timestamp}</time></trkpt>`).join('\n')}
  </trkseg></trk>
</gpx>`

function RouteMap({ points }) {
  const element = useRef(null)
  const map = useRef(null)
  const leaflet = useRef(null)
  const line = useRef(null)
  const startMarker = useRef(null)
  const endMarker = useRef(null)
  const pointsRef = useRef(points)
  pointsRef.current = points

  const draw = current => {
    if (!map.current || !leaflet.current || !current.length) return
    const L = leaflet.current
    const coordinates = current.map(point => [point.latitude, point.longitude])
    line.current?.remove(); startMarker.current?.remove(); endMarker.current?.remove()
    line.current = L.polyline(coordinates, { color: '#30d158', weight: 5, opacity: .9 }).addTo(map.current)
    startMarker.current = L.circleMarker(coordinates[0], { radius: 6, color: '#fff', weight: 2, fillColor: '#30d158', fillOpacity: 1 }).addTo(map.current)
    endMarker.current = L.circleMarker(coordinates.at(-1), { radius: 7, color: '#fff', weight: 2, fillColor: '#0a84ff', fillOpacity: 1 }).addTo(map.current)
    map.current.fitBounds(line.current.getBounds(), { padding: [28, 28], maxZoom: 17 })
  }

  useEffect(() => {
    let cancelled = false
    import('leaflet').then(module => {
      if (cancelled || !element.current) return
      const L = module.default || module
      leaflet.current = L
      map.current = L.map(element.current, { zoomControl: false }).fitWorld()
      L.control.zoom({ position: 'bottomright' }).addTo(map.current)
      L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 19, attribution: '© OpenStreetMap' }).addTo(map.current)
      draw(pointsRef.current)
    })
    return () => { cancelled = true; map.current?.remove(); map.current = null }
  }, [])
  useEffect(() => { draw(points) }, [points])

  return <div className="ec-route-map-wrap"><div ref={element} className="ec-route-map" aria-label="Mapa de la ruta" />{!points.length && <div className="ec-map-empty"><Icon name="route" /><span>La ruta aparecerá aquí cuando recibamos tu ubicación.</span></div>}</div>
}

export default function ActivityRecorder() {
  const saveOutdoorActivity = useSocial(state => state.saveOutdoorActivity)
  const [type, setType] = useState('walking')
  const [status, setStatus] = useState('idle')
  const [points, setPoints] = useState([])
  const [startedAt, setStartedAt] = useState(null)
  const [endedAt, setEndedAt] = useState(null)
  const [elapsed, setElapsed] = useState(0)
  const [message, setMessage] = useState('')
  const watchId = useRef(null)

  const stopWatch = () => {
    if (watchId.current != null) navigator.geolocation.clearWatch(watchId.current)
    watchId.current = null
  }
  useEffect(() => () => stopWatch(), [])
  useEffect(() => {
    if (status !== 'recording' || !startedAt) return undefined
    const update = () => setElapsed(Math.max(0, Math.round((Date.now() - new Date(startedAt).getTime()) / 1000)))
    update(); const timer = window.setInterval(update, 1000)
    return () => window.clearInterval(timer)
  }, [status, startedAt])

  const start = () => {
    if (!navigator.geolocation) { setMessage('Este navegador no ofrece ubicación GPS.'); return }
    const now = new Date().toISOString()
    setPoints([]); setStartedAt(now); setEndedAt(null); setElapsed(0); setMessage('Solicitando ubicación…'); setStatus('recording')
    watchId.current = navigator.geolocation.watchPosition(position => {
      const point = { timestamp: new Date(position.timestamp || Date.now()).toISOString(), latitude: position.coords.latitude, longitude: position.coords.longitude, altitude: position.coords.altitude, accuracy: position.coords.accuracy, heading: position.coords.heading }
      if (Number(point.accuracy) > 100) { setMessage('Esperando una señal GPS más precisa…'); return }
      setPoints(current => {
        const previous = current.at(-1)
        if (previous && distanceBetween(previous, point) < 3) return current
        return [...current, point]
      })
      setMessage('Grabando ruta · mantén EnfermiCambio en primer plano.')
    }, error => {
      stopWatch(); setStatus('idle')
      setMessage(error.code === 1 ? 'La ubicación no fue autorizada. Puedes activarla en los permisos del navegador.' : 'No pudimos obtener una señal GPS estable.')
    }, { enableHighAccuracy: true, maximumAge: 2000, timeout: 15000 })
  }
  const stop = () => { stopWatch(); setEndedAt(new Date().toISOString()); setStatus('stopped'); setMessage('Ruta detenida. Revísala antes de guardarla.') }
  const discard = () => { stopWatch(); setStatus('idle'); setPoints([]); setStartedAt(null); setEndedAt(null); setElapsed(0); setMessage('Actividad descartada; no se envió ningún punto.') }
  const save = async () => {
    if (!startedAt || !endedAt) return
    setStatus('saving'); setMessage('Guardando la actividad privada…')
    try {
      await saveOutdoorActivity({ type, startedAt, endedAt, durationSeconds: Math.max(1, (new Date(endedAt) - new Date(startedAt)) / 1000), distanceMeters: routeDistance(points), points })
      setStatus('saved'); setMessage('Actividad guardada. La ruta precisa queda privada.')
    } catch (error) { setStatus('stopped'); setMessage(error.message || 'No se pudo guardar la actividad.') }
  }
  const exportRoute = async () => {
    if (!points.length) return
    const file = new File([gpxFor(points, type)], `enfermicambio-${type}-${new Date(startedAt).toISOString().slice(0, 10)}.gpx`, { type: 'application/gpx+xml' })
    if (navigator.canShare?.({ files: [file] })) {
      await navigator.share({ title: 'Ruta de EnfermiCambio', files: [file] })
      setMessage('Ruta preparada para compartir con tu aplicación deportiva.')
      return
    }
    const url = URL.createObjectURL(file)
    const link = document.createElement('a'); link.href = url; link.download = file.name; link.click()
    URL.revokeObjectURL(url)
    setMessage('Ruta GPX descargada. Puedes importarla en Strava, Komoot u otra aplicación compatible.')
  }

  const distance = routeDistance(points)
  return <main className="ec-page ec-activity-recorder">
    <header className="ec-topbar"><div><p className="ec-kicker">Actividad al aire libre</p><h1>Registra tu ruta</h1><p className="ec-subtitle">Tiempo, distancia y mapa desde el GPS del teléfono.</p></div></header>
    <div className="ec-activity-types" role="radiogroup" aria-label="Tipo de actividad">{TYPES.map(([value, label, icon]) => <button role="radio" aria-checked={type === value} className={type === value ? 'on' : ''} disabled={status === 'recording'} key={value} onClick={() => setType(value)}><Icon name={icon} /><span>{label}</span></button>)}</div>
    <RouteMap points={points} />
    <section className="ec-route-stats" aria-label="Resumen de la actividad"><div><small>Tiempo</small><strong>{formatDuration(elapsed)}</strong></div><div><small>Distancia</small><strong>{(distance / 1000).toLocaleString('es-CL', { maximumFractionDigits: 2 })}<span> km</span></strong></div><div><small>GPS</small><strong>{points.length}<span> puntos</span></strong></div></section>
    <div className="ec-route-actions">{status === 'idle' && <button className="ec-primary" onClick={start}><Icon name="play" /> Comenzar grabación</button>}{status === 'recording' && <button className="ec-stop-route" onClick={stop}><Icon name="pause" /> Detener</button>}{status === 'stopped' && <><button className="ec-primary" onClick={save}><Icon name="check" /> Guardar actividad</button><button className="ec-secondary" onClick={exportRoute}><Icon name="share" /> Compartir GPX</button><button className="ec-secondary" onClick={discard}>Descartar</button></>}{status === 'saved' && <><button className="ec-secondary" onClick={exportRoute}><Icon name="share" /> Compartir con otra app</button><button className="ec-secondary" onClick={discard}>Registrar otra</button></>}</div>
    {message && <div className="ec-route-message" role="status">{message}</div>}
    <aside className="ec-route-privacy"><Icon name="lock" /><p><b>Tu ubicación es sensible</b><span>Los puntos precisos se guardan privados. En iPhone y Android una PWA no puede garantizar GPS continuo en segundo plano; mantén la pantalla de la app abierta mientras grabas.</span></p></aside>
  </main>
}
