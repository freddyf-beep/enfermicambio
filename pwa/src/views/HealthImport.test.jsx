// @vitest-environment happy-dom
import { act } from 'react'
import { createRoot } from 'react-dom/client'
import { afterEach, beforeEach, expect, it } from 'vitest'
import HealthImport from './HealthImport.jsx'

let root
beforeEach(() => { globalThis.IS_REACT_ACT_ENVIRONMENT = true; document.body.innerHTML = '<div id="root"></div>' })
afterEach(() => act(() => root?.unmount()))

it('explains the safe demo behavior when Supabase is not configured', async () => {
  root = createRoot(document.getElementById('root'))
  await act(async () => root.render(<HealthImport />))
  expect(document.body.textContent).toContain('Salud del teléfono')
  expect(document.body.textContent).toContain('Esta es la demostración')
  expect(document.body.textContent).toContain('enlaces y tokens privados')
  expect(document.body.textContent).toContain('Generar token e instalar Atajo')
})
