# Arquitectura de Enfermicambio PWA

## Decisión

Enfermicambio se distribuye como PWA instalable. El cliente Flutter permanece como legado hasta terminar la aceptación en los cuatro teléfonos. Supabase es la única fuente autoritativa para identidad, datos sociales, salud agregada, competición y estado de entrenamiento sincronizado.

```text
iPhone ─ Health Auto Export ─┐
                             ├─ HTTPS + token privado ─ Supabase Edge Functions
Android ─ exportador webhook ┘                              │
                                                           ▼
PWA instalada ─ Supabase Auth ─ RLS ─ PostgreSQL / Realtime / Storage
      │
      └─ estado local-first de entrenamiento ─ training_states por usuario
```

## Superficies

### `pwa/`

React 19, Vite, React Router y Zustand. Contiene las pantallas sociales de Enfermicambio y el motor de entrenamiento adaptado de OpenGym. El modo sin variables de entorno es solamente una demostración local.

### `supabase/`

Backend canónico y único. Las migraciones son forward-only. Toda tabla privada usa RLS; los cálculos de competición y los eventos de sistema permanecen en funciones del servidor.

### Cliente Flutter de la raíz

Implementación heredada que conserva historial, pruebas y una vía de recuperación durante la transición. No debe recibir nuevas funciones salvo correcciones críticas necesarias para la migración.

## Salud

### iPhone

`health_auto_export_setup` crea dos enlaces privados para Health Auto Export. `health_auto_export` importa métricas, entrenamientos y rutas; excluye registros manuales, guarda recibos técnicos sin conservar el payload crudo y actualiza eventos de juego.

### Android

`rotate_generic_health_ingest_token()` entrega un token privado por usuario. `ingest_health` acepta un agregado diario y hasta 100 entrenamientos por solicitud. El token se almacena únicamente como SHA-256 y puede rotarse desde la PWA.

La PWA nunca solicita acceso directo a HealthKit ni Health Connect. Esa limitación es deliberada: elimina permisos nativos, firma de aplicaciones e instalaciones laterales.

## Entrenamiento

OpenGym aporta rutinas, sesiones, progresión, RIR/RPE, 1RM, recuperación, importadores y pruebas. El estado completo se guarda primero en el navegador y se replica en `training_states`, aislado por `user_id` y RLS.

## Multimedia y licencias

- Código adaptado de OpenGym: AGPL-3.0.
- Metadatos de ejercicios provenientes de ExerciseDB/hasaneyldrm: MIT según los avisos conservados.
- Diagramas musculares derivados de MuscleMap: MIT.
- Ilustraciones de Workout Guide: CC BY-SA 4.0, con atribución conservada.

Enfermicambio no distribuye ni descarga las imágenes de OpenGym cuya titularidad está en disputa. Las ilustraciones visibles proceden exclusivamente de Workout Guide.

## Despliegue

El frontend es estático. Las variables públicas de producción son `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` y `VITE_COMPETITION_TZ`. Nunca se expone `SUPABASE_SERVICE_ROLE_KEY` al navegador. HTTPS es obligatorio para instalación, service worker, notificaciones y almacenamiento seguro de sesión.
