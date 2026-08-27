// @vitest-environment happy-dom
import { act } from 'react'
import { createRoot } from 'react-dom/client'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import App from './App.jsx'
import { useSocial } from './store/useSocial.js'

describe('Enfermicambio PWA shell', () => {
  let root
  beforeEach(() => {
    localStorage.clear()
    window.location.hash = '#/today'
    document.body.innerHTML = '<div id="root"></div>'
    useSocial.setState({ ready: false, session: null, profile: null, profiles: [], activity: [], posts: [], standings: [], notifications: [] })
  })
  afterEach(() => { act(() => root?.unmount()) })

  it('boots in safe demo mode and renders the six PWA destinations', async () => {
    root = createRoot(document.getElementById('root'))
    await act(async () => { root.render(<App />); await new Promise(resolve => setTimeout(resolve, 25)) })
    expect(document.body.textContent).toContain('Hola, Freddy')
    for (const label of ['Hoy', 'Ranking', 'Entrenar', 'Registrar', 'Juego', 'Nosotros']) {
      expect(document.body.textContent).toContain(label)
    }
    expect(document.querySelector('#social-tabbar')).not.toBeNull()
  })
})
