# Sesión de 24 horas en Mac: Atajo de Apple Salud

La Mac no necesita Xcode ni una cuenta Apple Developer. Para este trabajo solo se requieren la
app **Atajos**, iCloud Drive y el mismo Apple Account del iPhone. La prueba de datos se realiza en
el iPhone porque allí están Apple Salud y sus permisos.

## Antes de recibir la Mac

- Tener a mano el iPhone, cargador, Apple Account y segundo factor.
- Confirmar que Apple Salud contiene pasos del día.
- Poder abrir EnfermiCambio e iniciar sesión en la cuenta de prueba.
- Mantener disponible este chat para enviar capturas si una acción cambia de nombre.
- No llevar claves de Supabase, Firebase ni archivos `.env` a la Mac.
- No generar el token definitivo hasta que la plantilla esté construida y sincronizada.

## Entregables que deben salir de la sesión

1. Atajo llamado exactamente `EnfermiCambio Salud`.
2. Enlace público con forma `https://www.icloud.com/shortcuts/ID`.
3. Respaldo exportado `EnfermiCambio Salud.shortcut` para **Cualquiera**.
4. Primera sincronización confirmada desde el iPhone.
5. Automatización diaria creada en el iPhone.
6. Mac cerrada sin sesiones, contraseñas, archivos ni dispositivo confiable asociado.

## Cronograma recomendado

### Hora 0–1: entrada segura

1. Crear o solicitar un usuario local temporal en la Mac.
2. Iniciar sesión en Apple Account y activar únicamente iCloud Drive y Atajos.
3. Abrir Atajos en Mac y en iPhone; confirmar que un atajo vacío aparece en ambos.
4. Si el repositorio está disponible, ejecutar:

```sh
bash tools/macos/shortcut-session-preflight.sh
```

El script solo comprueba macOS, la herramienta `shortcuts` y crea un reporte local sin tokens.

### Hora 1–4: construir por bloques

Seguir [`IOS_HEALTH_SHORTCUT_BLUEPRINT.md`](IOS_HEALTH_SHORTCUT_BLUEPRINT.md) y probar después de
cada bloque:

1. configuración privada y archivo `config.json`;
2. fecha `yyyy-MM-dd`;
3. pasos;
4. distancia;
5. calorías activas;
6. minutos de ejercicio;
7. solicitud HTTP y validación de la respuesta.

No pegar un token real en ninguna acción. El Atajo público debe recibirlo solamente como entrada.

### Hora 4–6: sincronizar y probar en iPhone

1. Esperar que `EnfermiCambio Salud` aparezca en el iPhone mediante iCloud.
2. Generar el token desde EnfermiCambio una sola vez.
3. Ejecutar el Atajo con esa configuración y aceptar todos los permisos.
4. Comprobar la recepción en la PWA.
5. Volver a ejecutar y confirmar que no duplica los totales del día.

### Hora 6–8: publicar la plantilla

1. Antes de compartir, revisar que no exista ningún token o endpoint personal escrito en acciones.
2. En Atajos de Mac: abrir el Atajo → compartir → **Copiar enlace de iCloud** → **Compartir**.
3. Enviar el enlace por este chat. Se añadirá a `VITE_IOS_HEALTH_SHORTCUT_URL`, se compilará la
   PWA y se desplegará desde el equipo habitual; no es necesario instalar herramientas web en la
   Mac arrendada.
   El comando ya preparado para hacerlo es:

```sh
cd pwa
npm run shortcut:configure -- "https://www.icloud.com/shortcuts/ID"
npm test
npm run build
```

4. Exportar además un archivo para **Cualquiera** y guardarlo fuera de la Mac arrendada.
5. Opcionalmente firmar una exportación no firmada con:

```sh
bash tools/macos/sign-shortcut-backup.sh "/ruta/EnfermiCambio Salud.shortcut"
```

### Hora 8–10: experiencia final

Probar el flujo completo como usuario nuevo:

1. abrir EnfermiCambio;
2. generar token e instalar Atajo;
3. aceptar `Obtener atajo`;
4. volver a la app y tocar **Configurar y probar Atajo**;
5. aceptar Salud;
6. ver **Recepción confirmada**.

Después, crear en el iPhone la automatización diaria de las `23:55` con **Ejecutar
inmediatamente**. Las horas restantes quedan como margen para corregir permisos, unidades o
nombres de acciones.

## Cierre seguro antes de devolver la Mac

1. Copiar fuera de la Mac el enlace de iCloud y el archivo `.shortcut`.
2. Vaciar Descargas, Escritorio y Papelera del usuario temporal.
3. Cerrar sesión en Safari, Codex, GitHub y cualquier gestor de contraseñas utilizado.
4. En Ajustes del Sistema → Apple Account, cerrar sesión completamente y no conservar copias
   locales de iCloud.
5. Desde `account.apple.com` o el iPhone, revisar **Dispositivos** y eliminar la Mac arrendada.
6. Eliminar el usuario local temporal o solicitar al arrendador que restaure la Mac.

Quitar la Mac de la lista sin cerrar primero la sesión no basta: si vuelve a conectarse mientras
la cuenta sigue iniciada, puede reaparecer.

## Criterio de finalización

La sesión termina solamente cuando el enlace público instala una plantilla sin credenciales, el
iPhone envía datos reales, la PWA confirma la recepción y la automatización diaria queda activa.
