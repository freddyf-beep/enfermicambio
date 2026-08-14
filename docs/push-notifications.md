# Notificaciones del sistema

La tabla `notifications` sigue siendo la fuente de verdad. Cada notificación
nueva entra en `push_outbox`; el trigger de Postgres llama a la Edge Function
`send_push` y un cron de reintento procesa las entregas pendientes.

## Cliente

La app registra el token de Firebase del usuario autenticado mediante el RPC
`register_push_device`. Si faltan las variables Firebase, la app continúa con
la campana interna y el canal local de Realtime, pero no puede mostrar un push
cuando el proceso está terminado.

Variables públicas del cliente que se pasan con `--dart-define`:

```text
FIREBASE_API_KEY
FIREBASE_APP_ID_ANDROID
FIREBASE_APP_ID_IOS
FIREBASE_MESSAGING_SENDER_ID
FIREBASE_PROJECT_ID
FIREBASE_STORAGE_BUCKET
FIREBASE_IOS_BUNDLE_ID=com.enfermicambio.enfermicambio
```

## Servidor

En Supabase deben configurarse como secretos de Edge Functions, nunca en Git:

```text
FCM_SERVICE_ACCOUNT_JSON
```

o las tres variables equivalentes `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL` y
`FCM_PRIVATE_KEY`. La opción JSON es preferible porque conserva correctamente
los saltos de línea de la clave privada.

La función también admite envío directo a APNs con `APNS_KEY_ID`,
`APNS_TEAM_ID`, `APNS_PRIVATE_KEY`, `APNS_BUNDLE_ID` y opcionalmente
`APNS_USE_SANDBOX=true`. En la app se usa FCM como proveedor para Android y
iPhone; Firebase reenvía el mensaje de iPhone a APNs.

## iPhone

Para un push real de iPhone, el App ID debe tener habilitado Push Notifications,
la app debe incluir el entitlement `aps-environment` y la firma debe ser
compatible con esa capacidad. `ios/Runner/Push.entitlements` contiene el
entitlement separado para builds pagados; no se mezcla automáticamente en la
IPA gratuita para no romper el sideload actual.

Con Apple Developer gratuito, la IPA de siete días puede conservar las
notificaciones internas y locales, pero no se debe prometer APNs remoto. Si no
se habilita una firma de Apple con Push Notifications, la alternativa es un
puente como Pushover o ntfy, instalado aparte en cada iPhone.

## Prueba

1. Configurar el proyecto Firebase para el paquete Android y el bundle iOS.
2. Cargar las variables públicas en los builds.
3. Configurar `FCM_SERVICE_ACCOUNT_JSON` en los secretos de Supabase.
4. Instalar la nueva APK/IPA y aceptar Notificaciones.
5. Confirmar que la tabla `push_devices` tiene un token para cada usuario.
6. Crear una publicación con otro usuario y cerrar la app receptora.

La notificación seguirá apareciendo en la campana aunque el proveedor push esté
sin configurar; el push del sistema requiere los pasos anteriores.
