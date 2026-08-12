# Diseño: Sistema de Notificaciones + Registro de Peso

Fecha: 2026-08-11
Estado: Aprobado por el propietario (carta blanca para implementar)

## 1. Objetivo

Convertir los eventos de la competencia en notificaciones sociales y juguetonas
(SPECS.md §38) que hagan la app viva: adelantamientos, rondas, logros, workouts,
posts del feed, comentarios, reacciones, misiones, temporada, metas personales y
peso. Todo entregado con un centro in-app persistente (campana con badge) y un
canal de notificaciones locales del sistema preparado para FCM futuro.

Decisiones tomadas con el propietario:

- **Alcance**: centro in-app + notificaciones del sistema locales
  (`flutter_local_notifications`), arquitectura lista para FCM (el envío se
  disparará desde Edge Functions; solo falta el canal nativo).
- **Enfoque**: servidor como fuente de verdad (tabla `notifications` +
  Edge Functions + Realtime). Invariantes del proyecto: la database es
  autoritativa; Realtime es solo entrega.
- **Peso**: incluido como log personal privado. Sin ranking público entre los 4.
  Celebración personal solamente (nunca shaming).
- **Sin presencia en línea** ("quién está aquí"): descartado en este slice por
  ser invasivo y fuera del tono del producto (PRODUCT.md anti-references:
  sin presión de engagement).

## 2. Catálogo de notificaciones

| # | Tipo (`notification_type`) | Destino | Ejemplo de texto |
|---|---|---|---|
| 1 | `overtake` | Superado (el que pierde posición) | "🚨 Samir te pasó por 1.245 pasos." |
| 2 | `leader_change` | Los otros 3 | "👑 Freddy tomó el primer lugar." |
| 3 | `round_result` | Los 4 | "🏆 Felipe ganó la ronda de la mañana." |
| 4 | `round_ending_soon` | Los 4 (aviso de cierre) | "🌙 Quedan 30 min de la ronda de la noche." |
| 5 | `achievement` | Desbloqueador | "🔥 Desbloqueaste el logro Paso Firme." |
| 6 | `workout` | Los otros 3 | "🏃 Samir completó una carrera de 7,1 km." |
| 7 | `feed_post` | Los otros 3 | "🍔 Felipe publicó una foto de comida." |
| 8 | `comment` | Autor del post | "💬 Cristian comentó tu publicación." |
| 9 | `reaction` | Autor del post | "❤️ Samir reaccionó a tu foto." |
| 10 | `mission` | Los 4 | "🎯 Misión completada: Equipo 20K." |
| 11 | `season` | Los 4 | "👑 Cristian ganó la temporada." |
| 12 | `steps_milestone` | Solo el usuario | "🎉 ¡Llegaste a 10.000 pasos hoy!" |
| 13 | `personal_record` | Solo el usuario | "📈 ¡Nuevo récord personal: 12.340 pasos!" |
| 14 | `daily_goal` | Solo el usuario | "✅ Cumpliste tu meta de pasos de hoy." |
| 15 | `weight_entry_goal` | Solo el usuario | "⚖️ ¡Meta de peso lograda!" |
| 16 | `weight_change` | Solo el usuario | "⚖️ Bajaste 0,8 kg esta semana." |

Los tipos 1, 2, 3, 5, 10, 11, 12, 13, 14, 15, 16 los genera el servidor
(Edge Functions). Los tipos 6, 7 los genera el servidor vía trigger en
`posts` (solo posts manuales no `system_generated`). Los tipos 8, 9 vía
trigger en `comments` / `reactions`.

El tipo 4 (aviso de cierre de ronda) lo genera el cron ligero
`notify_round_ending` (ver §4.4), con dedupe por payload.

## 3. Esquema de base de datos (migración nueva)

### 3.1 Tabla `notifications`

```sql
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  payload jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  constraint notifications_type_check check (
    type in ('overtake','leader_change','round_result','round_ending_soon',
      'achievement','workout','feed_post','comment','reaction','mission',
      'season','steps_milestone','personal_record','daily_goal',
      'weight_entry_goal','weight_change')
  )
);

create index notifications_user_created_idx
  on public.notifications (user_id, created_at desc);
create index notifications_unread_idx
  on public.notifications (user_id) where is_read = false;
```

`payload` guarda referencias para navegación: `post_id`, `actor_id`,
`competition_date`, `metric`, `value`. Nunca datos sensibles.

### 3.2 Tabla `weight_entries`

```sql
create table public.weight_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  entry_date date not null,
  weight_kg numeric(5,2) not null check (weight_kg between 20 and 400),
  source text not null default 'manual' check (source in ('manual','import')),
  created_at timestamptz not null default now(),
  unique (user_id, entry_date)
);

create index weight_entries_user_date_idx
  on public.weight_entries (user_id, entry_date desc);
```

Un registro por usuario y día (upsert idempotente). El peso es privado:
RLS de dueño, nunca expuesto en ranking ni en posts del feed.

### 3.3 Columna de meta de peso en `profiles`

```sql
alter table public.profiles
  add column weight_goal_kg numeric(5,2)
  check (weight_goal_kg is null or weight_goal_kg between 20 and 400);
```

`null` = sin meta. La meta es personal y privada.

### 3.4 Tabla `rank_positions` (soporte de overtakes)

```sql
create table public.rank_positions (
  competition_date date not null,
  user_id uuid not null references public.profiles (id) on delete cascade,
  position int not null,
  updated_at timestamptz not null default now(),
  primary key (competition_date, user_id)
);
```

Guarda la última posición conocida del día por usuario. El Edge Function
`generate_events` la usa para detectar adelantamientos entre syncs: si un
usuario sube de posición, todos los que quedaron atrás reciben `overtake`
("X te pasó"). El cambio de líder (posición 1 distinta) dispara
`leader_change` para los otros 3, respetando el cooldown existente de
`app_config.leader_event_cooldown` (reutilizando `maybe_publish_leader_change`
para el post del feed).

## 4. Funciones y Edge Functions

### 4.1 Función `insert_notification` (SQL, security definer)

Único punto de escritura de notificaciones. Respeta preferencias del usuario.
Llamable solo por `service_role`:

```sql
create or replace function public.insert_notification(
  p_user_id uuid, p_type text, p_title text, p_body text,
  p_payload jsonb default '{}'::jsonb
) returns void ...
```

Reglas:

- Lee `profiles.notification_preferences` (jsonb `{category: bool}`). Si la
  categoría del tipo está en `false`, no inserta. Categoría por tipo:
  `overtake`→`overtakes`, `leader_change`→`overtakes`,
  `round_result`/`round_ending_soon`→`rounds`, `achievement`→`achievements`,
  `workout`→`workouts`, `feed_post`→`feed`, `comment`/`reaction`→`social`,
  `mission`→`missions`, `season`→`season`, `steps_milestone`/
  `personal_record`/`daily_goal`→`personal`, `weight_entry_goal`/
  `weight_change`→`weight`.
- Preferencia ausente = activada (default on).
- Inserta la fila con payload.

### 4.2 Función `notify_post_activity` (SQL trigger)

Triggers en `posts`, `comments`, `reactions` (AFTER INSERT):

- `posts`: si `system_generated = false`, inserta notificación tipo
  `feed_post` para los otros 3 usuarios (payload con `post_id`, `actor_id`,
  `post_type`). El `body` se compone en SQL con el `post_type`.
- `comments`: notifica `comment` al autor del post (si el comentarista no es
  el autor).
- `reactions`: notifica `reaction` al autor del post solo si el autor del post
  no reaccionó y no existe ya una notificación `reaction` del mismo actor para
  el mismo post en las últimas 24 h (evita spam de toggles).

Los triggers insertan vía `insert_notification` (security definer), así el
cliente no necesita permisos especiales más allá de su insert normal.

### 4.3 Edge Function `generate_events`

Nueva función Deno HTTP llamada por el cliente después de cada sync exitoso
(fire-and-forget). Entrada: `{user_id, date}`. Auth: `publishable` (JWT del
cliente); la función valida que `user_id` del body coincide con
`auth.uid()` del JWT y extrae el perfil desde ahí. Nadie puede generar
eventos en nombre de otro.

Pasos (todos idempotentes vía unicidad o lectura del estado previo):

1. **Ranking del día**: lee `daily_activity` del día (sin manuales), ordena por
   pasos. Compara con `rank_positions`:
   - Por cada usuario adelantado por el usuario sincronizado → `overtake` al
     superado ("X te pasó por N pasos").
   - Si el líder cambió y pasó el cooldown → `leader_change` a los otros 3 +
     `maybe_publish_leader_change` para el post del feed.
   - Upsert `rank_positions`.
2. **Milestones de pasos**: si el usuario superó 5.000/10.000/15.000/20.000
   pasos y no existe `steps_milestone` previo para (user, date, milestone)
   (chequea payload en notificaciones existentes) → notifica.
3. **Récord personal**: si `daily_steps` > máximo histórico del usuario en
   `daily_activity` → `personal_record` (una vez por día).
4. **Meta diaria**: si `daily_steps >= daily_step_target` → `daily_goal` (una
   vez por día; dedupe por payload).

Idempotencia: cada emisión de milestone/récord/meta registra un marcador
en `notifications.payload` (`key` = `steps:10000:2026-08-11`) y se chequea con
un `select` antes de insertar. `rank_positions` garantiza que overtakes no se
repitan mientras las posiciones no cambien.

### 4.4 Edge Functions existentes — añadir notificaciones

- `close_round`: después de insertar el post, `insert_notification`
  `round_result` para los 4 ("X ganó la ronda de la mañana").
- Aviso `round_ending_soon`: cron ligero `notify_round_ending` ejecutado
  30 min antes del cierre de cada ronda (12:00, 18:00, 00:00 en
  `competition_timezone`). Llama al RPC `insert_notification` con dedupe por
  payload `round:<nombre>:<fecha>`: si ya existe la notificación para
  (user, type, payload), no inserta otra.
- `close_day`: `round_result` del día para los 4 ("X se lleva el día") y
  `daily_goal` personal para quienes cumplieron meta (dedupe por payload).
- `close_season`: `season` para los 4 (ganador de temporada).

### 4.5 Peso (solo cliente + trigger de meta)

- Registrar peso: el cliente hace upsert en `weight_entries` (RLS de dueño).
- Detectar meta: el cliente compara el peso más reciente con
  `profiles.weight_goal_kg` al registrar; si `weight_kg <= weight_goal_kg`
  (nunca se vuelve a emitir mientras el goal no cambie) → el cliente llama a
  `insert_notification`... no: el cliente no puede llamar a
  `insert_notification` (service_role). Solución: RPC `notify_weight_goal`
  (security definer, ejecutable por `authenticated`, valida que el usuario
  objetivo es el propio llamador, emite `weight_entry_goal` y
  `weight_change`). El cliente la llama después de un upsert exitoso.
- `weight_change` semanal: se compara la entrada más reciente con la de hace
  7 días (mismo usuario). Solo si bajó/ subió ≥ 0,5 kg. Se emite una vez por
  semana (dedupe payload `week:2026-W33`).

## 5. RLS

| Tabla | Política |
|---|---|
| `notifications` | SELECT/UPDATE: dueño (`user_id = auth.uid()`). INSERT: solo `service_role` (vía `insert_notification` security definer). DELETE: no (retención natural, la lista pagina). |
| `weight_entries` | SELECT/INSERT/UPDATE/DELETE: dueño. Nadie más puede leer (privado). |
| `profiles.weight_goal_kg` | Actualizable solo por el dueño. No se muestra a otros (el cliente nunca la renderiza para otros). |
| `rank_positions` | Sin acceso directo (solo `service_role` / security definer). |

## 6. Cliente Flutter

### 6.1 Feature `notifications` (nuevo, `lib/features/notifications/`)

- `domain/notification_models.dart`: `AppNotification` (id, type, title, body,
  payload, isRead, createdAt) + `NotificationCategory` enum (overtakes, rounds,
  achievements, workouts, feed, social, missions, season, personal, weight) +
  `NotificationPreferences`.
- `domain/notification_repository.dart` (interfaz) +
  `data/supabase_notification_repository.dart`:
  - `loadLatest({cursor, limit})` — paginación cursor por `created_at`.
  - `markAllRead()`, `markRead(id)`.
  - `unreadCount()` — subscribe a Realtime `notifications` (INSERT) y refetch.
  - `setPreference(category, enabled)` — update `profiles.notification_preferences`.
  - `fetchPreferences()`.
- `presentation/notification_bell.dart`: icono campana con badge del conteo no
  leído (Stream de Realtime), abre `NotificationsScreen`.
- `presentation/notifications_screen.dart`: lista agrupada (Hoy / Ayer /
  Anteriores), pull-to-refresh, marcado leído al tocar, navegación según
  payload (`post_id` → pantalla de post/feed, `competition_date` → ranking,
  null → ninguna). Usa `AsyncStateView` y estados del shared UI.

### 6.2 Integración en el shell

- `app_shell.dart` o header de HOY: la campana con badge se coloca en el
  `AppBar` de `HOY` (y en las otras tabs si tienen AppBar propia, igual que el
  health icon en NOSOTROS). Diseño mínimo: un `NotificationBell` en el
  `AppBar.actions` de `HomeTab` y `NotificationsScreen` reutilizable.
- Realtime: al entrar la app, `AppNotificationStream` se suscribe al canal
  `notifications` filtrando `user_id` (RLS ya filtra; el canal usa el filtro
  de la tabla). En reconnect: refetch del conteo y lista desde la DB.

### 6.3 Feature `weight` (nuevo, `lib/features/weight/`)

- `domain/weight_models.dart`: `WeightEntry` (id, date, weightKg, source).
- `data/supabase_weight_repository.dart`:
  - `upsert(date, weightKg)`.
  - `latest()`, `history({limit})`.
  - `setGoal(kg?)` (update `profiles.weight_goal_kg`).
  - `notifyGoalIfMet()` → llama RPC `notify_weight_goal` (fire-and-forget).
- `presentation/weight_screen.dart`: pantalla de "Mi peso" accesible desde
  NOSOTROS (card por perfil propio → "Mi peso"): último peso, meta,
  progreso bar, registrar peso (dialog con campo numérico + fecha = hoy),
  historial simple (últimos 7 registros). Solo datos del usuario logueado.

### 6.4 Notificaciones locales del sistema (push-ready)

- Dependencia `flutter_local_notifications`.
- `LocalNotificationService` (abstract) + `FlutterLocalNotificationService`:
  `show(id, title, body)` con canal Android "competencia" (importancia alta)
  y compatibilidad iOS. `NotificationTapRouter` resuelve el payload.
- `NotificationCoordinator`: al recibir evento Realtime de `notifications`
  para el usuario logueado y si la app NO está en primer plano, muestra la
  notificación local. En primer plano no se muestra (el badge y la lista ya
  avisan) — evitando duplicados y ruido.
- Interfaz `PushSender` vacía (`sendToDevice(token, payload)`) documentada
  para FCM: cuando exista Firebase, una Edge Function `send_push` leerá las
  filas nuevas de `notifications` y llamará a FCM con los tokens de los
  dispositivos (el registro de `device_tokens` se agrega en ese slice futuro,
  no en este). Este slice NO implementa FCM (decisión del propietario); solo
  deja la interfaz.

### 6.5 Preferencias en NOSOTROS

- Sección "Notificaciones" en `AboutTab`: toggles por categoría
  (`overtakes`, `rounds`, `achievements`, `workouts`, `feed`, `social`,
  `missions`, `season`, `personal`, `weight`), persistidos vía
  `SupabaseNotificationRepository.setPreference`.

### 6.6 Disparadores del cliente

- `HealthSyncBootstrap.syncOnResume` / tras sync exitoso: invoca la Edge
  Function `generate_events` (fire-and-forget, vía
  `supabase.functions.invoke('generate_events', {body: {user_id, date}})`).
  La función valida `user_id` contra el JWT del llamador (§4.3).

## 7. Tonos de texto

Siempre en español (fase 8: 100% español). Juguetón, directo, nunca médico ni
avergonzante (PRODUCT.md). Emojis por tipo (ver tabla §2). Términos: "pasos",
"ronda de la mañana/tarde/noche", "logro", "meta". El peso solo en notificaciones
propias y con tono celebratorio.

## 8. Testing

- SQL: checks en la migración (bloque `do $$ ... $$`) que verifican:
  insert de post manual → 3 notificaciones `feed_post`; insert de post del
  sistema → 0; comment de otro usuario → 1 notificación `comment`; reaction
  repetida en 24 h → sin duplicado; preferencia `feed=false` → el trigger no
  inserta.
- Flutter widget: campana muestra badge con conteo; `NotificationsScreen`
  renderiza lista y marca leído; toggles de preferencias persisten;
  `WeightScreen` registra peso y muestra progreso a meta.
- `flutter analyze` limpio; `flutter test` existente sigue pasando.

## 9. Fuera de alcance (explícito)

- FCM/APNs reales (interfaz lista, canal futuro).
- Presencia en línea / "quién está aquí".
- Ranking público de peso o puntos por peso.
- Sistema completo de eventos server-side 4.6 (milestones de feed etc.):
  este slice genera los eventos necesarios para las notificaciones
  (overtakes, récords, metas, líder) y deja el resto del roadmap intacto.
- Pantallas nuevas de feed: la navegación desde notificaciones con
  `post_id` resalta el post en el feed existente (scroll), sin pantalla
  dedicada nueva.
