#!/usr/bin/env node
/**
 * Ajusta la fuente "Captura PWA" para que llene exactamente el canvas 1080x2400.
 *
 * La ventana de scrcpy tiene el mismo aspect ratio del display del emulador
 * (1080x2400), así que usar STRETCH anclado al centro garantiza que la captura
 * ocupe todo el canvas sin barras ni recortes visibles.
 */
const { OBSWebSocket } = require('obs-websocket-js')

const URL = 'ws://127.0.0.1:4455'
const PASS = 'VFqcYiF1GWLdLSuL'

async function main() {
  const o = new OBSWebSocket()
  await o.connect(URL, PASS)

  const v = await o.call('GetVideoSettings')
  const cw = v.baseWidth
  const ch = v.baseHeight

  // Fuente correcta y windowsu item en la escena.
  await o.call('SetInputSettings', {
    inputName: 'Captura PWA',
    inputSettings: { window: 'SCRCPY-EnfermiCambio:SDL_app:scrcpy.exe' },
  })

  const list = await o.call('GetSceneItemList', { sceneName: 'Tutorial Android' })
  const item = list.sceneItems.find((x) => x.sourceName === 'Captura PWA')
  if (!item) throw new Error('No se encontró el item Captura PWA')

  await o.call('SetSceneItemTransform', {
    sceneName: 'Tutorial Android',
    sceneItemId: item.sceneItemId,
    sceneItemTransform: {
      alignment: 0, // centro
      boundsAlignment: 0, // centro
      boundsType: 'OBS_BOUNDS_STRETCH',
      boundsWidth: cw,
      boundsHeight: ch,
      positionX: cw / 2,
      positionY: ch / 2,
      scaleX: 1,
      scaleY: 1,
    },
  })

  const t = await o.call('GetSceneItemTransform', {
    sceneName: 'Tutorial Android',
    sceneItemId: item.sceneItemId,
  })
  console.log(
    `FILL canvas=${cw}x${ch} item=${t.sceneItemTransform.width.toFixed(1)}x${t.sceneItemTransform.height.toFixed(1)} ` +
      `pos=${t.sceneItemTransform.positionX},${t.sceneItemTransform.positionY} boundsType=${t.sceneItemTransform.boundsType}`,
  )

  await o.disconnect()
}

main().catch((e) => {
  console.error('ERR', e.message)
  process.exit(1)
})
