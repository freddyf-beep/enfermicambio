# Puente Bark

Bark es el puente nuevo para los iPhone instalados con una IPA que no puede
recibir APNs directamente. Es una app nativa de App Store: no crea un acceso
directo web en la pantalla de inicio y no exige cambiar la firma de
EnfermiCambio.

## Migración gradual

La migración se diseñó para no interrumpir los avisos:

1. El usuario instala Bark desde App Store.
2. En Bark copia la URL de prueba.
3. En EnfermiCambio entra en `Nosotros → Notificaciones → Configurar Bark` y
   pega esa URL.
4. El servidor guarda la clave únicamente para ese usuario.
5. Desde ese momento ese usuario recibe Bark y deja de recibir ntfy, evitando
   duplicados.
6. Los usuarios que todavía no configuraron Bark continúan con ntfy.

No se deben compartir las claves de Bark: funcionan como una contraseña de
entrega para el dispositivo.

## Servidor

La Edge Function `send_push` reutiliza la cola existente
`notifications → push_outbox`. Envía un `POST` JSON al endpoint Bark del
dispositivo y conserva la misma política de reintentos y desactivación de
claves inválidas. El endpoint público inicial es `https://api.day.app`.

La tabla privada `bark_devices` tiene RLS por propietario. La función interna
`list_bark_devices_for_dispatch` solo puede ser ejecutada por `service_role`,
para que las claves no aparezcan en el cliente ni en la API pública.

## Icono de los avisos

El servidor incluye el campo `icon` en cada envío Bark mediante el secreto
`BARK_NOTIFICATION_ICON`. Actualmente apunta al logo principal servido por
HTTPS desde el servidor Ubuntu. Esto cambia el icono del aviso recibido; no
cambia el icono de la aplicación Bark en la pantalla de inicio.

## Retiro posterior de ntfy

No eliminar ntfy todavía. Antes de retirarlo hay que confirmar en los cuatro
teléfonos:

- Bark instalado y notificaciones permitidas en Ajustes.
- Un aviso de prueba recibido con la pantalla bloqueada.
- Un mensaje del feed recibido desde otro usuario.
- Un aviso de ronda o logro recibido.
- Sin duplicados.

Después de esa validación se hará en una migración separada:

- desactivar la lectura de `ntfy_devices` en `send_push`;
- conservar los registros durante un periodo de respaldo;
- retirar la pantalla y el RPC ntfy en una actualización posterior;
- borrar los datos ntfy solo con confirmación explícita.

La documentación oficial de Bark describe el envío por `GET` o `POST`, el
formato `/:key` y el servidor autoalojable: <https://github.com/Finb/Bark>.
