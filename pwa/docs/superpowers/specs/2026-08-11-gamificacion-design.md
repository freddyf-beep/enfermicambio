# Diseño: Sistema de gamificación completo (misiones, logros, km, pase de batalla, motivación, ranking)

Fecha: 2026-08-11
Estado: aprobado (aproximación A y B aprobadas; resto delegado al implementador)

## 1. Contexto y estado actual

El backend ya tiene: tablas de `achievements`, `user_achievements`, `streaks`, `missions`,
`mission_progress`, `seasons`, `season_points` (ledger append-only), `season_results`,
`award_points` (service-role only) y la vista `season_standings`. Están sembrados 15 logros y
10 misiones (en inglés). Existen Edge Functions `close_round`, `close_day`, `close_season`
desplegadas.

El frontend: la pantalla JUEGO muestra clasificación real pero misiones y medallas falsas
(hardcodeadas). RANKING tiene el selector de categorías/períodos pero siempre muestra los
mismos datos (solo pasos del día). No existe pase de batalla.

## 2. Objetivos (acordados con el usuario)

1. Todo el trabajo: backend + JUEGO + pase de batalla.
2. Pase de batalla: recompensas por umbrales de puntos de temporada (10 niveles, sin monedas ni pagos).
3. Kilómetros: logros + misiones + visualización.
4. Misiones diarias: rotación diaria de una piscina (2 individuales + 1 cooperativa + 1 competitiva).
5. Traducir logros y misiones a español.
6. Motivación: celebraciones in-app + eventos de feed (sin push).
7. Ranking: completar con datos reales por categoría y período.

## 3. Invariantes respetados

- Progreso de misiones/logros solo con actividad automática (`manual_entry_detected = false`).
- Puntos siempre vía `award_points` (service-role). Clientes nunca escriben puntos.
- `competition_timezone` define todos los cortes de día.
- El cliente nunca puede forjar posts de sistema (`system_generated`), logros o misiones.
- Sin pagos, sin monedas virtuales.

## 4. Backend

### 4.1 Migración: `mission_progress` con fecha diaria

- Añadir columna `progress_date date not null default current_date`.
- Cambiar la clave única a `(mission_id, user_id, progress_date)`; para cooperativas
  (`user_id` null) la unicidad la cubre una parcial: `unique (mission_id, progress_date)
  where user_id is null`.
- Migrar filas existentes a `progress_date = current_date` (solo diagnóstico; en producción
  la tabla estará vacía hasta que la evaluación esté viva).

### 4.2 Función SQL: `daily_missions_for_date(p_date date)`

Devuelve las misiones del día: 2 individuales + 1 cooperativa + 1 competitiva, elegidas de la
piscina activa (`starts_at <= p_date < ends_at`) ordenadas por `md5(id::text || p_date::text)`.
Determinista, sin tabla de asignación ni cron. La usan tanto close_day (para evaluar) como el
cliente (para mostrar).

### 4.3 Migración: traducción a español y nuevos logros/misiones de km

- `UPDATE achievements` y `UPDATE missions` con nombres/descripciones en español.
- `rules` de misiones redefinidas a métricas evaluables con los datos agregados existentes:

| Código misión | Nombre es | Métrica evaluable |
| --- | --- | --- |
| EARLY BIRD | Madrugador | `morning_steps >= 2500` |
| MORNING PUSH | Impulso matutino | `morning_steps >= 3500` |
| BEAT YOURSELF | Supérate | `daily_steps >= 1.2 * avg14d` |
| RUN FORREST | Corre Forrest | max `workout_distance_m >= 5000` |
| ACTIVE DAY | Día activo | `daily_steps >= meta` y ≥1 workout |
| BALANCED DAY | Día equilibrado | `daily_steps >= meta` y dentro de meta calórica |
| THE FOUR | Los cuatro | coop: suma pasos `>= 40000` |
| TEAM TRAINING | Entreno en equipo | coop: ≥3 de 4 con workout |
| LAST CHANCE | Última oportunidad | competitiva: mayor `night_steps` |
| DUEL | Duelo matutino | competitiva: mayor `morning_steps` (gana el 1º) |
| (nueva) CAMINA 3 KM | Camina 3 km | `distance_meters >= 3000` |
| (nueva) CORRE 10 KM | Corre 10 km | `workout_distance_m >= 10000` |
| (nueva) 10 KM DE GRUPO | 10 km de grupo | coop: suma `distance_meters >= 10000` |

- Nuevos logros de distancia de por vida (métrica `lifetime_distance_m`): `KM_25`
  (Cuarto de maratón, 25.000 m), `KM_50` (50 km), `KM_100` (100 km), `KM_250` (250 km).

### 4.4 Función SQL: `evaluate_missions(p_date date)` (security definer, service-role)

- Para cada misión del día y cada usuario con actividad automática: calcula el progreso
  según su `rules.metric`, upsert en `mission_progress` con `progress_date = p_date`.
- Al completar: `award_points` (idempotente, reference determinista
  `mission:<date>:<mission_id>:<user_id>`), y post de feed `mission` (system_generated).
- Cooperativas: fila de grupo; al completarse todos los que participan reciben puntos y post.
- Competitivas: se premia al mejor del día (los demás quedan sin completar).

### 4.5 Función SQL: `evaluate_achievements(p_user_id uuid, p_date date)` (security definer, service-role)

- Computa métricas acumuladas: `workouts_synced`, `daily_steps` (máximo), `morning_round_wins`,
  `night_steps`, `rounds_and_total_wins`, `step_goal_streak`, `workouts_7d`,
  `workout_distance_m` (máximo), `last_place_streak`, `perfect_day`, `season_wins`,
  `lifetime_distance_m`.
- Inserta en `user_achievements` (la clave única evita duplicados) y premia puntos vía
  `award_points` si `season_points > 0`. Post de feed `achievement` por cada desbloqueo.
- Nota: `VAMPIRO` se re-sembra con métrica `night_steps` (ventana 18-24) porque el agregado
  de las 22:00 no existe; descripción ajustada.

### 4.6 `close_day` extendido

Al cierre del día: ranking + rachas (ya existe) y además:
- `select evaluate_missions(p_date => competitionDate)`
- `select evaluate_achievements(p_user_id, p_date)` para cada uno de los 4 usuarios
- Post diario ya existente.

### 4.7 Pase de batalla

Tablas nuevas:

```sql
battle_pass_tiers (
  id uuid pk,
  tier int not null,            -- 1..10
  threshold_points int not null,-- umbral de puntos de temporada
  reward_type text,             -- 'badge' | 'title' | 'emoji'
  reward_key text,              -- id interno estable
  reward_name text,             -- texto visible
  reward_icon text,             -- icono Material
  unique (tier)
)

battle_pass_claims (
  id uuid pk,
  season_id uuid fk seasons,
  user_id uuid fk profiles,
  tier int not null,
  claimed_at timestamptz default now(),
  unique (season_id, user_id, tier)
)
```

- Semilla de 10 niveles (umbrales: 10, 25, 50, 80, 120, 170, 230, 300, 380, 480) con
  mezcla de medallas, títulos, emojis exclusivos y trofeo final.
- `profiles`: nueva columna `profile_title text null`.
- RPC `claim_battle_pass_reward(p_season_id, p_tier)`: security definer; verifica que el
  usuario alcanzó el umbral (suma del ledger), inserta `battle_pass_claims`, y aplica el
  efecto: título → `profiles.profile_title`; badge/emoji/trofeo → solo registro para UI
  (los emojis exclusivos aparecen en la paleta de reacciones del usuario).
- Los títulos/medallas se muestran en NOSOTROS (historial de recompensas del usuario).
- Realtime habilitado para `battle_pass_claims`, `mission_progress`, `user_achievements`.

## 5. Frontend

### 5.1 Modelos y repositorio de juego

- Ampliar `game_models.dart`: `Mission`, `MissionProgress`, `Achievement`,
  `UserAchievement`, `Streak`, `BattlePassTier`, `BattlePassClaim`, `SeasonResult`.
- Ampliar `SupabaseGameRepository`:
  - `dailyMissionsFor(DateTime date)` (usa `daily_missions_for_date`)
  - `missionProgressFor(date)`, `achievementsWithState(userId)`, `streaksFor(userId)`,
    `battlePassFor(seasonId, userId)`, `claimBattlePass(seasonId, tier)`,
    `seasonHistory()` (temporadas cerradas + campeón desde `season_results`).

### 5.2 Pantalla JUEGO (rediseño con datos reales)

1. Banner de temporada (existe) + posición + puntos.
2. **Pase de batalla**: pista horizontal de 10 niveles, progreso derivado de los puntos de
   la temporada, niveles alcanzados y reclamables con botón "Reclamar", reclamados con check.
3. **Misiones del día**: las 4 misiones rotadas con progreso real (barra), recompensa y
   estado completado.
4. **Rachas**: tarjeta de racha de meta de pasos (actual / máxima).
5. **Logros**: grid con estados desbloqueado / bloqueado / secreto (icono candado).
6. **Trofeos e historial de temporadas**: campeones de temporadas cerradas.
7. **Km de la temporada**: sección propia con los km recorridos por usuario en la temporada
   (suma de `distance_meters` dentro del rango de la temporada), ordenados de mayor a menor.

### 5.3 Celebraciones in-app

- Suscripción Realtime a `user_achievements` y `mission_progress` del usuario actual:
  al llegar una fila nueva completada, snackbar animado con icono + refetch de JUEGO.
- Los eventos de feed ya los publica el servidor (posts `achievement` / `mission`).

### 5.4 RANKING con datos reales

- Nuevo `RankingRepository.load(category, period)`:
  - `hoy`: agregado de `daily_activity` de hoy (pasos, distancia, calorías, franjas).
  - `semana`: suma de la semana en `competition_timezone`.
  - `temporada`: suma desde el inicio de la temporada; `puntos` usa `season_standings`.
  - `entrenamientos`: count de `workouts` en el período.
- Siempre se muestran los 4 usuarios (ceros para quien no tenga datos) y el indicador de
  frescura se conserva para la vista de hoy (fuente: `synced_at`).
- Se mantiene el contrato de prueba existente: `RankingTab(rows: [...], loadFromBackend: false)`.

## 6. Pruebas

- Unit: rotación determinista (mismo día → mismo conjunto; días distintos → distintos),
  traducción presente (seeds), evaluación de misiones por métrica.
- Widget: JUEGO con misiones/logros reales inyectados (contrato con `loadFromBackend`),
  RANKING existente sigue pasando.
- `flutter analyze` y `flutter test` limpios.
- Migraciones y funciones SQL se entregan listas para `supabase db push` (CLI no disponible
  en este host; la verificación se documenta).

## 7. Fuera de alcance

- Push notifications (fase existente del roadmap).
- Media pipeline y sistema de eventos restantes del feed (roadmap).
- Balanceo fino de umbrales del pase (configurable en semilla).
