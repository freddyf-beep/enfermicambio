# Verificación y adopción de la PWA

URL oficial: **https://enfermicambio-98b5a.web.app**

## Evidencia automática completada

- 44 archivos de prueba y 546 pruebas aprobadas.
- Build Vite de producción aprobado.
- `npm audit` sin vulnerabilidades reportadas.
- HTML, manifest y service worker responden `200` por HTTPS; el service worker
  actual es v5, elimina las cachés anteriores al activarse y usa network-first
  para el HTML, de modo que cada deploy trae los hashes nuevos sin quedarse en
  un shell viejo.
- Manifest válido: nombre EnfermiCambio, modo `standalone` y dos iconos.
- HTML y manifest se sirven sin caché persistente; `/sw.js` se sirve con
  `Cache-Control: no-cache` para que cada apertura revalide el service worker
  y aplique actualizaciones sin reinstalar.
- Assets con hash se sirven con caché inmutable de un año.
- La compilación de producción contiene la configuración pública de Supabase.
- La migración PWA y `ingest_health` están aplicadas en el proyecto remoto.
- Flujo de entrenamiento verificado en el navegador con sesión real: Entrenar
  carga, el plan inicial PPL se crea (Push 6, Pull 5, Leg 6) y Workout lista
  las rutinas disponibles.
- El fix de `evaluate_missions` está aplicado: `evaluate_missions('2026-08-26')`
  y `'2026-08-27'` responden 200 y devuelven 4 misiones cada una; `close_day`
  responde 200 para ambos días.
- El cliente Flutter de respaldo mantiene 107/107 pruebas aprobadas y análisis
  estático sin observaciones.

## Matriz de aceptación por persona

Completar una fila por cada uno de los cuatro usuarios. No compartir tokens de
salud ni contraseñas en este archivo.

| Verificación | Freddy | Pipe | Sami | Cruz |
| --- | --- | --- | --- | --- |
| Abre la URL por HTTPS | ☐ | ☐ | ☐ | ☐ |
| Inicia sesión | ☐ | ☐ | ☐ | ☐ |
| Instala en pantalla de inicio | ☐ | ☐ | ☐ | ☐ |
| Cierra y abre en modo standalone | ☐ | ☐ | ☐ | ☐ |
| Ve solo sus datos privados | ☐ | ☐ | ☐ | ☐ |
| Recibe pasos del día | ☐ | ☐ | ☐ | ☐ |
| Publica, reacciona y comenta | ☐ | ☐ | ☐ | ☐ |
| Registra comida con porción y foto | ☐ | ☐ | ☐ | ☐ |
| Registra peso y lee notificaciones | ☐ | ☐ | ☐ | ☐ |
| Completa y sincroniza un entrenamiento | ☐ | ☐ | ☐ | ☐ |
| Abre después de perder conexión | ☐ | ☐ | ☐ | ☐ |
| Recibe una actualización sin reinstalar | ☐ | ☐ | ☐ | ☐ |

## iPhone

1. Abrir la URL en Safari e iniciar sesión.
2. Entrar a **Nosotros → Instalar aplicación** y usar **Compartir → Agregar a
   inicio**.
3. Entrar a **Nosotros → Importación de salud**, preparar Health Auto Export y
   abrir los dos enlaces en el mismo iPhone.
4. Ejecutar una exportación de uno o dos días y confirmar que la hora de la
   última recepción cambia.

## Android

1. Abrir la URL en Chrome e iniciar sesión.
2. Usar **Instalar aplicación** o **Agregar a pantalla principal**.
3. En **Importación de salud**, generar el token genérico y configurarlo como
   `Authorization: Bearer TOKEN` en el exportador compatible con Health Connect.
4. Enviar un día dos veces y confirmar que el total se reemplaza sin duplicarse.

## Puerta final

Mantener Flutter como respaldo hasta que las cuarenta y ocho casillas estén completas y
hayan transcurrido 48 horas sin fallos de sincronización. Si Google OAuth vuelve
a una URL no permitida, añadir exactamente la URL oficial a la lista de redirección
de Supabase Auth; el inicio con correo y contraseña no depende de esa redirección.
