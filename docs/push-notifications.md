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

## Alternativas si el iPhone sigue usando firma gratuita

Estas alternativas son puentes externos: no crean otra versión de
EnfermiCambio ni sustituyen la campana interna. Cada usuario tendría que
instalar la aplicación puente y aceptar sus propias notificaciones.

### Opción recomendada: Pushover

Pushover recibe un `POST` en `https://api.pushover.net/1/messages.json` con un
token de aplicación, una clave de usuario o grupo y el mensaje. Es sencilla y
fiable para cuatro usuarios, pero el aviso llega con la identidad de Pushover,
no con la de EnfermiCambio. La referencia oficial es
<https://pushover.net/api>.

Para dejarlo listo mañana se necesitarían únicamente el token de la aplicación
y las claves de usuario/grupo. Nunca se deben guardar esas claves en Flutter,
GitHub ni en el APK/IPA; deben quedar como secretos del servidor.

### Opción recomendada: ntfy como puente externo

La app ya integra ntfy en la misma cola `notifications` → `push_outbox` →
`send_push`. Supabase crea un tópico aleatorio por usuario en
`ntfy_devices`; el tópico no se expone mediante una tabla pública y se entrega
solo al usuario autenticado mediante `get_or_create_ntfy_subscription()`.

La configuración actual usa el servicio gratuito alojado en `https://ntfy.sh`.
El servidor publica mediante un POST JSON y nunca guarda la credencial en la
APK/IPA. ntfy documenta este flujo HTTP y recomienda tratar el nombre del
tópico como una contraseña larga: <https://docs.ntfy.sh/publish/>.

#### Tutorial para cada usuario

1. Instalar **ntfy** desde la App Store o Google Play y permitir sus
   notificaciones.
2. Abrir EnfermiCambio y entrar en **NOSOTROS → Notificaciones → Configurar
   ntfy para iPhone**.
3. Pulsar **Abrir mi canal en ntfy**. Si iOS abre Safari, usar **Copiar
   tópico**, abrir ntfy, pulsar `+` y pegar el tópico.
4. Confirmar la suscripción y dejar activadas las notificaciones de ntfy en
   Ajustes del iPhone.

No hay que añadir una página a la pantalla de inicio, ni mantener abierta
EnfermiCambio. Cada usuario repite estos cuatro pasos una sola vez en su
propio teléfono. El aviso aparecerá con la identidad de ntfy; la campana y el
feed de EnfermiCambio siguen siendo la fuente de verdad.

La tabla ya está provisionada para los cuatro perfiles autorizados. Para
cambiar el proveedor en el futuro, `NTFY_BASE_URL` vive como secreto de la Edge
Function y no se guarda en Git.

#### Privacidad y servidor Ubuntu

El canal de ntfy es una capacidad: cualquiera que conozca el tópico puede
suscribirse. Por eso la app no lo muestra en el feed ni lo comparte, y los
mensajes no deben incluir información médica sensible. Si más adelante se
autoaloja ntfy en Ubuntu, iOS necesita que ese servidor configure
`upstream-base-url: https://ntfy.sh` para que lleguen los pushes instantáneos;
la documentación oficial explica esta limitación:
<https://docs.ntfy.sh/config/>.

### Opción navegador

Una PWA con Web Push puede servir como respaldo para Chrome y algunos flujos de
Safari, siempre con HTTPS y una suscripción por dispositivo. No es equivalente
a APNs para una IPA instalada: iOS puede limitar la entrega en segundo plano.
Por eso la dejaría como respaldo web, no como solución principal.

## Datos mínimos para la activación final

Si se habilita FCM/APNs directo, Freddy debe entregar mañana los valores de
Firebase del proyecto y configurar en Supabase el secreto
`FCM_SERVICE_ACCOUNT_JSON` (o sus tres variables equivalentes). Para APNs
directo también hacen falta `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY` y
`APNS_BUNDLE_ID`, además de una firma Apple con Push Notifications.

Si se escoge un puente externo, solo se pide la credencial de ese proveedor:

- Pushover: token de aplicación y claves de usuario/grupo.
- ntfy: URL HTTPS del servidor y tópico/credencial privada.

La aplicación debe seguir funcionando aunque esos secretos falten: se mantiene
la campana interna, Realtime y las notificaciones locales mientras el proceso
está abierto.
### Bark como puente en migraciÃ³n

La app tambiÃ©n integra Bark como alternativa nativa para iPhone. Bark se
configura desde `Nosotros â†’ Notificaciones â†’ Configurar Bark`: el usuario
pega la URL de prueba que copia desde Bark y la clave queda guardada en la
tabla privada `bark_devices`. Cuando Bark estÃ¡ activo para un usuario, el
servidor omite ntfy para evitar duplicados. ntfy no se elimina hasta validar
los cuatro telÃ©fonos. El procedimiento completo estÃ¡ en
[`docs/bark_bridge.md`](bark_bridge.md).

## Puente Web Push para iPhone

Cuando una IPA está instalada con una firma gratuita o con un perfil que no
incluye APNs, iOS puede no entregar el token nativo. La app mantiene el
registro nativo para Android/iOS firmados y, además, ofrece el puente web
privado en `web_push/`.

El puente se publica desde el servidor Ubuntu en:

`/enfermicambio/push/`

Cada usuario debe abrirlo en Safari, añadirlo a la pantalla de inicio, abrir
el icono instalado, iniciar sesión y pulsar **Activar avisos**. La suscripción
se guarda en `web_push_devices` con RLS por usuario. Las notificaciones pasan
por la misma cola `notifications` → `push_outbox` y `send_push`; el servidor
elige FCM/APNs o Web Push según los dispositivos activos.

La clave privada VAPID vive únicamente como secreto de Supabase Edge Functions.
El archivo `web_push/config.js` solo contiene la URL pública de Supabase, la
clave publicable y la clave pública VAPID, y está excluido de Git.

En iPhone la autorización de Web Push requiere una interacción visible y una
web app añadida a la pantalla de inicio. El dominio debe ser HTTPS; un quick
tunnel de Cloudflare sirve para pruebas, pero para uso permanente conviene un
túnel nombrado o dominio estable.
