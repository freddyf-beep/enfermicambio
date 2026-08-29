# Plano del Atajo “EnfermiCambio Salud”

Este documento es la receta de la plantilla pública. El Atajo compartido no contiene
credenciales: recibe la configuración privada desde EnfermiCambio en la primera ejecución y
la guarda en `iCloud Drive/Shortcuts/EnfermiCambio/config.json`.

Los nombres pueden cambiar ligeramente según la versión y el idioma de Atajos. Si la Mac está
en inglés, busca el equivalente indicado entre paréntesis.

## Resultado obligatorio

El Atajo debe:

1. aceptar la entrada del Atajo o, como respaldo, el portapapeles;
2. guardar el JSON de configuración cuando detecte `"shortcut":"EnfermiCambio Salud"`;
3. obtener los totales de Salud del día;
4. enviar un `POST` JSON al `endpoint` con `Authorization: Bearer TOKEN`;
5. considerar éxito únicamente una respuesta con `ok: true`.

## Bloque A: configuración privada

Agregar las acciones en este orden:

1. **Si** (`If`) `Entrada del Atajo` tiene algún valor.
2. **Establecer variable** (`Set Variable`) `ConfigText` = `Entrada del Atajo`.
3. **Si no** (`Otherwise`): **Obtener portapapeles** (`Get Clipboard`) y establecer
   `ConfigText` = `Portapapeles`.
4. Cerrar el primer **Si**.
5. **Si** `ConfigText` contiene el texto exacto `"shortcut":"EnfermiCambio Salud"`:
   - **Obtener diccionario de la entrada** (`Get Dictionary from Input`) usando `ConfigText`.
   - Establecer variable `Config` con ese diccionario.
   - **Guardar archivo** (`Save File`) usando el texto original `ConfigText` en
     `iCloud Drive/Shortcuts/EnfermiCambio/config.json` y activar **Sobrescribir si existe**.
6. **Si no**:
   - **Obtener archivo** (`Get File`) `Shortcuts/EnfermiCambio/config.json` desde iCloud Drive.
   - **Obtener texto de la entrada** (`Get Text from Input`).
   - **Obtener diccionario de la entrada** y establecer la variable `Config`.
7. Cerrar el segundo **Si**.
8. Usar dos acciones **Obtener valor del diccionario** (`Get Dictionary Value`):
   - clave `endpoint` de `Config` → variable `Endpoint`;
   - clave `token` de `Config` → variable `Token`.

No escribir un endpoint o token dentro de una acción. Si aparecen en el Atajo antes de la
instalación, la plantilla no es publicable.

## Bloque B: fecha local

1. **Fecha actual** (`Current Date`).
2. **Formatear fecha** (`Format Date`) con formato personalizado `yyyy-MM-dd`.
3. Establecer variable `ActivityDate`.

La salida debe verse, por ejemplo, `2026-08-29`, nunca `29/08/2026`.

## Bloque C: métricas de Apple Salud

Crear cuatro grupos iguales. Cada búsqueda debe filtrar muestras cuya fecha de inicio sea hoy.
Después de cada búsqueda, obtener el detalle **Valor** (`Value`), calcular la estadística
**Suma** (`Sum`) y guardar el resultado en la variable indicada.

| Tipo de muestra | Conversión final | Variable |
| --- | --- | --- |
| Conteo de pasos (`Step Count`) | redondear a entero | `DailySteps` |
| Distancia caminando + corriendo (`Walking + Running Distance`) | convertir a metros | `DistanceMeters` |
| Energía activa (`Active Energy Burned`) | convertir a kilocalorías/Calorías | `ActiveCalories` |
| Tiempo de ejercicio de Apple (`Apple Exercise Time`) | convertir a minutos | `ExerciseMinutes` |

Si una métrica no tiene muestras, debe producir `0`. Antes de cada grupo se puede establecer su
variable en cero y reemplazarla solamente cuando la búsqueda tenga resultados.

La Mac puede servir para construir estos bloques, pero la autorización y la prueba real deben
hacerse en el iPhone que contiene Apple Salud. Si una acción de Salud no aparece en la Mac, deja
marcado ese punto y agrégala desde el iPhone cuando el Atajo se sincronice por iCloud.

## Bloque D: solicitud al servidor

1. Agregar una acción **Texto** con `Bearer ` seguido de la variable `Token`; guardar su salida
   como `AuthorizationValue`.
2. Agregar **URL** con la variable `Endpoint`.
3. Agregar **Obtener contenido de URL** (`Get Contents of URL`) y abrir sus opciones:
   - método: `POST`;
   - cuerpo de la solicitud: `JSON`;
   - encabezado `Authorization`: variable `AuthorizationValue`;
   - encabezado `Content-Type`: `application/json`.
4. Agregar estos campos al cuerpo JSON:

| Clave | Tipo | Valor |
| --- | --- | --- |
| `activity_date` | texto | `ActivityDate` |
| `source_platform` | texto | `ios` |
| `source_app` | texto | `Apple Atajos` |
| `daily_steps` | número | `DailySteps` |
| `distance_meters` | número | `DistanceMeters` |
| `active_calories` | número | `ActiveCalories` |
| `exercise_minutes` | número | `ExerciseMinutes` |

`workouts` se puede omitir en esta primera versión; el receptor lo interpreta como una lista
vacía. La integración de entrenamientos detallados y rutas GPS se validará por separado.

## Bloque E: respuesta y mensajes

1. Obtener la clave `ok` del diccionario devuelto por **Obtener contenido de URL**.
2. Si `ok` es verdadero, durante las pruebas mostrar `Sincronización completada`.
3. Si no es verdadero, mostrar una alerta con la respuesta completa.
4. Cuando la prueba diaria sea estable, quitar la notificación de éxito y conservar solamente
   la alerta de error para no generar ruido.

## Prueba de aceptación en el iPhone

1. En EnfermiCambio, generar un token una sola vez.
2. Instalar la plantilla compartida.
3. Volver a EnfermiCambio y tocar **Configurar y probar Atajo**. La PWA vuelve a copiar el JSON y
   ejecuta el Atajo con el portapapeles como entrada.
4. Aceptar permisos de iCloud Drive, Salud y conexión a internet.
5. Confirmar en `Salud del teléfono` que aparece **Recepción confirmada** y una hora reciente.
6. Ejecutarlo una segunda vez. Los totales del mismo día deben reemplazarse, no duplicarse.

## Automatización diaria (solo en el iPhone)

1. Atajos → **Automatización** → `+` → **Hora del día**.
2. Elegir una hora posterior a la actividad habitual, por ejemplo `23:55`, frecuencia diaria.
3. Elegir **Ejecutar inmediatamente**.
4. Acción **Ejecutar atajo** → `EnfermiCambio Salud`.
5. Desactivar avisos de ejecución si iOS ofrece esa opción.

La automatización personal pertenece al iPhone; no se configura ni se comparte desde la Mac.
