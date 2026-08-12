# Puente de salud del iPhone

## Configuracion rapida desde EnfermiCambio

En una version actual de la app, cada usuario puede entrar a **Hoy -> Salud por
puente** (o **Nosotros -> Permisos y Salud**) y pulsar **Configurar puente de
salud**. La app genera dos enlaces privados para la cuenta que inicio sesion:

1. **Metricas de Salud**: pasos, calorias, distancia y ejercicio.
2. **Entrenamientos y rutas**: sesiones y recorridos GPS.

Pulsa **Preparar automatizaciones** y luego **Abrir** en cada tarjeta. Health Auto
Export se abrira con la configuracion REST API rellenada. Solo queda conceder los
permisos de Apple Salud, revisar la automatizacion y pulsar Actualizar. Si el enlace
no abre directamente, usa **Copiar** y pegalo en Safari.

Tambien puedes pulsar **Compartir instalador para este iPhone**. La app genera un
archivo HTML con dos botones privados; se puede guardar en Archivos o enviarlo a
otro dispositivo que use **la misma cuenta** y abrirlo desde Safari. Si lo va a
configurar Sammy, Sammy debe iniciar sesion en EnfermiCambio con su propia cuenta,
preparar su puente y compartir ese archivo desde esa sesion. No se debe enviar el
archivo generado por Freddy a Sammy, porque quedaria vinculado a la cuenta de Freddy.

El archivo compartido no debe cargarse en **Importar automatizacion** de Health Auto
Export: esa opcion usa el respaldo JSON interno que genera la propia aplicacion y
su estructura no esta publicada. El archivo de EnfermiCambio usa, en cambio, el
enlace oficial de instalacion documentado por HealthyApps. Cada enlace crea una
automatizacion REST API ya rellenada.

Preparar de nuevo rota el token de esa cuenta y deja inutilizado el enlace anterior.
Los enlaces contienen una credencial privada: no los publiques ni los envies a otra
persona. La app no guarda el token en texto; Supabase solo conserva su hash.

Este flujo no crea una app nueva. Usa la app existente **Health Auto Export** como puente:

```text
Apple Health → Health Auto Export → Supabase → Enfermicambio
```

La IPA de Enfermicambio no necesita tener el permiso nativo de HealthKit para recibir los
datos. El receptor del servidor escribe en `daily_activity`, `workouts` y
`workout_route_points`, que son las tablas que ya consulta el ranking y la pantalla de
entrenamientos.

## Valores del receptor

- URL REST: `https://bweynxdzovnbcjwgddar.supabase.co/functions/v1/health_auto_export`
- Método: `POST`
- Formato: `JSON`
- Encabezado: `Authorization: Bearer <TOKEN_PRIVADO>`

El token privado se entrega fuera del repositorio. No lo guardes en este archivo ni lo
compartas públicamente.

## Configuración en el iPhone

1. Instala o abre **Health Auto Export**.
2. En Apple Health, autoriza a Health Auto Export para leer:
   - pasos;
   - energía activa/calorías activas;
   - distancia caminando/corriendo;
   - minutos de ejercicio;
   - entrenamientos;
   - rutas de entrenamiento, si aparece como permiso separado.
3. En Health Auto Export crea una automatización **REST API**.
4. Configura la URL anterior y agrega el encabezado `Authorization` con el token entregado.
5. Usa JSON y Export Version 2.
   La automatización debe incluir el día anterior y el actual en cada ejecución;
   así el resumen diario se reconstruye completo y no queda solo con el último tramo.
6. En métricas activa `step_count`, `active_energy`, `walking_running_distance` y
   `apple_exercise_time`.
7. Elige agrupación por hora para que Enfermicambio pueda separar mañana, tarde y noche.
8. En Workouts activa **Include Route Data**. Activa también las métricas del entrenamiento
   si quieres guardar distancia, calorías y velocidad del entrenamiento.
9. Usa un rango de los últimos 1–2 días y pulsa **Run Now** para la primera prueba.

La respuesta correcta del receptor empieza con `200` y contiene `ok: true`. Después abre
Enfermicambio y actualiza el ranking. La tarjeta nativa de Apple Health puede seguir
mostrando permisos no concedidos en una IPA firmada gratuitamente; en este flujo esa tarjeta
no es la fuente de sincronización.

## Si no llegan datos

- Comprueba que la automatización esté activa y que el encabezado sea exactamente
  `Authorization` con el prefijo `Bearer `.
- Confirma que el formato sea JSON, no CSV.
- Ejecuta **Run Now** con el iPhone desbloqueado.
- Revisa que Salud tenga datos en el intervalo seleccionado.
- Si el token se expone, hay que revocarlo y generar otro; no lo reemplaces en el archivo de
  la app.
