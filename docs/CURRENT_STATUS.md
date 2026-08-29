# Estado actual de EnfermiCambio

Última organización: 29 de agosto de 2026.

Este archivo es la referencia corta para saber qué está guardado en el repositorio y qué trabajo sigue pendiente. Los roadmaps explican la dirección del producto; este documento registra el estado operativo actual.

## Qué está guardado

- La aplicación principal está en `pwa/`, con interfaz móvil instalable y navegación propia de app.
- El rediseño actual, Modo Casa, entrenamientos, comida y calorías, feed, misiones, logros y experiencia de notificaciones están versionados.
- Las animaciones e ilustraciones de ejercicios incluyen sus avisos de licencia y atribución.
- La integración de salud distingue Apple/iOS y Android, con función de ingesta, migraciones y documentación de Atajos.
- El cliente Flutter de la raíz se conserva como implementación heredada y respaldo; no se eliminó.
- Las herramientas de captura de tutoriales y preparación de Android se conservan en `tools/tutorials/`.

Importante: este checkpoint confirma que el código y los recursos están preservados. No significa que cada flujo haya sido probado en un teléfono físico.

## Pendiente de código y diseño

1. Seguir refinando la identidad visual de la PWA desde su estado actual en el navegador, con acabado más nativo y menos aspecto de página web.
2. Perfeccionar el feed, el sistema de pasos, las misiones, logros y progresión tipo pase de batalla.
3. Completar los detalles de comida, metas de peso y recuperación de datos históricos de calorías.
4. Revisar la experiencia completa de notificaciones una vez conectada la configuración externa.
5. Preparar la experiencia final de instalación y prueba en Android e iPhone.

## Pendiente externo u operativo

| Pendiente | Por qué no se resuelve solo con código |
| --- | --- |
| Aplicar las migraciones nuevas y desplegar `ingest_health` en Supabase | Modifica el backend remoto. |
| Configurar el enlace público del Atajo de iCloud en `VITE_IOS_HEALTH_SHORTCUT_URL` | Requiere publicar o elegir el Atajo definitivo. |
| Confirmar que el secreto VAPID privado corresponde a la clave pública configurada | El secreto vive fuera del repositorio. |
| Validar permisos y entrega real de notificaciones | Requiere navegador instalado o dispositivo físico. |
| Probar instalación y sincronización en iPhone y Android | Se dejó deliberadamente fuera de este checkpoint. |

## Mapa del repositorio

- `pwa/`: producto principal y diseño vigente.
- `supabase/`: backend canónico, funciones, migraciones y scripts operativos.
- `docs/`: decisiones, roadmaps, estado y guías de integración.
- `tools/`: automatización local y utilidades de tutoriales.
- `lib/`, `android/`, `ios/`: cliente Flutter heredado que se mantiene como respaldo.

## Archivos locales que no se suben

Dependencias (`node_modules`), builds (`dist`), cachés, grabaciones y secretos locales permanecen ignorados por Git. Ignorar estos archivos no los elimina del computador.

## Regla para continuar

Antes de comenzar un bloque grande, revisar este archivo. Al terminarlo, mover el punto correspondiente a “Qué está guardado” o actualizar su descripción. Así el estado pendiente no depende de recordar conversaciones anteriores.
