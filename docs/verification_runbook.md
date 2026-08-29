# Manual de verificacion de EnfermiCambio

Este manual valida el flujo completo sin borrar los datos actuales. La limpieza de
datos de prueba tiene una confirmacion separada en `docs/private_data_reset.md`.

## 1. Construir una version conectada

La build debe recibir la URL y la clave publica de Supabase mediante `--dart-define`.
No pegues una clave `service_role` en la aplicacion.

```powershell
$envValues = @{}
Get-Content .env | ForEach-Object {
  if ($_ -match '^\s*([^#=]+)=(.*)$') {
    $envValues[$matches[1].Trim()] = $matches[2].Trim().Trim('"')
  }
}

& C:\src\flutter\bin\flutter.bat build apk --release `
  --dart-define="SUPABASE_URL=$($envValues['SUPABASE_URL'])" `
  --dart-define="SUPABASE_ANON_KEY=$($envValues['SUPABASE_ANON_KEY'])" `
  --dart-define="COMPETITION_TZ=$($envValues['COMPETITION_TZ'])"
```

En PowerShell, `$($envValues['NOMBRE'])` es importante: evita que se pase la
representación textual completa de la tabla (`System.Collections.Hashtable`) en
vez del valor de la variable.

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`. La firma actual es
solo para pruebas privadas; no es una firma de Play Store.

## 2. Salud en iPhone: puente Health Auto Export

El flujo de iPhone es:

`Apple Salud -> Health Auto Export -> Supabase -> EnfermiCambio`

La forma recomendada para un usuario nuevo es entrar en **Hoy -> Salud por puente**
con su propia cuenta y usar **Configurar puente de salud**. La app prepara dos
enlaces privados: uno para metricas y otro para entrenamientos/rutas. Al abrir cada
enlace, Health Auto Export crea la automatizacion REST API sin tener que copiar la
URL ni el token manualmente.

En Health Auto Export crea o edita una sola automatizacion **REST API**:

- URL: `https://bweynxdzovnbcjwgddar.supabase.co/functions/v1/health_auto_export`
- Metodo: `POST`
- Formato: `JSON`, version `v2`
- Encabezado: `Authorization` con `Bearer ` y el token privado entregado para el puente
- Metricas: pasos, calorias activas, distancia caminando/corriendo y minutos de ejercicio
- Agrupacion: por hora
- Workouts: activados; incluye rutas si Salud ofrece ese permiso

Para la primera prueba usa rango de 1 o 2 dias y pulsa **Run Now** con el iPhone
desbloqueado. Luego abre EnfermiCambio y pulsa actualizar en la pantalla de hoy.
El resultado esperado es una fila diaria actualizada, sin duplicar pasos ni calorias.

Si no llega nada, revisa primero que el encabezado sea exactamente `Authorization`, que
el prefijo sea `Bearer `, que la automatizacion este habilitada y que existan datos en
Apple Salud para el rango elegido. No uses CSV para este receptor.

## 3. Salud en Android: Health Connect

1. Instala o abre **Health Connect** y termina su configuracion.
2. En permisos de la aplicacion concede lectura de pasos, calorias activas, distancia,
   ejercicio y ruta de ejercicio cuando aparezca.
3. Abre EnfermiCambio, entra a **Nosotros -> Salud** y solicita los permisos.
4. Regresa a **Hoy** y pulsa actualizar.

La primera validacion debe hacerse con un dato de hoy generado por el telefono o reloj.
Para una ruta, inicia un entrenamiento que registre GPS y concede el permiso de ruta.
La app guarda la sesion en **Entrenamientos** y sus puntos en **Rutas**; al abrir una
sesion desde **Nosotros** debe aparecer el mapa cuando existan puntos GPS. El ranking
debe mostrar el total del dia; varias actualizaciones del mismo dia deben actualizar la
misma fila.

## 4. Lista funcional de la aplicacion

Prueba con una cuenta autorizada y registra el resultado:

- Inicio de sesion: Freddy y Felipe; las cuentas aun no creadas deben mostrar estado
  claro y no fallar silenciosamente.
- Hoy: resumen, pasos, calorias, distancia, minutos, feed y actualizar.
- Feed: texto, foto de comida, reaccion, comentario y carga de imagen privada.
- Registrar: buscar alimento, escanear codigo de barras, crear alimento personalizado,
  elegir porciones y guardar la comida.
- Peso: guardar peso y objetivo con punto o coma decimal; repetir el mismo dia actualiza.
- Juegos: temporada activa, kilometros, puntos e historial.
- Ranking: diario, semanal y sincronizacion reciente.
- Notificaciones: abrir el centro, marcar como leida y recibir una notificacion local
  cuando llega un evento realtime mientras la aplicacion esta activa.
- Offline: crear una reaccion sin red, recuperar la conexion y confirmar que la cola se
  reintenta una sola vez.

## 5. Retencion diaria

Los datos diarios de salud usan `upsert` por usuario y fecha. Por eso una sincronizacion
repetida no crea filas infinitas ni suma dos veces el mismo periodo. El cierre automatico
conserva el resumen final del dia y evita repetir las publicaciones de cierre. El historial
de dias anteriores se conserva porque alimenta ranking, temporada y estadisticas.

Para borrar datos de prueba, detener la aplicacion y seguir exactamente la confirmacion
de `docs/private_data_reset.md`; no se ejecuta durante una prueba normal.

## 6. Evidencia minima antes de darlo por terminado

- `flutter test --no-pub` sin fallos.
- `flutter analyze --no-pub` sin errores de compilacion.
- APK release generado con los tres `dart-define`.
- Una prueba real de HAE en iPhone y otra de Health Connect en Android.
- Una prueba de feed, alimento, codigo de barras, peso, juego y notificaciones.
- Confirmar que los cuatro perfiles existan antes de declarar valida la competencia de
  cuatro usuarios. No se crean cuentas automaticamente desde la aplicacion.
