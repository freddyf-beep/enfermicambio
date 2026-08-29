import { useEffect, useRef, useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import Icon from '../components/Icon.jsx'
import { scanBarcodeFile } from '../lib/barcode-scan.js'
import { optimizePhoto } from '../lib/image-file.js'
import { useSocial } from '../store/useSocial.js'
import { importFromApp } from '../sheets.jsx'
import { supabase } from '../lib/supabase.js'

const emptyMeal = () => ({ meal_type: 'lunch', quantity: 1, unit: 'serving', calories: '', protein_g: 0, carbs_g: 0, fat_g: 0, notes: '' })

function PhotoActions({ file, preview, onCamera, onGallery, onRemove, privateLabel }) {
  return <div className="ec-photo-box">
    {preview ? <div className="ec-photo-preview"><img src={preview} alt="Vista previa" /><button onClick={onRemove} aria-label="Quitar foto"><Icon name="xmark" /></button></div> : <span className="ec-photo-empty"><Icon name="camera" /><b>Agrega una foto</b><small>{privateLabel}</small></span>}
    <div className="ec-photo-actions"><button onClick={onCamera}><Icon name="camera" /> Tomar foto</button><button onClick={onGallery}><Icon name="image" /> Elegir de galería</button></div>
    {file && <small className="ec-file-note">{file.name} · {(file.size / 1024 / 1024).toFixed(1)} MB</small>}
  </div>
}

export default function Register() {
  const { createPost, createPhotoPost, logFood, foodEntries = [], demo } = useSocial()
  const nav = useNavigate()
  const [params] = useSearchParams()
  const initialMode = ['meal', 'post', 'activity'].includes(params.get('mode')) ? params.get('mode') : null
  const [mode, setMode] = useState(initialMode)
  const [caption, setCaption] = useState('')
  const [photo, setPhoto] = useState(null)
  const [photoPreview, setPhotoPreview] = useState('')
  const [meal, setMeal] = useState(emptyMeal)
  const [mealPhoto, setMealPhoto] = useState(null)
  const [mealPhotoPreview, setMealPhotoPreview] = useState('')
  const [barcode, setBarcode] = useState('')
  const [foodName, setFoodName] = useState('')
  const [looking, setLooking] = useState(false)
  const [scanning, setScanning] = useState(false)
  const [message, setMessage] = useState('')
  const postCamera = useRef(null); const postGallery = useRef(null)
  const mealCamera = useRef(null); const mealGallery = useRef(null)
  const barcodeCamera = useRef(null); const barcodeGallery = useRef(null); const activityImport = useRef(null)

  useEffect(() => {
    if (!photo) { setPhotoPreview(''); return undefined }
    const url = URL.createObjectURL(photo); setPhotoPreview(url)
    return () => URL.revokeObjectURL(url)
  }, [photo])
  useEffect(() => {
    if (!mealPhoto) { setMealPhotoPreview(''); return undefined }
    const url = URL.createObjectURL(mealPhoto); setMealPhotoPreview(url)
    return () => URL.revokeObjectURL(url)
  }, [mealPhoto])

  const pick = async (event, setter) => {
    const file = event.target.files?.[0]
    event.target.value = ''
    if (file) setter(await optimizePhoto(file))
  }
  const run = async (fn, success) => {
    try { await fn(); setMessage(demo ? 'Guardado en la demostración local.' : success) }
    catch (error) { setMessage(error.message) }
  }
  const lookup = async (requestedCode = barcode) => {
    const code = String(requestedCode || '').trim()
    if (!code) return
    if (![8, 12, 13, 14].includes(code.length) || !/^\d+$/.test(code)) { setMessage('Ingresa un código EAN/UPC válido de 8, 12, 13 o 14 dígitos.'); return }
    setLooking(true); setMessage('')
    try {
      let cached = null
      if (supabase) {
        const result = await supabase.from('foods').select('name,brand,calories,protein_g,carbs_g,fat_g').eq('barcode', code).maybeSingle()
        if (!result.error) cached = result.data
      }
      let product = cached
      if (!product) {
        const fields = 'code,product_name,product_name_es,brands,serving_quantity,nutriments'
        let body
        if (supabase) {
          const result = await supabase.functions.invoke('food_lookup', { body: { barcode: code } })
          if (result.error) throw result.error
          body = result.data
        } else {
          const response = await fetch(`https://world.openfoodfacts.org/api/v3/product/${encodeURIComponent(code)}?cc=cl&lc=es&fields=${fields}`)
          body = await response.json()
          if (!response.ok) throw new Error('El catálogo no está disponible en este momento.')
        }
        if (!body?.product) throw new Error('No encontramos este producto. Puedes ingresar sus datos manualmente y quedará disponible la próxima vez.')
        const p = body.product; const n = p.nutriments || {}
        const value = (serving, per100) => Number(n[serving] ?? n[per100] ?? 0)
        product = { name: p.product_name_es || p.product_name || 'Producto escaneado', brand: p.brands || null, calories: value('energy-kcal_serving', 'energy-kcal_100g'), protein_g: value('proteins_serving', 'proteins_100g'), carbs_g: value('carbohydrates_serving', 'carbohydrates_100g'), fat_g: value('fat_serving', 'fat_100g') }
        if (supabase) {
          const { data: { user } } = await supabase.auth.getUser()
          await supabase.from('foods').insert({ barcode: code, ...product, serving_size: Number(p.serving_quantity) || 100, serving_unit: p.serving_quantity ? 'serving' : 'g', source: 'open_food_facts_cl', created_by: user?.id || null }).then(() => {}).catch(() => {})
        }
      }
      const name = product.name
      setFoodName(name)
      setMeal(current => ({ ...current, notes: name, calories: Number(product.calories) || 0, protein_g: Number(product.protein_g) || 0, carbs_g: Number(product.carbs_g) || 0, fat_g: Number(product.fat_g) || 0 }))
    } catch (error) { setMessage(error.message) } finally { setLooking(false) }
  }
  const scanProduct = async event => {
    const file = event.target.files?.[0]
    event.target.value = ''
    if (!file) return
    setScanning(true); setMessage('')
    try {
      const value = await scanBarcodeFile(file)
      setBarcode(value)
      await lookup(value)
    } catch (error) { setMessage(error.message) }
    finally { setScanning(false) }
  }

  const postInputs = <><input ref={postCamera} className="ec-hidden-input" type="file" accept="image/*" capture="environment" onChange={event => pick(event, setPhoto)} /><input ref={postGallery} className="ec-hidden-input" type="file" accept="image/*" onChange={event => pick(event, setPhoto)} /></>
  const mealInputs = <><input ref={mealCamera} className="ec-hidden-input" type="file" accept="image/*" capture="environment" onChange={event => pick(event, setMealPhoto)} /><input ref={mealGallery} className="ec-hidden-input" type="file" accept="image/*" onChange={event => pick(event, setMealPhoto)} /></>
  const modeCopy = {
    meal: { kicker: 'Registro privado', title: 'Comida', subtitle: 'Foto, código de barras o ingreso manual.', icon: 'food', tone: 'coral' },
    post: { kicker: 'Compartido con el grupo', title: 'Publicación', subtitle: 'Una foto o mensaje para tus cuatro compañeros.', icon: 'camera', tone: 'violet' },
    activity: { kicker: 'Movimiento y salud', title: 'Actividad', subtitle: 'Entrenamiento, ruta, peso o sincronización.', icon: 'activity', tone: 'lime' },
  }
  const chooseMode = next => { setMode(next); setMessage(''); nav(`/register?mode=${next}`, { replace: true }) }
  const clearMode = () => { setMode(null); setMessage(''); nav('/register', { replace: true }) }
  const heading = mode ? modeCopy[mode] : { kicker: 'Registrar', title: '¿Qué quieres guardar?', subtitle: 'Elige una acción; cada flujo muestra solo lo necesario.' }
  const recentMeals = [...new Map(foodEntries.filter(item => item.notes).map(item => [item.notes.trim().toLowerCase(), item])).values()].slice(0, 4)
  const reuseMeal = item => {
    setFoodName(item.notes)
    setMeal(current => ({ ...current, meal_type: item.meal_type || current.meal_type, notes: item.notes, calories: Number(item.calories) || 0, protein_g: Number(item.protein_g) || 0, carbs_g: Number(item.carbs_g) || 0, fat_g: Number(item.fat_g) || 0 }))
  }

  return <div className="ec-page">
    <header className="ec-topbar ec-register-topbar"><div>{mode && <button className="ec-register-back" onClick={clearMode}><Icon name="chevronLeft" /> Cambiar tipo</button>}<p className="ec-kicker">{heading.kicker}</p><h1>{heading.title}</h1><p className="ec-subtitle">{heading.subtitle}</p></div></header>

    {!mode && <section className="ec-register-launcher">
      <div className="ec-register-choices">
        <button className="meal" onClick={() => chooseMode('meal')}>
          <span className="ec-register-choice-icon"><Icon name="food" /></span>
          <span className="ec-register-choice-copy"><small><Icon name="lock" /> Solo tú</small><b>Registrar comida</b><em>Foto, envase o datos nutricionales.</em></span>
          <Icon name="chevronRight" />
        </button>
        <button className="post" onClick={() => chooseMode('post')}>
          <span className="ec-register-choice-icon"><Icon name="camera" /></span>
          <span className="ec-register-choice-copy"><small><Icon name="people" /> Grupo privado</small><b>Crear publicación</b><em>Comparte una foto, un logro o un mensaje.</em></span>
          <Icon name="chevronRight" />
        </button>
        <button className="activity" onClick={() => chooseMode('activity')}>
          <span className="ec-register-choice-icon"><Icon name="activity" /></span>
          <span className="ec-register-choice-copy"><small><Icon name="lock" /> Actividad personal</small><b>Registrar actividad</b><em>Entrenamiento, GPS, peso o salud.</em></span>
          <Icon name="chevronRight" />
        </button>
      </div>
      <p className="ec-register-assurance"><Icon name="shield" /> Antes de guardar siempre verás si el dato es privado o si se comparte con el grupo.</p>
    </section>}

    {mode === 'meal' && <section className="ec-capture-section">
      <div className="ec-privacy-line"><Icon name="lock" /><span>La nutrición queda privada; la foto solo se comparte si tú lo decides.</span></div>
      {recentMeals.length > 0 && <div className="ec-recent-food"><div><small>REPETIR RÁPIDO</small><b>Comidas de hoy</b></div><div>{recentMeals.map(item => <button key={item.id} onClick={() => reuseMeal(item)}><span>{item.notes}</span><small>{Number(item.calories).toLocaleString('es-CL')} kcal</small></button>)}</div></div>}
      {mealInputs}<PhotoActions file={mealPhoto} preview={mealPhotoPreview} onCamera={() => mealCamera.current?.click()} onGallery={() => mealGallery.current?.click()} onRemove={() => setMealPhoto(null)} privateLabel="Puedes tomarla ahora o usar una de tu galería." />
      <div className="ec-divider-label"><span>o busca un producto</span></div>
      <div className="ec-barcode"><Icon name="barcode" /><input inputMode="numeric" aria-label="Código de barras" placeholder="Código de barras" value={barcode} onChange={event => setBarcode(event.target.value.replace(/\D/g, ''))} /><button onClick={() => lookup()} disabled={!barcode || looking}>{looking ? 'Buscando…' : 'Buscar'}</button></div>
      <input ref={barcodeCamera} className="ec-hidden-input" type="file" accept="image/*" capture="environment" onChange={scanProduct} />
      <input ref={barcodeGallery} className="ec-hidden-input" type="file" accept="image/*" onChange={scanProduct} />
      <div className="ec-barcode-actions"><button onClick={() => barcodeCamera.current?.click()} disabled={scanning}><Icon name="camera" /> Escanear envase</button><button onClick={() => barcodeGallery.current?.click()} disabled={scanning}><Icon name="image" /> Leer una foto</button></div>
      {scanning && <div className="ec-scan-status" role="status"><Icon name="barcode" /> Analizando el código en este dispositivo…</div>}
      {foodName && <div className="ec-success"><Icon name="checkCircle" /> {foodName}</div>}
      <div className="ec-form">
        <label><span>Alimento</span><input value={meal.notes} placeholder="Ej. arroz con pollo" onChange={event => { setFoodName(event.target.value); setMeal({ ...meal, notes: event.target.value }) }} /></label>
        <div className="ec-form-row"><label><span>Momento</span><select value={meal.meal_type} onChange={event => setMeal({ ...meal, meal_type: event.target.value })}><option value="breakfast">Desayuno</option><option value="lunch">Almuerzo</option><option value="dinner">Cena</option><option value="snack">Snack</option><option value="other">Otro</option></select></label><label><span>Porciones</span><input type="number" inputMode="decimal" min="0.01" step="0.25" value={meal.quantity} onChange={event => setMeal({ ...meal, quantity: Number(event.target.value) })} /></label></div>
        <label><span>Calorías estimadas</span><input type="number" inputMode="numeric" min="0" placeholder="0" value={meal.calories} onChange={event => setMeal({ ...meal, calories: Number(event.target.value) })} /></label>
        <details className="ec-details"><summary>Agregar proteínas, carbohidratos y grasa</summary><div className="ec-form-row"><label><span>Proteína (g)</span><input type="number" min="0" value={meal.protein_g} onChange={event => setMeal({ ...meal, protein_g: Number(event.target.value) })} /></label><label><span>Carbohidratos (g)</span><input type="number" min="0" value={meal.carbs_g} onChange={event => setMeal({ ...meal, carbs_g: Number(event.target.value) })} /></label></div><label><span>Grasa (g)</span><input type="number" min="0" value={meal.fat_g} onChange={event => setMeal({ ...meal, fat_g: Number(event.target.value) })} /></label></details>
      </div>
      <button className="ec-primary" disabled={!meal.calories || !meal.notes?.trim()} onClick={() => run(async () => { await logFood(meal, mealPhoto); setMeal(emptyMeal()); setMealPhoto(null); setFoodName(''); setBarcode('') }, 'Comida guardada de forma privada.')}>Guardar comida</button>
    </section>}

    {mode === 'post' && <section className="ec-capture-section">
      <div className="ec-privacy-line shared"><Icon name="people" /><span>Esto se publicará para Freddy, Pipe, Sami y Cruz.</span></div>
      {postInputs}<PhotoActions file={photo} preview={photoPreview} onCamera={() => postCamera.current?.click()} onGallery={() => postGallery.current?.click()} onRemove={() => setPhoto(null)} privateLabel="La vista previa aparece antes de publicar." />
      <div className="ec-form"><label><span>Cuéntales algo</span><textarea placeholder="Entrenamiento, meta, logro o comentario…" value={caption} onChange={event => setCaption(event.target.value)} /></label></div>
      <button className="ec-primary" disabled={!caption.trim() && !photo} onClick={() => run(async () => { if (photo) await createPhotoPost(caption, photo); else await createPost(caption); setCaption(''); setPhoto(null) }, 'Publicado para el grupo.')}>Publicar al grupo</button>
    </section>}

    {mode === 'activity' && <section className="ec-capture-section"><input ref={activityImport} className="ec-hidden-input" type="file" accept=".csv,.xml,text/csv,text/xml" onChange={event => { const file = event.target.files?.[0]; if (file) importFromApp(file); event.target.value = '' }} /><div className="ec-action-list">
      <button onClick={() => nav('/train')}><span className="lime"><Icon name="dumbbell" /></span><p><b>Empezar entrenamiento</b><small>Rutina, sesión libre o continuar una activa</small></p><Icon name="chevronRight" /></button>
      <button onClick={() => nav('/activity')}><span className="violet"><Icon name="route" /></span><p><b>Registrar ruta con GPS</b><small>Caminata, carrera o bicicleta con mapa</small></p><Icon name="chevronRight" /></button>
      <button onClick={() => activityImport.current?.click()}><span className="coral"><Icon name="upload" /></span><p><b>Cargar entrenamiento</b><small>Importar FitNotes, Strong o Hevy</small></p><Icon name="chevronRight" /></button>
      <button onClick={() => nav('/weight')}><span className="blue"><Icon name="scale" /></span><p><b>Registrar peso</b><small>Dato privado y evolución personal</small></p><Icon name="chevronRight" /></button>
      <button onClick={() => nav('/health-import')}><span className="coral"><Icon name="refresh" /></span><p><b>Sincronizar salud</b><small>Pasos, calorías, distancia y entrenamientos</small></p><Icon name="chevronRight" /></button>
    </div></section>}
    {message && <div className="ec-result" role="status">{message}</div>}
  </div>
}
