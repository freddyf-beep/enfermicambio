# Checkpoint: Sistema de gamificación completo

Fecha: 2026-08-11

## Alcance entregado

### Backend (migraciones forward-only, listas para `supabase db push`)

1. `20260811120000_gamification_schema.sql`
   - `mission_progress.progress_date` + clave única `(mission_id, user_id, progress_date)`.
   - Índice único parcial para cooperativas (`user_id null`).
   - Tablas `battle_pass_tiers` y `battle_pass_claims` con RLS (lectura allowlisted;
     escrituras solo vía función security definer).
   - `profiles.profile_title` (título ganado en el pase).
   - Realtime para `mission_progress`, `user_achievements`, `battle_pass_claims`.

2. `20260811120100_seed_gamification_es.sql`
   - 15 logros y 10 misiones traducidos a español (códigos técnicos intactos).
   - `VAMPIRO` re-definido a la franja nocturna almacenada (18:00-24:00).
   - 4 logros nuevos de distancia de por vida (`KM_25/50/100/250`).
   - 3 misiones nuevas de km (`CAMINA 3 KM`, `CORRE 10 KM`, `10 KM DE GRUPO`).
   - Semilla del pase de batalla: 10 niveles (umbrales 10, 25, 50, 80, 120, 170,
     230, 300, 380, 480 pts) con medallas, títulos, emojis exclusivos y trofeo.

3. `20260811120200_gamification_functions.sql`
   - `daily_missions_for_date(date)`: rotación determinista por fecha
     (2 individuales + 1 cooperativa + 1 competitiva), sin tablas ni cron.
   - `evaluate_missions(date)`: evalúa las 4 misiones del día para los 4 usuarios
     (métricas: morning_steps, night_steps, distance_meters, workout_distance_m,
     vs_14d_avg, active_day, balanced_day, steps, members_with_workout),
     escribe `mission_progress`, premia vía `award_points` (idempotente) y
     publica posts de sistema. Solo service_role.
   - `evaluate_achievements(user, date)`: métricas acumuladas (workouts, pasos
     máximos, victorias de franjas, dictador, racha de meta, workouts 7d,
     distancia de workout, último lugar consecutivo, día perfecto, campeonatos,
     distancia de vida); inserta `user_achievements` (única vez, vía RETURNING),
     premia y publica posts. Solo service_role.
   - `claim_battle_pass_reward(season, tier)`: verifica el umbral contra el
     ledger, registra el claim y aplica títulos. Callable por `authenticated`.

### Edge Function

- `close_day`: ahora evalúa misiones y logros tras las rachas, antes del post
  diario. Retries seguros por idempotencia del ledger.

### Frontend (Flutter)

- Modelos de dominio: `Mission`, `MissionProgress`, `Achievement`,
  `UserAchievement`, `Streak`, `BattlePassTier`, `BattlePassClaim`,
  `SeasonResult`, `SeasonKm`.
- `SupabaseGameRepository` ampliado: misiones del día, progreso, logros con
  estado, rachas, pase (niveles + claims + reclamar), km de temporada, historial.
- Pantalla JUEGO con datos reales: banner de temporada (posición y puntos),
  pase de batalla con pista horizontal y botón Reclamar, misiones del día con
  progreso, rachas, grid de logros (desbloqueado/bloqueado/secreto), tabla de
  puntos, km de la temporada, historial de temporadas con campeón.
- Celebraciones in-app vía Realtime: snackbar al desbloquear logro o completar
  misión + refetch.
- RANKING con datos reales por categoría (pasos, franjas, distancia,
  entrenamientos, calorías, puntos) y período (hoy/semana/temporada):
  `RankingRepository` nuevo; el selector recarga de verdad.

## Verificación local

- `flutter analyze`: 0 errores, 0 warnings (21 infos de estilo pre-existentes).
- `flutter test`: 64 tests pasan (incluye widget tests de JUEGO con snapshot
  inyectado y los tests existentes de ranking sin cambios de contrato).
- `close_day`: bundle esbuild OK (sintaxis TypeScript).

## Despliegue pendiente (requiere CLI de Supabase, no disponible en este host)

```powershell
supabase db push          # aplica las 3 migraciones nuevas
supabase functions deploy close_day
```

Verificación post-despliegue:

```sql
-- Rotación del día (debe devolver 4 misiones: 2 individual + 1 coop + 1 comp)
select mission_type, name from daily_missions_for_date(current_date);

-- Evaluación manual de un día (solo con servicio; close_day ya lo hace)
select * from evaluate_missions('2026-08-11');
select * from evaluate_achievements('<user_id>', '2026-08-11');

-- Pase de batalla
select * from battle_pass_tiers order by tier;
select * from battle_pass_claims;
select claim_battle_pass_reward('<season_id>', 1); -- como usuario autenticado

-- Realtime
-- verificar en el dashboard de Supabase que mission_progress,
-- user_achievements y battle_pass_claims están en la publicación.
```

## Decisiones de diseño tomadas en ejecución

- Los logros de la piscina `VAMPIRO`/`SOFA_DE_ORO`/`DICTATOR` usan ventanas
  agregadas almacenadas (18-24, último del día, 3 franjas + total).
- `posts.author_id` es NOT NULL: las misiones cooperativas publican el post con
  el autor de mayor contribución del día.
- El título del pase sobrescribe `profiles.profile_title` (el más reciente gana);
  las medallas/emojis quedan como historial de claims.
- `timezone` bajado de ^0.11.1 a ^0.10.1 para resolver el conflicto con
  `flutter_local_notifications` ^19.5.0 (API usada compatible; no toca el
  código de notificaciones).
