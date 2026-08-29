# Grabación de tutoriales — EnfermiCambio PWA

Este directorio deja listo el equipo para grabar los tutoriales de
**EnfermiCambio en formato PWA** (no la app nativa). La PWA oficial vive en
[`pwa/`](../../pwa) y se sirve desde
**https://enfermicambio-98b5a.web.app**. Aquí se documenta el flujo Android
verificado de punta a punta y el roadmap de espejo/control de iPhone.

---

## 1. Flujo Android (verificado)

Resultado: **funcional y confirmado**. El emulador Android proyecta la PWA
mediante `scrcpy`, y OBS graba la ventana a **1080x2400 @ 30 fps** llenando el
canvas, sin barras ni frame negro.

Arquitectura de la grabación:

```text
emulador Android (1080x2400)
        │  adb
        ▼
scrcpy ventana "SCRCPY-EnfermiCambio"
        │  window capture
        ▼
OBS escena "Tutorial Android"  →  1080x2400 @ 30fps
```

### Componentes instalados

| Componente | Ruta / versión | Estado |
| --- | --- | --- |
| Emulador Android | Android SDK, `emulator-5554`, `1080x2400`, densidad 420 | ✅ online |
| ADB | `C:\Users\fredd\AppData\Local\Android\Sdk\platform-tools\adb.exe` | ✅ |
| scrcpy | WinGet, `scrcpy-win64-v4.1` | ✅ corriendo |
| OBS | 32.2.1, websocket `ws://127.0.0.1:4455` | ✅ abierto |
| Fuente OBS | `Captura PWA` (`window_capture`) → `SCRCPY-EnfermiCambio` | ✅ centrada y a pantalla |

### Verificación end-to-end

Evidencia de que el flujo quedó impecable:

- Emulador `emulator-5554` online, `sys.boot_completed=1`, físico `1080x2400`.
- scrcpy PID `20704` con ventana `SCRCPY-EnfermiCambio` (respondiendo).
- OBS en escena `Tutorial Android`, vídeo `1080x2400@30fps`.
- Fuente `Captura PWA`: `window_capture`, item `3`, `pos=540,1200`,
  `boundsType=OBS_BOUNDS_STRETCH`, tamaño `~421x936` → llena el canvas.
- Clip de prueba grabado y revisado a `1080x2400`; el frame extraído muestra
  el login de EnfermiCambio a pantalla completa, sin barras ni zonas negras.

Los clips de verificación quedaron en `C:\Users\fredd\Videos\`.

---

## 2. Comandos de operación (Android)

Todos los scripts se ejecutan desde `tools/tutorials`.

### Levantar la PWA en el emulador

```powershell
powershell -ExecutionPolicy Bypass -File .\open_pwa_emu.ps1
```

### Lanzar la PWA como ventana standalone en Chrome (PC)

Para grabar la PWA con login desde el equipo (alternativa al emulador):

```powershell
powershell -ExecutionPolicy Bypass -File .\launch_pwa.ps1
```

### Conectar y lanzar scrcpy

Verificar que el dispositivo está en línea y proyectar:

```powershell
adb devices
adb -s emulator-5554 shell am start -a android.intent.action.VIEW -d https://enfermicambio-98b5a.web.app/
scrcpy --window-title "SCRCPY-EnfermiCambio" -s emulator-5554
```

Si `scrcpy` no abre la ventana, matar la instancia previa y relanzar:

```powershell
Get-Process scrcpy -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
scrcpy --window-title "SCRCPY-EnfermiCambio" -s emulator-5554
```

### Reconfigurar la fuente OBS hacia scrcpy

Apunta la fuente `Captura PWA` a la ventana de scrcpy y la encuadra a
pantalla completa en el canvas 1080x2400:

```powershell
node obs_fill_scrcpy.cjs
```

### Grabar y detener

```powershell
node obs.cjs record 10      # graba 10s
node obs.cjs scene          # lista escena e items
node obs.cjs fit            # re-encuadra si se movió
```

### Enfocar la ventana de la PWA en el PC

```powershell
powershell -ExecutionPolicy Bypass -File .\focus_pwa.ps1
```

### Resolver encuadres / listar ventanas

```powershell
powershell -ExecutionPolicy Bypass -File .\list_windows.ps1 -Filter scrcpy
powershell -ExecutionPolicy Bypass -File .\list_windows_rect.ps1 -Filter scrcpy
powershell -ExecutionPolicy Bypass -File .\window_rect.ps1 -Handle <HWND>
```

> Si el encuadre se desvirtúa tras mover la ventana, vuelve a ejecutar
> `node obs_fill_scrcpy.cjs`.

---

## 3. Flujo de la PWA que muestran los tutoriales

La PWA no requiere APK ni Play Store. El contenido de los tres tutoriales
(instalación, vinculación de datos, puesta en marcha) sigue este orden,
extraído de `pwa/README.md`, `docs/PWA_ROADMAP.md` y `docs/PWA_VERIFICATION.md`:

1. **Abrir** `https://enfermicambio-98b5a.web.app` en el navegador del emulador
   (o del dispositivo real).
2. **Iniciar sesión** con una cuenta de la allowlist. No existe registro
   público; solo entran las cuentas autorizadas.
3. **Instalar la PWA**: `Nosotros → Instalar aplicación`. En Android, `Agregar
   a pantalla principal`; en iOS, `Compartir → Agregar a inicio`.
4. **Vincular datos de salud**:
   - **Android**: `Nosotros → Importación de salud`, generar el token genérico
     y configurarlo como `Authorization: Bearer TOKEN` en el exportador
     compatible con Health Connect. Enviar un día dos veces confirma que el
     total se reemplaza sin duplicarse.
   - **iPhone**: `Nosotros → Importación de salud`, preparar Health Auto Export
     y abrir los dos enlaces en el mismo iPhone. Ejecutar una exportación de
     uno o dos días y confirmar que la hora de la última recepción cambia.
5. **Verificar datos**: el dashboard `HOY`, el ranking y el feed deben mostrar
   los datos del usuario.

Esto es lo que verás grabado al dejar la app operativa.

---

## 4. Roadmap iPhone (sin verificar en este momento)

No se pudo probar porque el iPhone no está disponible en esta sesión. Lo que
sigue es el resultado de la investigación (2026-08-28) y debe validarse cuando
haya iPhone a mano.

### Dato clave de Apple

Apple **no permite que apps de terceros tomen control remoto total** del iPhone.
La única vía nativa de *control real* es **iPhone Mirroring**, que solo funciona
de **iPhone → Mac** (iOS 18+ / macOS 15+). Por eso:

- Si los tutoriales son de **solo espejo** (ver y grabar la pantalla), cualquier
  receptor AirPlay en Windows sirve.
- Si necesitas **controlar (tocar/navegar)** el iPhone desde el PC, la opción
  real disponible es una app de control remoto a través de red/USB. Eso reduce
  la fidelidad y requiere aceptar el alcance de Apple.

### A) Solo espejo (ver + grabar) — recomendado para tutoriales

Estas apps convierten el PC en un receptor AirPlay. Requieren iPhone y PC en la
misma red Wi-Fi. Son gratuitas y suficientes para grabar la pantalla:

| App | Cómo usarla |
| --- | --- |
| **LonelyScreen** | Instalar en PC, abrir el receptor AirPlay, luego en iPhone: `Centro de control → Screen Mirroring → LonelyScreen`. |
| **5KPlayer** | Instalar, clic en el icono AirPlay, luego `Screen Mirroring → 5KPlayer`. |
| **AnyMiro** | Instalar, conectar iPhone por cable, tocar `Trust` en el iPhone. Soporta 4K y permite capturar la ventana con OBS. |

Cualquiera de las tres produce una ventana en el PC que OBS puede capturar como
`window_capture`, igual que con scrcpy. La más estable para grabar con OBS es la
de **conexión USB (AnyMiro)** porque no depende de la Wi-Fi durante la grabación.

### B) Espejo + control (tocar desde el PC)

Estas permiten interactuar, aunque con limitaciones y normalmente con versión
de pago para uso prolongado:

| App | Método |
| --- | --- |
| **AirDroid Cast** | USB o Wi-Fi; permite controlar el iPhone desde el PC sin jailbreak. |
| **ApowerMirror** | USB o AirPlay; ofrece control y es popular para tutoriales. |
| **TeamViewer / QuickSupport** | Iniciar sesión, compartir el ID y conectar; orientado a soporte, no a una sesión fluida de grabación. |
| **iMyFone MirrorTo** | Wi-Fi o USB; enfocado a asistencia y control. |

Para grabar, la app de espejo/control se abre en el PC y OBS captura esa ventana.

### C) Configuración de grabación iPhone en OBS

1. Preparar el espejo (USB recomendado) y dejar la ventana visible.
2. En OBS, añadir una fuente `Window Capture` apuntando a la ventana de la app.
3. Ajustar el encuadre al canvas 1080x2400 (reusar el patrón de
   `obs_fill_scrcpy.cjs` cambiando el nombre de ventana).
4. Grabar y revisar un frame de prueba.

### Pendiente cuando haya iPhone

- Elegir y validar el método (recomendado: USB + AnyMiro para espejo OBS).
- Confirmar que la app de espejo permite grabar la ventana sin marcas de agua.
- Probar el flujo de login e instalación de la PWA en Safari, ya que iOS no
  instala desde Chrome.
- Registrar el frame verificado a 1080x2400 igual que en Android.

---

## 5. Checklist antes de grabar cada tutorial

- [ ] Emulador online: `adb devices` muestra `emulator-5554  device`.
- [ ] scrcpy con ventana `SCRCPY-EnfermiCambio` visible.
- [ ] OBS en escena `Tutorial Android`.
- [ ] `node obs_fill_scrcpy.cjs` para re-encuadrar.
- [ ] Ventana de la app enfocada y sin diálogos superpuestos.
- [ ] Grabar un clip corto de prueba y revisar el primer frame.

---

## 6. Notas / limitaciones

- La fuente PWA puede quedar apuntando a una ventana huérfana si se cierra y
  se abre Chrome/scrcpy varias veces. En ese caso, vuelve a ejecutar
  `node obs_fill_scrcpy.cjs`, que re-resuelve la ventana visible.
- La ventana standalone de Chrome (`EnfermiCambio`) también puede capturarse,
  pero para el emulador la vía correcta es scrcpy. El flujo verificado usa
  scrcpy.
- No se probó el espejo/control de iPhone en esta sesión. El roadmap de la
  sección 4 es orientativo hasta validación con el dispositivo.
