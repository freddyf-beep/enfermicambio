# Configuración de Firebase de EnfermiCambio

Fecha de provisionamiento: 2026-08-14
Proyecto: `enfermicambio-98b5a`
Región de Firestore: `southamerica-west1`

## Provisionado

- Aplicación Android registrada con el paquete
  `com.enfermicambio.enfermicambio`.
- Aplicación iOS registrada con el bundle ID
  `com.enfermicambio.enfermicambio`.
- `android/app/google-services.json` y
  `ios/Runner/GoogleService-Info.plist` se descargan desde el proyecto.
- `lib/firebase_options.dart` fue generado con FlutterFire CLI.
- Authentication tiene habilitados correo/contraseña, Google y teléfono.
- Firestore Standard está creado y sus reglas/indexes están desplegados.
- Los cuatro perfiles autorizados están provisionados en Authentication y en
  la colección privada `members`.

## Uso en la app

La inicialización de Firebase es independiente de Supabase, por lo que FCM y
los servicios Firebase pueden funcionar mientras se conserva la sesión de
datos actual. `FirebaseAuthService` ya implementa:

- correo y contraseña;
- Google Sign-In;
- verificación por SMS;
- cierre de sesión;
- escritura separada de perfil público y privado en Firestore.

`FIREBASE_AUTH_ENABLED` permanece en `false` por defecto. Al cambiarlo a
`true`, la pantalla de inicio usa Firebase Auth y mantiene una sesión Supabase
de compatibilidad para las funciones que aún no migraron. No se debe activar
en producción hasta migrar `AuthGate` y los repositorios de feed, ranking,
salud, juegos, nutrición, entrenamientos, rutas y notificaciones a Firestore.

## Validación

Desde la raíz del proyecto:

```text
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

Las claves privadas de cuentas de servicio, tokens de Firebase y secretos de
Supabase no pertenecen al repositorio. Los archivos nativos de Firebase solo
contienen configuración pública de la aplicación; la protección real depende
de Authentication y de las reglas de Firestore.
