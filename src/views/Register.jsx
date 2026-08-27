import { useState } from 'react'
import { useSocial } from '../store/useSocial.js'

export default function Register() {
  const { createPost, logFood, demo } = useSocial()
  const [caption, setCaption] = useState('')
  const [meal, setMeal] = useState({ meal_type: 'lunch', quantity: 1, unit: 'serving', calories: '', protein_g: 0, carbs_g: 0, fat_g: 0 })
  const [barcode, setBarcode] = useState('')
  const [foodName, setFoodName] = useState('')
  const [looking, setLooking] = useState(false)
  const [message, setMessage] = useState('')
  const run = async fn => { try { await fn(); setMessage(demo ? 'Guardado en la demostración local.' : 'Guardado y compartido.'); } catch (e) { setMessage(e.message) } }
  const lookup = async () => {
    setLooking(true); setMessage('')
    try {
      const response = await fetch(`https://world.openfoodfacts.org/api/v2/product/${encodeURIComponent(barcode.trim())}.json`)
      const body = await response.json()
      if (!response.ok || body.status !== 1 || !body.product) throw new Error('Producto no encontrado en Open Food Facts.')
      const p = body.product; const n = p.nutriments || {}
      const value = (serving, per100) => Number(n[serving] ?? n[per100] ?? 0)
      const name = p.product_name_es || p.product_name || 'Producto escaneado'
      setFoodName(name)
      setMeal(current => ({ ...current, notes: name,
        calories: value('energy-kcal_serving', 'energy-kcal_100g'),
        protein_g: value('proteins_serving', 'proteins_100g'),
        carbs_g: value('carbohydrates_serving', 'carbohydrates_100g'),
        fat_g: value('fat_serving', 'fat_100g'),
      }))
    } catch (e) { setMessage(e.message) } finally { setLooking(false) }
  }
  return <div className="social-page"><header className="social-head"><div><p className="eyebrow">REGISTRAR</p><h1>¿Qué hiciste?</h1></div></header>
    <section className="social-card"><h2>Publicación</h2><textarea className="social-textarea" placeholder="Comparte un entrenamiento, una meta o una foto…" value={caption} onChange={e => setCaption(e.target.value)} /><button className="social-primary" onClick={() => run(async () => { await createPost(caption); setCaption('') })}>Publicar al grupo</button></section>
    <section className="social-card"><h2>Comida rápida</h2><div className="barcode-row"><input inputMode="numeric" placeholder="Código de barras" value={barcode} onChange={e => setBarcode(e.target.value.replace(/\D/g, ''))} /><button onClick={lookup} disabled={!barcode || looking}>{looking ? 'Buscando…' : 'Buscar'}</button></div>{foodName && <div className="food-result">✓ {foodName}</div>}<div className="social-form grid-form">
      <label>Tipo<select value={meal.meal_type} onChange={e => setMeal({ ...meal, meal_type: e.target.value })}><option value="breakfast">Desayuno</option><option value="lunch">Almuerzo</option><option value="dinner">Cena</option><option value="snack">Snack</option><option value="other">Otro</option></select></label>
      <label>Calorías<input type="number" min="0" value={meal.calories} onChange={e => setMeal({ ...meal, calories: Number(e.target.value) })} /></label>
      <label>Proteína (g)<input type="number" min="0" value={meal.protein_g} onChange={e => setMeal({ ...meal, protein_g: Number(e.target.value) })} /></label>
      <label>Carbohidratos (g)<input type="number" min="0" value={meal.carbs_g} onChange={e => setMeal({ ...meal, carbs_g: Number(e.target.value) })} /></label>
      <label>Grasa (g)<input type="number" min="0" value={meal.fat_g} onChange={e => setMeal({ ...meal, fat_g: Number(e.target.value) })} /></label>
    </div><button className="social-primary" disabled={!meal.calories} onClick={() => run(() => logFood(meal))}>Guardar comida</button></section>
    {message && <div className="toast-inline">{message}</div>}
  </div>
}
