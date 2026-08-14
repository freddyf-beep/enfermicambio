# Configuración de mapas nativos

La app usa el mapa nativo de cada plataforma:

- iPhone: MapKit mediante `apple_maps_flutter`; no necesita una API key de
  Google.
- Android: Google Maps mediante `google_maps_flutter`.

## Android local

1. En Google Cloud crea o selecciona un proyecto.
2. Habilita **Maps SDK for Android**.
3. Crea una API key y restringe la aplicación Android al paquete
   `com.enfermicambio.enfermicambio`.
4. En `android/local.properties` agrega una línea local (ese archivo no se
   versiona):

   ```properties
   googleMapsApiKey=PEGA_AQUI_LA_KEY
   ```

También se puede usar la variable `GOOGLE_MAPS_API_KEY` al ejecutar Gradle o
la opción `-PgoogleMapsApiKey=...` en CI. Nunca pongas la key en GitHub como
texto dentro del repositorio.

Sin key, la app sigue compilando, pero el mapa de Android mostrará el error del
proveedor hasta que se configure la key. El registro GPS y la ruta guardada no
se pierden.

## Android en GitHub Actions

Configura el secreto `GOOGLE_MAPS_API_KEY` y pásalo al build como propiedad de
Gradle. La key debe mantenerse restringida al paquete de la aplicación.

## iPhone

MapKit funciona con la firma disponible. Para dibujar una ruta en segundo
plano se siguen necesitando los permisos de ubicación del proyecto y la
autorización del usuario. La vista nativa se actualiza sin recrear el mapa en
cada punto GPS.

El plugin de Apple no ofrece el mismo JSON de estilo oscuro que Google Maps en
esta versión; por eso iOS usa el estilo nativo de MapKit y Android aplica el
estilo oscuro JSON. Si una versión futura del plugin de Apple deja de compilar,
el fallback documentado es usar Google Maps en iOS con su API key.
