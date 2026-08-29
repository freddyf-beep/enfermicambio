# Puentes de salud gratuitos

Verificado el 29 de agosto de 2026. La PWA usa una sola pantalla, **Salud del teléfono**, con una pestaña por plataforma. Cada teléfono genera un token independiente contra el mismo endpoint privado:

`https://bweynxdzovnbcjwgddar.supabase.co/functions/v1/ingest_health`

## iPhone — Conduit Health Sync

- App Store Chile: <https://apps.apple.com/cl/app/conduit-health-sync/id6786544769>
- Código fuente: <https://github.com/noebrito/conduit>
- Contrato exacto: <https://github.com/noebrito/conduit/blob/main/proto/conduit/v1/sync.proto>
- Requisitos: iOS 17 o superior.

La ficha chilena informa precio `0 CLP` y no ofrece prueba. La ficha no declara compras internas y el código público que el autor identifica como espejo de la aplicación publicada no contiene StoreKit ni un sistema de pagos. El código usa licencia Apache-2.0.

Configuración:

1. Instalar Conduit desde App Store.
2. En EnfermiCambio → Salud del teléfono → iPhone, generar y verificar el token.
3. Pegar el endpoint en `Webhook URL` y el token puro en `Bearer Token`.
4. Activar Steps, Walking + Running Distance, Active Energy, Exercise Time y Workouts.
5. Tocar `Test Connection`; el resultado esperado es HTTP 200.

Conduit envía ProtoJSON incremental con UUID estables de HealthKit. El receptor guarda únicamente métricas normalizadas y usa esos UUID para que los reintentos no dupliquen datos. Atajos ya no forma parte del flujo principal.

## Android — Life Dashboard Companion 1.8.0

- Repositorio: <https://github.com/owen282000/life-dashboard-companion-app>
- Release fijado: <https://github.com/owen282000/life-dashboard-companion-app/releases/tag/1.8.0>
- APK: <https://github.com/owen282000/life-dashboard-companion-app/releases/download/1.8.0/app-release.apk>
- SHA-256: `35a61fa2eec07f13743d8c36e1e08382192eb8e5d1c7d87890a0ba44aa8d0eab`

Es software MIT distribuido gratuitamente desde GitHub Releases. No requiere cuenta, nube del desarrollador, suscripción ni prueba. Health Connect funciona de forma práctica desde Android 9; en Android 14 está integrado en Ajustes.

Configuración:

1. Instalar o activar Health Connect y conceder solo los permisos deseados.
2. Instalar el APK oficial 1.8.0.
3. En EnfermiCambio → Salud del teléfono → Android, generar y verificar el token.
4. Configurar el endpoint y el header `Authorization` con valor `Bearer TOKEN`.
5. Activar Steps, Distance, Active Calories, Exercise y `Daily totals`.
6. Usar `Preview Data` y `Sync Now`; luego elegir un intervalo de al menos 15 minutos.

`Daily totals` usa la API Aggregate de Health Connect para evitar duplicar datos superpuestos de teléfono y reloj. El receptor también entiende los arrays con UUID para reintentos y backfill.

## Estado del backend

- Las RPC `rotate_platform_health_ingest_token` y `get_platform_health_ingest_status` están aplicadas en producción.
- `ingest_health` versión 3 está desplegada con `verify_jwt=false` porque valida un Bearer hex propio, no un JWT de Supabase.
- La migración de muestras deduplicadas está aplicada y tiene RLS sin acceso de clientes.
- Se comprobó en producción un token temporal de Android y un envelope vacío de Conduit: ambos devolvieron HTTP 200; los tokens temporales fueron eliminados al terminar.
- Falta la validación física con datos reales en los teléfonos de las cuatro personas.
