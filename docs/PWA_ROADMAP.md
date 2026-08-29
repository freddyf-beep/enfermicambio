# Roadmap de Enfermicambio PWA

Actualizado: 2026-08-27

Leyenda: `[x]` terminado y verificado localmente · `[~]` implementado con validación pendiente · `[ ]` pendiente.

## Objetivo de lanzamiento

Los cuatro usuarios pueden abrir una URL HTTPS, instalar Enfermicambio desde el navegador, iniciar sesión una vez y recibir actualizaciones sin APK ni IPA. La actividad diaria se importa sin acceso nativo directo y todos los datos continúan protegidos por la allowlist y RLS.

## Fase 0 — Procedencia y base técnica

- [x] Auditar OpenGym y Workout Guide.
- [x] Confirmar que la PWA incorpora los 130 archivos fuente de OpenGym: 117 sin cambios y 13 adaptados (tree actual de `pwa/src`: 153 archivos contando la capa social de EnfermiCambio).
- [x] Confirmar el manifiesto completo de 302 ejercicios de Workout Guide.
- [x] Mantener Enfermicambio/OpenGym bajo AGPL-3.0 y las ilustraciones bajo CC BY-SA 4.0.
- [x] Excluir la multimedia de ExerciseDB/OpenGym con derechos no resueltos.
- [x] Importar la nueva aplicación en `pwa/` sin sobrescribir Flutter.

## Fase 1 — PWA instalable y actualizable

- [x] Manifest, iconos, orientación y modo standalone.
- [x] Service worker con caché de aplicación y Workout Guide.
- [x] Pantalla de instalación con instrucciones específicas para iOS y Android.
- [x] Acceso a instalación antes y después de iniciar sesión.
- [x] Navegación móvil con los cinco destinos originales de Flutter
  (`HOY | RANKING | REGISTRAR | JUEGO | NOSOTROS`).
- [~] Verificar instalación real, actualización y recuperación offline en los cuatro dispositivos.

## Fase 2 — Backend único y sincronización de entrenamiento

- [x] Mantener `supabase/` de la raíz como única fuente del backend.
- [x] Añadir `training_states` con RLS y propiedad por usuario.
- [x] Sincronizar el estado local-first de OpenGym con la sesión Supabase.
- [x] Evitar que la PWA dependa de la API Node/passkeys original de OpenGym.
- [x] Migración PWA aplicada al proyecto remoto; las cuatro identidades están
  provisionadas (Freddy, Pipe, Sami y Cruz con sus perfiles RLS).
- [~] Historial remoto divergente documentado en
  [`supabase/docs/migration_history_reconciliation.md`](../supabase/docs/migration_history_reconciliation.md);
  no usar `db push` en producción hasta reconciliarlo.
- [ ] Simular ediciones desde dos dispositivos del mismo usuario y documentar resolución de conflictos.

## Fase 3 — Salud sin aplicación nativa

- [x] Reutilizar el puente robusto de Health Auto Export para iPhone.
- [x] Mostrar estado de la última recepción y enlaces de automatización desde la PWA.
- [x] Añadir token genérico revocable y endpoint de webhook para Android.
- [x] Mantener idempotencia por usuario y fecha, límite de payload y exclusión de días contaminados por entradas manuales.
- [x] Recalcular logros y eventos después de la ingesta.
- [ ] Elegir y documentar el exportador Android definitivo con los teléfonos reales.
- [ ] Ejecutar matriz de aceptación: permisos, segundo plano, duplicados, zona horaria y cambio de día.

## Fase 4 — Producto social y entrenamiento

- [x] Dashboard diario, ranking, feed, registro, juego y perfiles conectados a Supabase.
- [x] Rutinas, entrenamiento guiado, calentamientos, superseries, cardio, RIR/RPE, progresión, 1RM, historial y recuperación.
- [x] Catálogo visual legal de Workout Guide.
- [x] Separar pantallas pesadas para reducir la descarga inicial.
- [x] Auditar y portar ranking por período/categoría desde la versión Flutter.
- [~] Feed enriquecido con fotos, comentarios y reacciones; las rutas se publican desde el cliente Flutter heredado.
- [~] Registro privado de comida con porción, macros y fotografía conectado a Supabase; falta validación con usuarios reales.
- [ ] Completar nutrición: búsqueda, código de barras y macros ampliados.
- [x] Misiones, logros, rachas y pase conectados al backend. El cierre diario
  fue corregido con
  [`20260827100001_fix_evaluate_missions_ambiguity.sql`](../supabase/migrations/20260827100001_fix_evaluate_missions_ambiguity.sql)
  (ON CONFLICT cualificado + normalización de NULL) y aplicado en producción:
  `evaluate_missions` responde 200 para las fechas recientes y `close_day`
  corre sin error. Las rachas se actualizarán cuando llegue actividad
  calificada de los cuatro usuarios.
- [x] La PWA repara el encoding heredado de logros, misiones y rachas al mostrar
  (`repairMojibake`) y la pantalla de juego muestra objetivo, recompensa y estado.
- [x] Service worker v5: network-first para el HTML y limpieza de cachés
  anteriores, de modo que cada actualización despliega el nuevo index sin
  exigir reinstalar la app (verificado: el flujo Entrenar/Plan/Workout carga
  tras un deploy con hashes nuevos).
- [x] Centro de notificaciones y registro privado de peso/meta conectados con RLS.

## Fase 5 — Confiabilidad, seguridad y rendimiento

- [x] 546 pruebas de frontend aprobadas.
- [x] Build de producción aprobado.
- [x] `npm audit` sin vulnerabilidades reportadas.
- [x] RLS para estado de entrenamiento y tokens privados fuera del alcance del navegador.
- [x] Reducir el bundle inicial y mantener entrenamiento, idiomas e instrucciones bajo carga diferida.
- [x] Separar React y Supabase en chunks con hash estable: el index pasó de
  ~1.35 MB (266 KB gzip) a ~952 KB (142 KB gzip) en el build de producción.
- [x] Añadir pruebas del instalador, puente de salud y sincronización en modo autenticado.
- [ ] Ejecutar auditoría RLS completa con cuatro identidades reales.
- [ ] Validar restauración de respaldo y comportamiento sin conexión.
- [ ] Validar WCAG, movimiento reducido y tamaños táctiles en dispositivos reales.

## Fase 6 — Publicación y adopción

- [x] Configurar URL HTTPS estable y variables públicas de producción.
- [x] Aplicar la migración PWA y desplegar `ingest_health`.
- [x] Revalidar el despliegue del conjunto completo de Edge Functions:
  `close_round`, `close_season`, `close_day`, `food_lookup`, `generate_events`,
  `health_auto_export`, `ingest_health` y `send_push` responden en producción
  (200/400/401 según su política de auth).
- [x] Publicar la PWA y comprobar manifest/service worker desde producción.
- [ ] Instalarla en los cuatro teléfonos.
- [ ] Configurar el puente de salud de cada usuario.
- [ ] Observar 48 horas de sincronización y corregir bloqueos de adopción.
- [ ] Congelar Flutter como `legacy` después de aprobar la matriz de cuatro dispositivos.

## Puerta de lanzamiento

No se declara lista para uso diario hasta que los cuatro usuarios completen: instalación, inicio de sesión, importación automática, actualización silenciosa, entrenamiento, recuperación offline y cierre de sesión. Ningún usuario debe necesitar descargar un binario ni volver a conceder permisos por una actualización ordinaria.
