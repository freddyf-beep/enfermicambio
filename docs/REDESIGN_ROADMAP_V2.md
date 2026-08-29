# EnfermiCambio 3.0 — roadmap de rediseño móvil

Fecha de inicio: 27 de agosto de 2026  
Estado: implementado y desplegado; validación física posdespliegue pendiente

## Objetivo

Convertir la PWA en una aplicación de salud que se sienta coherente, personal y
natural en iPhone y Android. El rediseño debe conservar los datos y funciones ya
operativos, eliminar la apariencia de dos productos pegados y reducir al mínimo
los pasos necesarios para entrenar, registrar una comida, sacar una foto,
sincronizar salud y participar en el grupo.

## Evidencia de partida

- La PWA ya es instalable, usa Supabase y mantiene las cinco áreas históricas:
  Hoy, Ranking, Registrar, Juego y Nosotros.
- El módulo de entrenamiento aporta rutinas, sesión activa, descanso, progreso,
  historial y un catálogo de 1.324 ejercicios con animaciones.
- La auditoría móvil a 393 × 852 px confirmó que las funciones existen, pero hay
  dos sistemas visuales simultáneos: el shell social de EnfermiCambio y varias
  pantallas heredadas de OpenGym.
- Hoy muestra demasiada actividad histórica antes de acciones frecuentes.
- Registrar mezcla publicación social y nutrición en un formulario largo.
- El catálogo usa nombres mezclados en español e inglés y demasiados filtros a
  la vista al mismo tiempo.
- Hay publicaciones antiguas con texto mal codificado (`dÃ­a`, `sofÃ¡`).
- La instalación actual explica el concepto, pero aún no acompaña paso a paso ni
  abre las tiendas de las aplicaciones puente.

## Principios de producto y diseño

1. **Primero la acción del día.** Entrenar, comida, foto y sincronización deben
   estar a uno o dos toques desde Hoy.
2. **Una sola aplicación.** Social, salud, nutrición, juego y entrenamiento
   compartirán navegación, tipografía, iconografía, espaciado y estados.
3. **Móvil de verdad.** Áreas táctiles de al menos 44 px, safe areas, cabeceras
   compactas, hojas inferiores, teclado y cámara pensados para una mano.
4. **Identidad propia.** Sin mosaicos genéricos, gradientes decorativos, emojis
   como iconos ni tarjetas para cada párrafo. La información manda sobre el
   adorno.
5. **Progreso comprensible.** Mostrar una métrica principal, contexto y una
   acción; evitar paneles llenos de números sin explicación.
6. **Privacidad visible.** Distinguir con claridad qué es privado, qué se
   comparte con el grupo y qué se envía al puente de salud.
7. **Inspiración, no copia.** Adoptar patrones probados sin reproducir marcas,
   ilustraciones ni pantallas de otras aplicaciones.

## Referencias verificadas

- Apple Human Interface Guidelines: jerarquía, armonía, consistencia,
  accesibilidad y controles familiares.
  <https://developer.apple.com/design/human-interface-guidelines>
- Apple Health: resumen personal, tendencias y privacidad como información de
  primer nivel. <https://www.apple.com/health/>
- Hevy: registro rápido de series, rutinas reutilizables, ejercicio anterior,
  temporizador, progresión y comunidad.
  <https://www.hevyapp.com/features/>
- MacroFactor: captura de comida por foto con resultado editable, y accesos
  rápidos a los flujos de registro.
  <https://help.macrofactorapp.com/en/articles/258-ai-food-logging>
- Guía oficial PWA: Android puede presentar un diálogo de instalación; iOS no
  ofrece ese prompt y requiere Compartir → Agregar a pantalla de inicio.
  <https://web.dev/learn/pwa/installation>
- Conduit Health Sync: aplicación iOS gratuita y de código abierto que envía
  HealthKit a un webhook propio. <https://github.com/noebrito/conduit>
- Life Dashboard Companion: aplicación Android MIT con APK gratuito, Health
  Connect Aggregate, cola y reintentos. <https://github.com/owen282000/life-dashboard-companion-app>

## Sistema visual propuesto: “Pulso privado”

- Base oscura carbón y una base clara hueso, ambas neutras y sin azulados.
- Verde vivo reservado para progreso y acción principal; coral para rachas y
  advertencias suaves; violeta para competencia y logros.
- Tipografía del sistema (`-apple-system`, `BlinkMacSystemFont`, `Inter` cuando
  exista localmente) con pesos 400/600/700 y números tabulares.
- Iconos lineales propios y consistentes; no usar emojis como controles.
- Superficies agrupadas y separadores finos; tarjetas solo para contenido que
  realmente forma una unidad.
- Movimiento breve (160–240 ms), reducido o eliminado con
  `prefers-reduced-motion`.

## Arquitectura de información

### Hoy

- Saludo y estado de sincronización.
- Progreso diario principal con pasos y meta; calorías, distancia y minutos como
  contexto secundario.
- Acciones rápidas: Entrenar, Comida, Foto y Sincronizar.
- Rutina de hoy o sesión activa.
- Clasificación compacta de cuatro personas.
- Dos novedades recientes y acceso explícito al resto de la actividad.

### Ranking

- Ganador y diferencia real con el siguiente puesto.
- Selector de métrica y periodo con controles compactos.
- Podio, tabla completa y evolución sin duplicar números.

### Registrar

- Selector inicial de tres flujos: Comida, Publicación y Actividad.
- Comida: tomar foto, elegir de galería, buscar código/nombre y confirmar datos
  editables antes de guardar.
- Publicación: texto/foto con indicación inequívoca de que se comparte al grupo.
- Actividad: accesos directos a peso, salud y entrenamiento.

### Juego

- Resumen de temporada, misión prioritaria y racha vigente.
- Logros agrupados por cercanía a completar, no una cuadrícula interminable.
- Explicar por qué se obtuvo cada punto y cuándo se actualizó.

### Nosotros

- Perfil propio primero; equipo como sección social.
- Centro de salud e instalación como una configuración guiada.
- Apariencia, icono, notificaciones, peso y privacidad agrupados por tema.

### Entrenamiento

- Cabecera y navegación comunes a EnfermiCambio.
- Un toque para rutina de hoy o entrenamiento libre.
- Biblioteca con Recientes/Favoritos al inicio; búsqueda fija; filtros de músculo,
  equipo y nivel dentro de una hoja; nombres principales en español.
- Ficha de ejercicio con animación, instrucciones, músculos, equipo, historial y
  acción “Añadir a rutina”.
- Sesión con datos anteriores visibles, sets editables con pulgar, temporizador
  persistente y finalización segura.

## Instalación y puentes de salud

1. Detectar plataforma, navegador y si la PWA ya está instalada.
2. En Android/Chromium, mostrar el prompt nativo al tocar “Instalar”.
3. En iPhone/iPad, mostrar tutorial visual Safari → Compartir → Agregar a
   pantalla de inicio. iOS no permite automatizar esos dos toques desde una web.
4. Después de instalar, ofrecer un asistente separado para el puente de salud:
   - iPhone: instalar Conduit desde App Store y configurar endpoint/token.
   - Android: abrir Health Connect o sus ajustes, instalar Life Dashboard
     Companion 1.8.0 y configurar endpoint/token más `Daily totals`.
5. Mostrar estado de cada etapa: PWA instalada, app puente disponible,
   automatización creada y última recepción confirmada.
6. Nunca colocar tokens privados en enlaces públicos, documentación o analítica.

## Iconos intercambiables: alcance real de una PWA

El icono interno y la apariencia pueden cambiar al instante. El icono ya
instalado en la pantalla de inicio no puede sustituirse mediante la API nativa
de iOS (`setAlternateIconName`) porque esa API solo existe para aplicaciones
nativas. La PWA ofrecerá variantes antes de instalar y un flujo claro para
reinstalar con otro icono en iPhone; Android WebAPK puede actualizar metadatos,
pero no se prometerá un cambio inmediato en todos los launchers.

Variantes previstas:

- Pulso — principal, neutral.
- Equipo — violeta, competencia.
- Fuego — coral, rachas.
- Noche — monocromo oscuro.

## Fases de ejecución

### Fase A — inventario y cimientos

- [x] Auditar Hoy, Registrar, Entrenar, Ejercicios e Instalación a tamaño iPhone.
- [x] Investigar referencias oficiales y restricciones PWA actuales.
- [x] Crear tokens, componentes y shell 3.0 sin modificar contratos de datos.
- [x] Añadir pruebas visuales/semánticas básicas de navegación y estados.

### Fase B — núcleo diario

- [x] Rediseñar Hoy, barra inferior y cabeceras.
- [x] Reordenar ranking compacto y actividad reciente.
- [x] Corregir mojibake histórico al presentar publicaciones.
- [x] Rediseñar Registrar como flujos independientes.
- [x] Separar “Tomar foto” y “Elegir de galería”; comprimir imágenes grandes y
  conservar vista previa antes de subir.

### Fase C — entrenamiento unificado

- [x] Migrar Entrenar, Plan, Workout, Progreso e Historial al shell 3.0.
- [x] Rediseñar biblioteca y ficha de ejercicio.
- [x] Priorizar traducción española, recientes, favoritos y sustituciones.
- [x] Verificar crear plan, comenzar, registrar sets, descanso y finalizar.

### Fase D — juego, grupo y preferencias

- [x] Rediseñar Juego y logros alrededor de progreso accionable.
- [x] Rediseñar Nosotros, notificaciones, peso y privacidad.
- [x] Implementar selector de apariencia e icono con limitaciones explicadas.
- [x] Generar iconos finales, maskable y Apple touch icons.

### Fase E — instalación y salud asistidas

- [x] Crear asistente por plataforma y tutorial visual.
- [x] Añadir enlaces oficiales App Store, Google Play y ajustes de Health
  Connect con fallback comprensible.
- [x] Integrar la preparación de automatizaciones/tokens dentro del asistente.
- [x] Confirmar recepción real sin exponer credenciales.

### Fase F — calidad y producción

- [x] Probar 320, 375, 393, 430 y 768 px; claro/oscuro; teclado y safe areas.
- [x] Probar flujos autenticados completos en el navegador usado como simulador.
- [x] Verificar contraste, foco, lector de pantalla y reducción de movimiento.
- [x] Ejecutar todas las pruebas, build, auditoría de dependencias y revisión de
  payload inicial.
- [x] Desplegar con nueva versión de service worker y verificar actualización.
- [ ] Completar matriz física en los cuatro teléfonos y observar 48 horas.

## Puertas de aceptación

- Ninguna pantalla parece pertenecer a OpenGym o a otra aplicación.
- Las cinco áreas principales siguen accesibles y no se pierde ningún dato.
- Entrenar, tomar foto y registrar comida requieren como máximo dos decisiones
  desde Hoy.
- Todas las acciones que comparten información indican su destino.
- El usuario sabe exactamente si la PWA, el puente y la sincronización están
  listos.
- No hay scroll horizontal ni controles menores de 44 px en los tamaños objetivo.
- La interfaz no contiene textos dañados ni nombres esenciales en otro idioma
  cuando existe traducción.
- Pruebas y build quedan en verde antes de cada despliegue.

## Evidencia de cierre del 28 de agosto de 2026

- Producción desplegada en <https://enfermicambio-98b5a.web.app> con Supabase
  configurado mediante su clave pública; la clave `service_role` no forma parte
  del bundle ni de los archivos de entorno del frontend.
- 47 archivos de prueba y 551 pruebas en verde; build de Vite completado y
  auditoría de dependencias de producción sin vulnerabilidades conocidas.
- Matriz autenticada en el navegador usado como simulador: 320, 375, 393, 430
  y 768 px, sin desplazamiento horizontal y sin objetivos táctiles visibles
  menores de 44 px en las rutas principales.
- Entrenamiento iniciado y descartado de forma segura; biblioteca en español y
  guía visual local de 512 × 512 comprobada en producción.
- Registro de comida comprobado con entradas distintas para cámara trasera y
  galería, sin enviar una foto real ni alterar datos del usuario.
- Puente de salud autenticado: recepción histórica confirmada con 26 métricas;
  Hoy informa correctamente que no existen datos sincronizados para la fecha
  actual.
- Ranking, Juego, Nosotros, Ajustes e Instalación cargan sin alertas de interfaz
  ni scroll horizontal. Los identificadores internos de misión ya no aparecen
  como texto visible.

La única puerta deliberadamente abierta es la validación física y la observación
de 48 horas: requiere instalar la PWA en los cuatro teléfonos reales y esperar
datos nuevos de Apple Health/Health Connect. No bloquea el despliegue web.

## Ajuste 3.1 — identidad histórica y registro móvil

- [x] Recuperar la paleta oscura iOS y los iconos originales de EnfermiCambio.
- [x] Compactar las seis métricas del ranking para iPhone sin perder sus nombres
  accesibles completos.
- [x] Pedir altura, peso y Casa/Gimnasio antes de entrenar; guardar altura y peso
  en las tablas privadas existentes y sincronizar el lugar/equipo con el estado
  de entrenamiento.
- [x] Leer códigos de barras desde la cámara trasera o una foto, con decodificación
  local y consulta editable en Open Food Facts.
- [x] Añadir actividad al aire libre con tiempo, distancia, GPS, mapa y guardado
  privado de los puntos precisos.
- [x] Permitir cargar entrenamientos desde los formatos ya compatibles.
- [ ] Validar cámara y GPS en los cuatro teléfonos físicos; el navegador simula
  tamaños y flujo, pero no sustituye los sensores ni las restricciones del SO.

### Próxima fase — planes automáticos para casa (no incluida en 3.1)

1. Tomar objetivo, experiencia, días disponibles, duración y lesiones/limitaciones.
2. Cruzar el perfil Casa con el equipo realmente marcado por el usuario.
3. Generar una semana equilibrada usando el catálogo fusionado, con alternativa
   de peso corporal para cada ejercicio que requiera equipo.
4. Incluir calentamiento, progresión, descanso y sustituciones, siguiendo el mismo
   modelo de rutinas/ejercicios que ya se integró desde los dos repositorios.
5. Mostrar una vista previa editable; nunca sobrescribir planes existentes sin
   confirmación.
6. Probar que ningún plan queda vacío y que el volumen semanal sube de manera
   gradual antes de habilitarlo en producción.
