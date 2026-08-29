const { OBSWebSocket } = require('obs-websocket-js')

const URL = 'ws://127.0.0.1:4455'
const PASS = 'VFqcYiF1GWLdLSuL'

async function main() {
  const o = new OBSWebSocket()
  await o.connect(URL, PASS)
  const op = process.argv[2]
  if (op === 'toggle') {
    await o.call('SetSceneItemEnabled', {
      sceneName: 'Tutorial Android',
      sceneItemId: 3,
      sceneItemEnabled: false,
    })
    await new Promise((r) => setTimeout(r, 500))
    await o.call('SetSceneItemEnabled', {
      sceneName: 'Tutorial Android',
      sceneItemId: 3,
      sceneItemEnabled: true,
    })
    await new Promise((r) => setTimeout(r, 1500))
    const st = await o.call('GetSceneItemTransform', {
      sceneName: 'Tutorial Android',
      sceneItemId: 3,
    })
    console.log('AFTER TOGGLE:', st.sceneItemTransform.width, 'x', st.sceneItemTransform.height)
  } else if (op === 'fit') {
    const v = await o.call('GetVideoSettings')
    const cw = v.baseWidth
    const ch = v.baseHeight
    const scale = Math.min(cw / 430, ch / 860)
    await o.call('SetSceneItemTransform', {
      sceneName: 'Tutorial Android',
      sceneItemId: 3,
      sceneItemTransform: {
        // alignment 0 = centro. Con position (cw/2, ch/2) el item queda centrado.
        // OJO: alignment 5 significa "arriba-izquierda", que desplaza el contenido
        // hacia la esquina inferior derecha cuando se fija position en el centro.
        alignment: 0,
        boundsAlignment: 0,
        boundsType: 'OBS_BOUNDS_NONE',
        positionX: cw / 2,
        positionY: ch / 2,
        scaleX: scale,
        scaleY: scale,
      },
    })
    const st = await o.call('GetSceneItemTransform', {
      sceneName: 'Tutorial Android',
      sceneItemId: 3,
    })
    console.log('FIT scale=', scale, '=> size', st.sceneItemTransform.width, 'x', st.sceneItemTransform.height, 'align', st.sceneItemTransform.alignment, 'pos', st.sceneItemTransform.positionX, st.sceneItemTransform.positionY)
  } else if (op === 'record') {
    const dur = Number(process.argv[3] || 6)
    await o.call('StartRecord')
    console.log('REC started')
    await new Promise((r) => setTimeout(r, dur * 1000))
    const st = await o.call('StopRecord')
    console.log('path', st.outputPath)
  } else if (op === 'scene') {
    const cur = await o.call('GetCurrentProgramScene')
    console.log('PROG:', cur.currentProgramSceneName)
    const items = await o.call('GetSceneItemList', { sceneName: 'Tutorial Android' })
    console.log('ITEMS:', JSON.stringify(items.sceneItems.map((x) => ({ name: x.sourceName, id: x.sceneItemId }))))
  }
  await o.disconnect()
}

main().catch((e) => {
  console.error('ERR', e.message)
  process.exit(1)
})
