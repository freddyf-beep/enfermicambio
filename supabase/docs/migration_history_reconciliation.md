# Reconciliación del historial de migraciones

## Estado encontrado el 27 de agosto de 2026

El proyecto remoto `bweynxdzovnbcjwgddar` contiene versiones históricas que no
coinciden uno a uno con los archivos consolidados de este repositorio. Por eso
`supabase db push --dry-run` se detiene antes de calcular cambios. La base remota
sigue operativa; el problema es el registro histórico, no la disponibilidad de
las tablas.

La migración PWA `20260827233000_pwa_training_and_generic_health_ingest.sql` se
aplicó de forma explícita después de revisar sus dependencias y solamente esa
versión fue marcada como aplicada. La función `ingest_health` también quedó
desplegada con verificación JWT desactivada porque usa un token de ingestión
propio, rotatorio y almacenado como hash.

## Regla de seguridad

No ejecutar en bloque las órdenes `supabase migration repair` sugeridas por el
CLI. Marcar como revertidas migraciones remotas antiguas sin comparar su SQL
podría hacer que el siguiente `db push` intente recrear o eliminar objetos que
ya contienen datos.

## Procedimiento de reconciliación

1. Crear una rama de mantenimiento y un respaldo remoto verificable.
2. Obtener el esquema remoto en un directorio temporal con la misma versión del
   CLI usada en CI.
3. Comparar objeto por objeto las migraciones remotas faltantes con las
   migraciones consolidadas locales: tablas, funciones, políticas RLS, triggers,
   vistas, grants y publicaciones Realtime.
4. Generar una migración de convergencia solo para diferencias reales. No usar
   el historial como sustituto de la comparación del esquema.
5. Ejecutar `supabase db push --dry-run` hasta que el plan sea vacío o contenga
   únicamente la migración de convergencia esperada.
6. Aplicar los cambios en una ventana de mantenimiento, ejecutar las consultas
   de humo y recién entonces corregir las versiones del historial.

## Verificaciones mínimas posteriores

- Los cuatro perfiles allowlisted pueden leer `profiles`, `daily_activity`,
  `posts`, `season_standings` y las tablas de gamificación.
- Un usuario solo puede escribir su actividad, comida, publicaciones,
  comentarios y reacciones autorizadas.
- `training_states` mantiene RLS y versionado optimista.
- `rotate_generic_health_ingest_token()` solo devuelve el token nuevo al dueño.
- `ingest_health` rechaza tokens ausentes o inválidos y conserva idempotencia de
  entrenamientos.
- `health_auto_export`, `health_auto_export_setup` e `ingest_health` continúan
  respondiendo después de la reconciliación.

Hasta completar este procedimiento, las migraciones nuevas deben revisarse y
aplicarse de forma individual, dejando constancia de la versión exacta. Nunca se
deben reparar versiones históricas en masa sobre producción.
