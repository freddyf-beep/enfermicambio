# Revisión inicial de seguridad de Firebase

Fecha: 2026-08-14
Proyecto: `enfermicambio-98b5a`

Esta revisión corresponde a la primera base de Firestore. Las reglas están
desplegadas en el proyecto y mantienen el acceso de datos en modo privado
mientras la app conserva Supabase como capa de compatibilidad.

## Ataques comprobados contra las reglas

- **Lectura anónima:** denegada por la regla general y por las colecciones
  privadas.
- **Escritura anónima:** denegada.
- **Lectura de `users_private` de otro usuario:** denegada; solo coincide el
  UID autenticado con el UID del documento.
- **Escritura de un perfil público con correo o teléfono:** denegada; esos
  campos no forman parte del conjunto permitido.
- **Cambio del UID del documento:** denegado en actualizaciones.
- **Campos arbitrarios en perfiles:** denegados mediante `hasOnly`.
- **Autoactivación en `members`:** denegada; los clientes no tienen permiso
  de escritura en esa colección.
- **Actualización con tipos incorrectos:** denegada para UID, textos y marcas
  de tiempo validadas por las reglas.

## Devil's advocate: límites conocidos

This is a prototype Security Rules review. The rules are designed to be secure
for the current private four-user profile surface, but they are not yet a
complete authorization model for the whole application. Before moving all
Supabase data to Firestore, each collection (feed, meals, workouts, routes,
notifications and device tokens) needs its own owner/group validation and
Firestore Emulator tests for allow/deny cases.

No se debe activar la migración completa de datos solo por tener estas reglas:
la app todavía usa repositorios Supabase para sus funciones existentes.
