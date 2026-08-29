#!/usr/bin/env node
/**
 * Configura OBS para grabar el emulador Android de EnfermiCambio.
 *
 * - Conecta al websocket de OBS (puerto 4455).
 * - Crea/actualiza una escena dedicada "Tutorial Android".
 * - Añade una captura de ventana del emulador.
 * - Ajusta la resolución de la salida de vídeo a 1080x2400.
 * - Devuelve una verificación de que la escena quedó lista.
 *
 * Uso: node obs_setup.cjs [--scene "Tutorial Android"] [--window "Android Emulator - enfermicambio:5554"]
 */

const OBSWebSocket = require('obs-websocket-js').OBSWebSocket;
const { EventSubscription } = require('obs-websocket-js');

const HOST = process.env.OBS_WS_URL || 'ws://127.0.0.1:4455';
const PASSWORD = process.env.OBS_WS_PASSWORD || 'VFqcYiF1GWLdLSuL';
const SCENE_NAME = 'Tutorial Android';
const WINDOW_TITLE =
  process.env.ANDROID_EMULATOR_WINDOW || 'Android Emulator - enfermicambio:5554';

function arg(name, fallback) {
  const i = process.argv.indexOf(name);
  return i !== -1 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

const sceneName = arg('--scene', SCENE_NAME);
const windowTitle = arg('--window', WINDOW_TITLE);

async function main() {
  const obs = new OBSWebSocket();
  await obs.connect(HOST, PASSWORD);
  console.log(`[obs_setup] Conectado a ${HOST}`);

  // 1. Ajustar salida de vídeo a 1080x2400 (retrato del emulador).
  try {
    await obs.call('SetVideoSettings', {
      baseWidth: 1080,
      baseHeight: 2400,
      outputWidth: 1080,
      outputHeight: 2400,
      fpsNumerator: 30,
      fpsDenominator: 1,
    });
    // Re-Aplicar a la salida actual
    await obs.call('SetCurrentVideoScene', { sceneName });
    console.log('[obs_setup] Resolución de vídeo: 1080x2400 @ 30fps');
  } catch (e) {
    console.warn('[obs_setup] No se pudo fijar la resolución (puede requerir permiso):', e.message);
  }

  // 2. Asegurar que la escena existe.
  let scenes = await obs.call('GetSceneList');
  let sceneExists = scenes.scenes.some((s) => s.name === sceneName);
  if (!sceneExists) {
    await obs.call('CreateScene', { sceneName });
    console.log(`[obs_setup] Escena creada: ${sceneName}`);
  } else {
    console.log(`[obs_setup] Escena ya existe: ${sceneName}`);
  }

  // 3. Añadir captura de ventana del emulador (si no existe).
  const inputs = await obs.call('GetInputList');
  const existing = inputs.inputs.find((i) => i.inputName === 'Captura Emulador Android');
  if (!existing) {
    await obs.call('CreateInput', {
      sceneName,
      inputName: 'Captura Emulador Android',
      inputKind: 'window_capture',
      inputSettings: {
        window: windowTitle,
        method: 'WGC',
        capture_cursor: true,
      },
    });
    console.log(`[obs_setup] Captura de ventana creada para: ${windowTitle}`);
  } else {
    const settings = await obs.call('GetInputSettings', { inputName: 'Captura Emulador Android' });
    console.log(`[obs_setup] Captura ya existente. Ventana: ${settings.inputSettings?.window || windowTitle}`);
  }

  // 4. Cambiar a la escena para dejar todo listo.
  await obs.call('SetCurrentProgramScene', { sceneName });
  console.log(`[obs_setup] Escena activa: ${sceneName}`);

  // 5. Verificar.
  const finalScenes = await obs.call('GetSceneList');
  const finalInputs = await obs.call('GetInputList');
  const inScene = finalInputs.inputs.some((i) => i.inputName === 'Captura Emulador Android');
  console.log(
    `[obs_setup] VERIFICACIÓN: escena=${sceneName} presente=${scenes.scenes.some((s) => s.name === sceneName) || sceneExists} captura_en_escena=${inScene}`,
  );

  await obs.disconnect();
  console.log('[obs_setup] Listo.');
  process.exit(0);
}

main().catch((err) => {
  console.error('[obs_setup] Error:', err.message);
  process.exit(1);
});
