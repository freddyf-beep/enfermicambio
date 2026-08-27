# Enfermicambio 2.0

PWA privada para cuatro amigos que combina actividad automática, nutrición, competencia social y entrenamiento de fuerza. Se instala desde el navegador y no necesita App Store, Play Store, APK ni IPA.

## Qué incluye

- Dashboard diario, ranking, feed, nutrición, temporadas, perfiles y notificaciones respaldados por Supabase.
- Importación automática desde exportadores de Apple Health y Health Connect mediante un endpoint con token revocable.
- Rutinas, sesiones, series, peso, cardio, superseries, calentamientos, RIR/RPE, progresión, 1RM e historial adaptados de [OpenGym](https://gitlab.com/DuarteSantos8/opengym).
- Catálogo visual basado en [Workout Guide](https://github.com/bryllim/workout-guide), con recursos versionados y atribución CC BY-SA 4.0.
- Funcionamiento local y offline. Con una sesión Supabase, el estado de entrenamiento se sincroniza por usuario.

## Desarrollo

Requiere Node.js 24.

```bash
cp .env.example .env
npm install
npm run dev
```

```env
VITE_SUPABASE_URL=https://PROJECT.supabase.co
VITE_SUPABASE_ANON_KEY=PUBLIC_ANON_KEY
VITE_COMPETITION_TZ=America/Santiago
```

Sin variables, la interfaz abre un modo demostración local sin conectarse a datos reales.

## Supabase

```bash
supabase db push
supabase functions deploy ingest_health --no-verify-jwt
```

`--no-verify-jwt` es intencional: el endpoint verifica su propio bearer token aleatorio, almacenado solamente como SHA-256. Cada usuario lo genera desde **Nosotros → Importación automática de salud**.

## Compilar y alojar

```bash
npm test
npm run build
```

`dist/` es estático y puede publicarse en Cloudflare Pages, Netlify, Vercel, GitHub Pages o cualquier hosting web. El router usa hashes y no requiere reglas de reescritura.

## Seguridad

- No existe registro público; Supabase conserva la allowlist de cuatro perfiles y RLS.
- Nunca pongas `SUPABASE_SERVICE_ROLE_KEY` en variables `VITE_*`.
- Los tokens de salud se muestran una sola vez y pueden rotarse.
- Las antiguas credenciales de acceso rápido fueron eliminadas. Las cuentas utilizadas por la versión Flutter deben cambiar de contraseña antes del despliegue.

## Procedencia y licencias

Enfermicambio se distribuye bajo **AGPL-3.0-or-later**. El motor de entrenamiento contiene trabajo adaptado de OpenGym y conserva sus avisos en [NOTICE-OPENGYM.md](NOTICE-OPENGYM.md). Las ilustraciones de Workout Guide están separadas bajo **CC BY-SA 4.0** en `public/workout-guide/`.

El cliente Flutter anterior permanece en el historial de Git y su documentación está archivada en `docs/legacy-flutter/`.
