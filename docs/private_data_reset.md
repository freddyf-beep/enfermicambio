# Reinicio seguro de datos de prueba

La base queda preparada para un reinicio controlado mediante la funcion
`public.reset_private_demo_data(text)`. El reinicio conserva las cuentas,
perfiles, configuracion, temporadas, misiones, logros, niveles del pase y los
tokens del puente de salud. Borra unicamente datos derivados o generados por
los usuarios: actividad, entrenamientos y rutas, peso, alimentos y registros
de comida, publicaciones, reacciones, comentarios, notificaciones y progreso
del juego.

Tambien elimina los objetos de fotos del bucket `meal-media`. Conserva los
buckets de avatares y multimedia de entrenamientos, y no revoca el token del
puente de salud.

La funcion no esta disponible para la app ni para usuarios autenticados: solo
puede ejecutarse con `service_role` y exige la confirmacion exacta
`RESET_ENFERMICAMBIO_TEST_DATA`.

No se ejecuta automaticamente durante una actualizacion, porque hacerlo
borraria el historial real de salud y peso. Para una prueba desde cero se
ejecuta explicitamente desde un entorno administrativo y despues se vuelve a
probar la automatizacion de Health Auto Export.
