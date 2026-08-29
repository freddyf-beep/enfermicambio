# Plantilla “EnfermiCambio Salud”

La construcción y liberación están detalladas en:

- [`IOS_HEALTH_SHORTCUT_BLUEPRINT.md`](IOS_HEALTH_SHORTCUT_BLUEPRINT.md): orden exacto de los bloques.
- [`MAC_24H_SHORTCUT_RUNBOOK.md`](MAC_24H_SHORTCUT_RUNBOOK.md): sesión de trabajo y cierre seguro en una Mac arrendada.

La PWA está preparada para abrir una plantilla compartida mediante
`VITE_IOS_HEALTH_SHORTCUT_URL`. Apple crea ese enlace al compartir el Atajo por iCloud.
La aplicación genera un token, copia este JSON y abre la plantilla:

```json
{"endpoint":"https://PROJECT.supabase.co/functions/v1/ingest_health","token":"…","source_platform":"ios","shortcut":"EnfermiCambio Salud"}
```

## Configuración inicial de la plantilla

1. Recibir texto como entrada; si no existe, obtener el portapapeles. La PWA puede ejecutar
   el Atajo con `shortcuts://run-shortcut?name=EnfermiCambio%20Salud&input=clipboard`.
2. Convertir el texto en diccionario y guardar `endpoint` y `token` en un archivo privado
   `EnfermiCambio/config.json` de iCloud Drive.
3. Mostrar “Conexión guardada”.

## Ejecución diaria

1. Leer `EnfermiCambio/config.json`.
2. Buscar muestras de Salud del día para pasos, distancia caminando/corriendo y energía activa.
3. Sumar cada grupo y crear un diccionario con:
   `activity_date`, `source_platform` (`ios`), `source_app` (`Apple Atajos`),
   `daily_steps`, `distance_meters`, `active_calories`, `exercise_minutes` y `workouts` (`[]`).
4. Usar “Obtener contenido de URL”: endpoint del archivo, método POST, cuerpo JSON y
   encabezado `Authorization` con `Bearer ` seguido del token.
5. Mostrar una notificación solo si la respuesta no contiene `ok: true`.

Al compartirla, elegir “Cualquiera” y copiar el enlace de iCloud. La plantilla nunca debe
contener un token real: el token llega después mediante el portapapeles. El enlace se asigna a
`VITE_IOS_HEALTH_SHORTCUT_URL`; desde entonces el flujo de la PWA queda reducido a generar,
aceptar y ejecutar una vez.
