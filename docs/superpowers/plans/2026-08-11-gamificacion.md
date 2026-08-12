# Sistema de Gamificación Completo — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Completar el sistema de gamificación: misiones diarias rotativas con datos reales, logros, rachas, trofeos, pase de batalla por umbrales de puntos, km, celebraciones in-app y ranking con categorías reales.

**Architecture:** Backend SQL (migraciones forward-only + funciones plpgsql security definer) que alimenta la pantalla JUEGO y RANKING vía Supabase. El motor de evaluación vive en SQL (donde están los datos); el cliente solo lee y reclama el pase. `close_day` se extiende para llamar a las evaluaciones. Frontend Flutter con modelos/repositorios ampliados y rediseño de JUEGO manteniendo el contrato de prueba `loadFromBackend`.

**Tech Stack:** Flutter/Dart, Supabase (PostgreSQL, RLS, Realtime), Edge Functions Deno.

## Global Constraints

- Puntos siempre vía `award_points` (service-role); funciones de evaluación llamadas solo por service_role.
- Progreso de misiones/logros solo con `manual_entry_detected = false`.
- `competition_timezone` (America/Santiago, `AppEnvironment.competitionTz`) define cortes de día.
- Nombres y textos de logros/misiones en español (la app es 100% español).
- Clientes nunca insertan posts con `system_generated = true` (RLS lo bloquea).
- `flutter analyze` y `flutter test` limpios al final de cada tarea Flutter.
- No hay CLI de Supabase en este host: las migraciones se entregan listas para `supabase db push`; su verificación se documenta en el commit.

---

### Task 1: Migración de esquema (mission_progress diario, pase de batalla, título de perfil, realtime)

**Files:**
- Create: `supabase/migrations/20260811120000_gamification_schema.sql`

**Interfaces:**
- Consumes: tablas `mission_progress`, `profiles`, `seasons`, `season_points` existentes.
- Produces: columnas `mission_progress.progress_date`, `profiles.profile_title`, tablas `battle_pass_tiers`, `battle_pass_claims`, realtime para las 3 tablas de progreso.

- [ ] **Step 1: Escribir la migración completa**

```sql
-- Gamification schema: daily mission progress, battle pass tiers/claims,
-- profile titles, and realtime for progress tables. Forward-only.

-- Daily mission progress: progress resets per competition day.
alter table public.mission_progress
  add column progress_date date not null default current_date;

alter table public.mission_progress
  drop constraint mission_progress_mission_user_unique;

alter table public.mission_progress
  add constraint mission_progress_mission_user_date_unique
  unique (mission_id, user_id, progress_date);

create unique index mission_progress_group_date_unique
  on public.mission_progress (mission_id, progress_date)
  where user_id is null;

-- Battle pass: season progression rewards by points thresholds.
create table public.battle_pass_tiers (
  id uuid primary key default gen_random_uuid(),
  tier integer not null,
  threshold_points integer not null,
  reward_type text not null,
  reward_key text not null,
  reward_name text not null,
  reward_icon text not null,
  created_at timestamptz not null default now(),
  constraint battle_pass_tiers_tier_unique unique (tier),
  constraint battle_pass_tiers_threshold_positive check (threshold_points >= 0),
  constraint battle_pass_tiers_reward_type_check check (
    reward_type in ('badge', 'title', 'emoji')
  )
);

create table public.battle_pass_claims (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  tier integer not null,
  claimed_at timestamptz not null default now(),
  constraint battle_pass_claims_season_user_tier_unique
    unique (season_id, user_id, tier)
);

create index battle_pass_claims_user_idx
  on public.battle_pass_claims (user_id);

-- Profile titles awarded by the battle pass (shown in NOSOTROS).
alter table public.profiles
  add column profile_title text;

-- RLS: tiers readable by the four allowlisted users; claims are read by
-- peers and inserted ONLY through the security definer claim function.
alter table public.battle_pass_tiers enable row level security;
alter table public.battle_pass_claims enable row level security;

create policy battle_pass_tiers_read_allowlisted
  on public.battle_pass_tiers
  for select
  using (public.is_allowlisted_user());

create policy battle_pass_claims_read_allowlisted
  on public.battle_pass_claims
  for select
  using (public.is_allowlisted_user());

-- No insert/update policies: writes flow through claim_battle_pass_reward.

-- Realtime for progress surfaces (database stays authoritative).
alter publication supabase_realtime add table public.mission_progress;
alter publication supabase_realtime add table public.user_achievements;
alter publication supabase_realtime add table public.battle_pass_claims;
```

- [ ] **Step 2: Verificar sintaxis SQL localmente**

Run: `node -e "const fs=require('fs');const s=fs.readFileSync('supabase/migrations/20260811120000_gamification_schema.sql','utf8');console.log('bytes',s.length)"` — solo valida que el archivo existe y no está vacío. La verificación real (`supabase db push`) se documenta en el commit (CLI no disponible en este host).

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260811120000_gamification_schema.sql
git commit -m "feat(db): daily mission progress, battle pass schema, profile titles"
```

---

### Task 2: Migración de seeds (traducción a español, métricas evaluables, logros y misiones de km)

**Files:**
- Create: `supabase/migrations/20260811120100_seed_gamification_es.sql`

**Interfaces:**
- Consumes: `achievements` (columna `code`), `missions`.
- Produces: logros/misiones en español con `rules.metric` evaluable por `evaluate_missions`/`evaluate_achievements` (Task 3): `morning_steps`, `vs_14d_avg`, `workout_distance_m`, `active_day`, `balanced_day`, `distance_meters`, `steps`, `members_with_workout`, `night_steps`, y métricas de logros `lifetime_distance_m`.

- [ ] **Step 1: Escribir la migración**

```sql
-- Translate achievement/mission seeds to Spanish and add km content.
-- Technical codes and metric names are stable; display text only. Forward-only.

update public.achievements set
  name = v.name,
  description = v.description,
  icon = v.icon
from (values
  ('FIRST_BLOOD', 'Primera vez', 'Primer entrenamiento sincronizado', 'fitness_center'),
  ('5K_CLUB', 'Club 5K', '5.000 pasos en un día', 'directions_walk'),
  ('10K_CLUB', 'Club 10K', '10.000 pasos en un día', 'directions_walk'),
  ('20K_CLUB', 'Club 20K', '20.000 pasos en un día', 'directions_run'),
  ('MARATHON_LEGS', 'Piernas de maratón', '25.000 pasos en un día', 'directions_run'),
  ('GALLO', 'Gallo', 'Gana 5 franjas de la mañana', 'wb_twilight'),
  ('VAMPIRO', 'Vampiro', '5.000 pasos en la franja nocturna (18:00-24:00)', 'nightlight'),
  ('DICTATOR', 'Dictador', 'Gana las 3 franjas y el total del día', 'emoji_events'),
  ('ON_FIRE', 'En racha', 'Racha de 7 días cumpliendo la meta de pasos', 'local_fire_department'),
  ('GYM_RAT', 'Rata de gimnasio', '5 entrenamientos en 7 días', 'fitness_center'),
  ('RUN_FORREST', 'Corre Forrest', 'Corre 5 km en un entrenamiento', 'directions_run'),
  ('DOUBLE_DIGITS', 'Doble dígito', 'Corre 10 km en un entrenamiento', 'directions_run'),
  ('SOFA_DE_ORO', 'Sofá de oro', 'Queda último en pasos 3 días seguidos', 'weekend'),
  ('PERFECT_DAY', 'Día perfecto', 'Meta de pasos + entrenamiento + meta calórica + comidas registradas', 'star'),
  ('SEASON_CHAMPION', 'Campeón de temporada', 'Termina primero en una temporada', 'workspace_premium')
) as v(code, name, description, icon)
where public.achievements.code = v.code;

-- VAMPIRO uses the stored night window (18:00-24:00), not 22:00.
update public.achievements
set metric = 'night_steps', threshold = 5000
where code = 'VAMPIRO';

-- New lifetime-distance achievements.
insert into public.achievements (code, name, description, icon, metric, operator, threshold, time_window, repeatable, hidden, season_points)
values
  ('KM_25', 'Cuarto de maratón', '25 km de por vida', 'route', 'lifetime_distance_m', 'gte', 25000, null, false, false, 0),
  ('KM_50', 'Cincuenta kilómetros', '50 km de por vida', 'route', 'lifetime_distance_m', 'gte', 50000, null, false, false, 0),
  ('KM_100', 'Centenario', '100 km de por vida', 'route', 'lifetime_distance_m', 'gte', 100000, null, false, false, 0),
  ('KM_250', 'Maratonista de maratones', '250 km de por vida', 'route', 'lifetime_distance_m', 'gte', 250000, null, false, false, 0)
on conflict (code) do nothing;

-- Missions: Spanish names, descriptions, and evaluable metrics.
update public.missions m set
  name = v.name,
  description = v.description,
  rules = v.rules,
  reward_points = v.reward_points
from (values
  ('EARLY BIRD', 'Madrugador', '2.500 pasos antes del mediodía',
   '{"metric":"morning_steps","target":2500}'::jsonb, 10),
  ('MORNING PUSH', 'Impulso matutino', '3.500 pasos por la mañana',
   '{"metric":"morning_steps","target":3500}'::jsonb, 10),
  ('BEAT YOURSELF', 'Supérate', 'Supera tu promedio de 14 días en un 20%',
   '{"metric":"vs_14d_avg","target":1.2}'::jsonb, 15),
  ('RUN FORREST', 'Corre Forrest', 'Corre al menos 5 km',
   '{"metric":"workout_distance_m","target":5000}'::jsonb, 10),
  ('ACTIVE DAY', 'Día activo', 'Cumple tu meta de pasos y haz un entrenamiento',
   '{"metric":"active_day","target":1}'::jsonb, 10),
  ('BALANCED DAY', 'Día equilibrado', 'Cumple tu meta de pasos sin pasarte de calorías',
   '{"metric":"balanced_day","target":1}'::jsonb, 10),
  ('THE FOUR', 'Los cuatro', '40.000 pasos entre los 4',
   '{"metric":"steps","target":40000}'::jsonb, 20),
  ('TEAM TRAINING', 'Entreno en equipo', 'Al menos 3 de los 4 hacen un entrenamiento',
   '{"metric":"members_with_workout","target":3}'::jsonb, 20),
  ('LAST CHANCE', 'Última oportunidad', 'La mayor cantidad de pasos en la noche (18:00-24:00)',
   '{"metric":"night_steps","target":1}'::jsonb, 10),
  ('DUEL', 'Duelo matutino', 'La mayor cantidad de pasos en la mañana (06:00-12:00)',
   '{"metric":"morning_steps","target":1}'::jsonb, 10)
) as v(name, description, mission_type_ignored, rules, reward_points)
where m.name = v.name;

-- New km missions.
insert into public.missions (name, description, mission_type, rules, reward_points, starts_at, ends_at)
select * from (values
  ('CAMINA 3 KM', 'Camina 3 km en el día', 'individual',
   '{"metric":"distance_meters","target":3000}'::jsonb, 10,
   '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz),
  ('CORRE 10 KM', 'Corre 10 km en un entrenamiento', 'individual',
   '{"metric":"workout_distance_m","target":10000}'::jsonb, 15,
   '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz),
  ('10 KM DE GRUPO', '10 km de distancia combinada entre los 4', 'cooperative',
   '{"metric":"distance_meters","target":10000}'::jsonb, 20,
   '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz)
) as v(name, description, mission_type, rules, reward_points, starts_at, ends_at)
where not exists (select 1 from public.missions m where m.name = v.name);

-- Battle pass: 10 tiers by season-point thresholds (no payments, single track).
insert into public.battle_pass_tiers (tier, threshold_points, reward_type, reward_key, reward_name, reward_icon)
values
  (1, 10, 'badge', 'badge_iniciado', 'Iniciado del mes', 'military_tech'),
  (2, 25, 'title', 'titulo_caminante', 'Caminante', 'directions_walk'),
  (3, 50, 'emoji', 'emoji_unicornio', 'Emoji exclusivo: 🦄', 'sentiment_satisfied'),
  (4, 80, 'badge', 'badge_mitad', 'Mitad de camino', 'flag'),
  (5, 120, 'title', 'titulo_atleta', 'Atleta del mes', 'sports_gymnastics'),
  (6, 170, 'emoji', 'emoji_corona', 'Emoji exclusivo: 👑', 'emoji_events'),
  (7, 230, 'badge', 'badge_veterano', 'Veterano', 'workspace_premium'),
  (8, 300, 'title', 'titulo_leyenda', 'Leyenda del grupo', 'auto_awesome'),
  (9, 380, 'emoji', 'emoji_fuego', 'Emoji exclusivo: 🔥', 'local_fire_department'),
  (10, 480, 'badge', 'trofeo_maestro', 'Maestro de temporada', 'emoji_events')
on conflict (tier) do nothing;
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/20260811120100_seed_gamification_es.sql
git commit -m "feat(db): Spanish seeds, evaluable mission metrics, km achievements and missions"
```

---

### Task 3: Funciones SQL (rotación diaria, evaluación de misiones, evaluación de logros, reclamación del pase)

**Files:**
- Create: `supabase/migrations/20260811120200_gamification_functions.sql`

**Interfaces:**
- Produces:
  - `public.daily_missions_for_date(p_date date) returns setof missions` — grant `authenticated` + `service_role`.
  - `public.evaluate_missions(p_date date) returns table (mission_id uuid, completed_count integer)` — grant solo `service_role`.
  - `public.evaluate_achievements(p_user_id uuid, p_date date) returns table (achievement_code text)` — grant solo `service_role`.
  - `public.claim_battle_pass_reward(p_season_id uuid, p_tier integer) returns text` (recompensa reclamada o mensaje) — grant `authenticated` + `service_role`.

- [ ] **Step 1: Escribir la migración**

```sql
-- Gamification engine functions. Evaluators are security definer and
-- service-role-only (clients never award points). Claims are the one
-- authenticated entry point. Forward-only.

-- 1) Daily mission rotation: deterministic per date, no storage.
create or replace function public.daily_missions_for_date(p_date date)
returns setof public.missions
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  with pool as (
    select m.*, md5(m.id::text || p_date::text) as sort_key
    from public.missions m
    where m.starts_at::date <= p_date
      and m.ends_at::date >= p_date
  ), ranked as (
    select pool.*, row_number() over (
      partition by pool.mission_type order by pool.sort_key
    ) as rn
    from pool
  )
  select r.id, r.name, r.description, r.mission_type, r.rules,
         r.reward_points, r.starts_at, r.ends_at
  from ranked r
  where (r.mission_type = 'individual' and r.rn <= 2)
     or (r.mission_type = 'cooperative' and r.rn <= 1)
     or (r.mission_type = 'competitive' and r.rn <= 1)
  order by r.mission_type, r.rn;
$$;

grant execute on function public.daily_missions_for_date(date) to authenticated;
grant execute on function public.daily_missions_for_date(date) to service_role;

-- 2) Mission evaluation. Writes mission_progress, awards points on
-- completion, publishes system feed posts. Idempotent via the ledger.
create or replace function public.evaluate_missions(p_date date)
returns table (mission_id uuid, completed_count integer)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_mission record;
  v_profile record;
  v_target numeric;
  v_tz text;
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_metric_value numeric;
  v_avg numeric;
  v_today numeric;
  v_steps numeric;
  v_workouts integer;
  v_consumed numeric;
  v_group_value numeric;
  v_group_members integer;
  v_winner_id uuid;
  v_best numeric;
  v_completed boolean;
  v_season_id uuid;
  v_ref_id uuid;
  v_author uuid;
  v_count integer;
begin
  select config_value into v_tz from public.app_config
  where config_key = 'competition_timezone';
  v_tz := coalesce(v_tz, 'America/Santiago');
  v_day_start := (p_date::text || 'T00:00:00')::timestamp at time zone v_tz;
  v_day_end := ((p_date + 1)::text || 'T00:00:00')::timestamp at time zone v_tz;

  select id into v_season_id
  from public.seasons
  where status = 'active'
    and starts_at <= now()
    and ends_at > now()
  order by starts_at desc
  limit 1;
  if v_season_id is null then
    return;
  end if;

  for v_mission in
    select * from public.daily_missions_for_date(p_date)
  loop
    v_count := 0;

    if v_mission.mission_type = 'cooperative' then
      -- Group row: user_id null, progress_date p_date.
      v_group_value := 0;
      v_group_members := 0;
      select coalesce(sum(a.daily_steps), 0) into v_group_value
      from public.daily_activity a
      where a.activity_date = p_date and a.manual_entry_detected = false;

      if (v_mission.rules->>'metric') = 'distance_meters' then
        select coalesce(sum(a.distance_meters), 0) into v_group_value
        from public.daily_activity a
        where a.activity_date = p_date and a.manual_entry_detected = false;
      end if;
      if (v_mission.rules->>'metric') = 'members_with_workout' then
        select count(distinct w.user_id) into v_group_members
        from public.workouts w
        where w.started_at >= v_day_start and w.started_at < v_day_end;
        v_group_value := v_group_members;
      end if;

      v_completed := v_group_value >= (v_mission.rules->>'target')::numeric;

      insert into public.mission_progress
        (mission_id, user_id, progress_date, progress, completed, completed_at)
      values (
        v_mission.id, null, p_date,
        jsonb_build_object(v_mission.rules->>'metric', v_group_value),
        v_completed, case when v_completed then now() else null end
      )
      on conflict (mission_id, progress_date) where user_id is null
      do update set progress = excluded.progress,
        completed = excluded.completed,
        completed_at = excluded.completed_at;

      if v_completed then
        -- Everyone who contributed earns the reward.
        for v_profile in
          select distinct a.user_id
          from public.daily_activity a
          where a.activity_date = p_date and a.manual_entry_detected = false
          order by a.user_id
        loop
          v_ref_id := public.gen_deterministic_mission_ref(
            v_mission.id, v_profile.user_id, p_date);
          begin
            perform public.award_points(
              v_season_id, v_profile.user_id, v_mission.reward_points,
              'mission', 'mission', v_ref_id);
            v_count := v_count + 1;
          exception when unique_violation then
            null; -- already awarded on a retry
          end;
        end loop;

        if v_count > 0 then
          select user_id into v_author from public.daily_activity
          where activity_date = p_date and manual_entry_detected = false
          order by daily_steps desc nulls last
          limit 1;
          insert into public.posts (author_id, post_type, caption, system_generated)
          values (
            coalesce(v_author, (select id from public.profiles order by created_at limit 1)),
            'mission',
            format('Misión completada: %s (%s puntos)', v_mission.name, v_mission.reward_points),
            true
          );
        end if;
      end if;

      mission_id := v_mission.id;
      completed_count := v_count;
      return next;
      continue;
    end if;

    -- Individual and competitive: per user.
    for v_profile in
      select p.id, p.daily_step_target, p.daily_calorie_target
      from public.profiles p
    loop
      v_metric_value := 0;
      v_completed := false;

      case v_mission.rules->>'metric'
        when 'morning_steps' then
          select coalesce(a.morning_steps, 0) into v_metric_value
          from public.daily_activity a
          where a.user_id = v_profile.id
            and a.activity_date = p_date
            and a.manual_entry_detected = false;
        when 'night_steps' then
          select coalesce(a.night_steps, 0) into v_metric_value
          from public.daily_activity a
          where a.user_id = v_profile.id
            and a.activity_date = p_date
            and a.manual_entry_detected = false;
        when 'distance_meters' then
          select coalesce(a.distance_meters, 0) into v_metric_value
          from public.daily_activity a
          where a.user_id = v_profile.id
            and a.activity_date = p_date
            and a.manual_entry_detected = false;
        when 'workout_distance_m' then
          select coalesce(max(w.distance_meters), 0) into v_metric_value
          from public.workouts w
          where w.user_id = v_profile.id
            and w.started_at >= v_day_start and w.started_at < v_day_end;
        when 'vs_14d_avg' then
          select coalesce(avg(a.daily_steps), 0) into v_avg
          from public.daily_activity a
          where a.user_id = v_profile.id
            and a.activity_date < p_date
            and a.activity_date >= p_date - 14
            and a.manual_entry_detected = false;
          select coalesce(a.daily_steps, 0) into v_today
          from public.daily_activity a
          where a.user_id = v_profile.id
            and a.activity_date = p_date
            and a.manual_entry_detected = false;
          v_metric_value := case when v_avg > 0 then v_today / v_avg else 0 end;
        when 'active_day' then
          select coalesce(a.daily_steps, 0) into v_steps
          from public.daily_activity a
          where a.user_id = v_profile.id
            and a.activity_date = p_date
            and a.manual_entry_detected = false;
          select count(*) into v_workouts
          from public.workouts w
          where w.user_id = v_profile.id
            and w.started_at >= v_day_start and w.started_at < v_day_end;
          v_target := coalesce(v_profile.daily_step_target, 10000);
          v_metric_value := case
            when v_steps >= v_target and v_workouts >= 1 then 1 else 0 end;
        when 'balanced_day' then
          select coalesce(a.daily_steps, 0) into v_steps
          from public.daily_activity a
          where a.user_id = v_profile.id
            and a.activity_date = p_date
            and a.manual_entry_detected = false;
          select coalesce(sum(f.calories), 0) into v_consumed
          from public.food_entries f
          where f.user_id = v_profile.id
            and f.logged_at >= v_day_start and f.logged_at < v_day_end;
          v_target := coalesce(v_profile.daily_step_target, 10000);
          v_metric_value := case
            when v_steps >= v_target
             and v_consumed > 0
             and v_consumed <= coalesce(v_profile.daily_calorie_target, 2200)
            then 1 else 0 end;
        when 'steps' then
          select coalesce(a.daily_steps, 0) into v_metric_value
          from public.daily_activity a
          where a.user_id = v_profile.id
            and a.activity_date = p_date
            and a.manual_entry_detected = false;
        else
          v_metric_value := 0;
      end case;

      if v_mission.mission_type = 'competitive' then
        -- Track the best; completion is decided after the loop.
        if v_metric_value > v_best or v_best is null then
          v_best := v_metric_value;
          v_winner_id := v_profile.id;
        end if;
        -- Record per-user progress so the UI can show the race.
        insert into public.mission_progress
          (mission_id, user_id, progress_date, progress, completed, completed_at)
        values (
          v_mission.id, v_profile.id, p_date,
          jsonb_build_object(v_mission.rules->>'metric', v_metric_value),
          false, null
        )
        on conflict (mission_id, user_id, progress_date) do update
          set progress = excluded.progress;
        continue;
      end if;

      v_completed := v_metric_value >= (v_mission.rules->>'target')::numeric;
      insert into public.mission_progress
        (mission_id, user_id, progress_date, progress, completed, completed_at)
      values (
        v_mission.id, v_profile.id, p_date,
        jsonb_build_object(v_mission.rules->>'metric', v_metric_value),
        v_completed, case when v_completed then now() else null end
      )
      on conflict (mission_id, user_id, progress_date) do update
        set progress = excluded.progress,
            completed = excluded.completed,
            completed_at = excluded.completed_at;

      if v_completed then
        v_ref_id := public.gen_deterministic_mission_ref(
          v_mission.id, v_profile.id, p_date);
        begin
          perform public.award_points(
            v_season_id, v_profile.id, v_mission.reward_points,
            'mission', 'mission', v_ref_id);
          v_count := v_count + 1;
          insert into public.posts (author_id, post_type, caption, system_generated)
          values (
            v_profile.id, 'mission',
            format('Misión completada: %s (%s puntos)', v_mission.name, v_mission.reward_points),
            true
          );
        exception when unique_violation then
          null; -- duplicate award on retry; post already published
        end;
      end if;
    end loop;

    -- Competitive winner resolution.
    if v_mission.mission_type = 'competitive' and v_winner_id is not null then
      insert into public.mission_progress
        (mission_id, user_id, progress_date, progress, completed, completed_at)
      values (
        v_mission.id, v_winner_id, p_date,
        jsonb_build_object(v_mission.rules->>'metric', v_best),
        true, now()
      )
      on conflict (mission_id, user_id, progress_date) do update
        set completed = true, completed_at = excluded.completed_at;

      v_ref_id := public.gen_deterministic_mission_ref(
        v_mission.id, v_winner_id, p_date);
      begin
        perform public.award_points(
          v_season_id, v_winner_id, v_mission.reward_points,
          'mission', 'mission', v_ref_id);
        v_count := v_count + 1;
        insert into public.posts (author_id, post_type, caption, system_generated)
        values (
          v_winner_id, 'mission',
          format('Misión competitiva ganada: %s (%s puntos)', v_mission.name, v_mission.reward_points),
          true
        );
      exception when unique_violation then
        null;
      end;
    end if;

    mission_id := v_mission.id;
    completed_count := v_count;
    return next;
  end loop;
end;
$$;

-- Helper: deterministic reference id for mission awards (idempotent retries).
create or replace function public.gen_deterministic_mission_ref(
  p_mission_id uuid, p_user_id uuid, p_date date
) returns uuid
language sql
immutable
as $$
  select ('00000000-0000-4000-8000-' ||
          substr(md5(p_mission_id::text || p_user_id::text || p_date::text), 1, 12))::uuid;
$$;

grant execute on function public.evaluate_missions(date) to service_role;
grant execute on function public.gen_deterministic_mission_ref(uuid, uuid, date) to service_role;

-- 3) Achievement evaluation for one user.
create or replace function public.evaluate_achievements(p_user_id uuid, p_date date)
returns table (achievement_code text)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_ach record;
  v_metric_value numeric;
  v_season_id uuid;
  v_ref_id uuid;
  v_target_steps numeric;
  v_tz text;
  v_week_start timestamptz;
  v_new_id uuid;
begin
  select config_value into v_tz from public.app_config
  where config_key = 'competition_timezone';
  v_tz := coalesce(v_tz, 'America/Santiago');
  v_week_start := ((p_date - 6)::text || 'T00:00:00')::timestamp at time zone v_tz;

  select id into v_season_id
  from public.seasons
  where status = 'active'
    and starts_at <= now()
    and ends_at > now()
  order by starts_at desc
  limit 1;

  select coalesce(p.daily_step_target, 10000) into v_target_steps
  from public.profiles p where p.id = p_user_id;

  for v_ach in select * from public.achievements order by threshold
  loop
    case v_ach.metric
      when 'workouts_synced' then
        select count(*) into v_metric_value from public.workouts
        where user_id = p_user_id;
      when 'daily_steps' then
        select coalesce(max(a.daily_steps), 0) into v_metric_value
        from public.daily_activity a
        where a.user_id = p_user_id and a.manual_entry_detected = false;
      when 'night_steps' then
        select coalesce(max(a.night_steps), 0) into v_metric_value
        from public.daily_activity a
        where a.user_id = p_user_id and a.manual_entry_detected = false;
      when 'morning_round_wins' then
        select count(*) into v_metric_value from public.season_points sp
        where sp.user_id = p_user_id and sp.reason = 'morning_round_win';
      when 'rounds_and_total_wins' then
        with wins as (
          select sp.reference_id, sp.reason, sp.created_at::date as d
          from public.season_points sp
          where sp.user_id = p_user_id
            and sp.reason in ('morning_round_win', 'afternoon_round_win', 'night_round_win')
        ), day_wins as (
          select d, count(*) as n from wins group by d
        ), days_total as (
          select a.activity_date as d, a.daily_steps,
                 row_number() over (partition by a.activity_date
                   order by a.daily_steps desc) as rn
          from public.daily_activity a
          where a.user_id = p_user_id and a.manual_entry_detected = false
        )
        select count(*) into v_metric_value
        from day_wins dw
        join days_total dt on dt.d = dw.d and dt.rn = 1
        where dw.n = 3;
      when 'step_goal_streak' then
        select coalesce(max(current_count), 0) into v_metric_value
        from public.streaks where user_id = p_user_id and streak_type = 'step_goal';
      when 'workouts_7d' then
        select count(*) into v_metric_value
        from public.workouts w
        where w.user_id = p_user_id and w.started_at >= v_week_start;
      when 'workout_distance_m' then
        select coalesce(max(w.distance_meters), 0) into v_metric_value
        from public.workouts w where w.user_id = p_user_id;
      when 'last_place_streak' then
        with daily_ranks as (
          select a.activity_date as d,
                 row_number() over (partition by a.activity_date
                   order by a.daily_steps desc, a.user_id) as rn,
                 count(*) over (partition by a.activity_date) as participants
          from public.daily_activity a
          where a.manual_entry_detected = false
        ), user_last_days as (
          select d from daily_ranks dr
          where dr.rn = dr.participants
            and exists (
              select 1 from public.daily_activity a
              where a.activity_date = dr.d and a.user_id = p_user_id
                and a.manual_entry_detected = false
            )
        ), grouped as (
          select d, d - (row_number() over (order by d))::int as grp
          from user_last_days
        )
        select coalesce(max(c), 0) into v_metric_value
        from (select count(*) as c from grouped group by grp) t;
      when 'perfect_day' then
        with days as (
          select a.activity_date as d,
                 a.daily_steps >= v_target_steps as step_ok,
                 exists (
                   select 1 from public.workouts w
                   where w.user_id = a.user_id
                     and w.started_at >= (a.activity_date::text || 'T00:00:00')::timestamp at time zone v_tz
                     and w.started_at < ((a.activity_date + 1)::text || 'T00:00:00')::timestamp at time zone v_tz
                 ) as workout_ok,
                 coalesce((
                   select sum(f.calories) from public.food_entries f
                   where f.user_id = a.user_id
                     and f.logged_at >= (a.activity_date::text || 'T00:00:00')::timestamp at time zone v_tz
                     and f.logged_at < ((a.activity_date + 1)::text || 'T00:00:00')::timestamp at time zone v_tz
                 ), 0) as consumed,
                 coalesce((select p.daily_calorie_target from public.profiles p
                           where p.id = a.user_id), 2200) as cal_target
          from public.daily_activity a
          where a.user_id = p_user_id and a.manual_entry_detected = false
        )
        select count(*) into v_metric_value
        from days
        where step_ok and workout_ok
          and consumed > 0 and consumed <= cal_target;
      when 'season_wins' then
        select count(*) into v_metric_value from public.season_results sr
        where sr.user_id = p_user_id and sr.position = 1;
      when 'lifetime_distance_m' then
        select coalesce(sum(a.distance_meters), 0) into v_metric_value
        from public.daily_activity a
        where a.user_id = p_user_id and a.manual_entry_detected = false;
      else
        v_metric_value := 0;
    end case;

    if v_metric_value >= v_ach.threshold then
      v_new_id := null;
      insert into public.user_achievements (user_id, achievement_id, context)
      values (
        p_user_id, v_ach.id,
        jsonb_build_object('metric', v_ach.metric, 'value', v_metric_value)
      )
      on conflict (user_id, achievement_id) do nothing
      returning id into v_new_id;

      if v_new_id is not null then
        if v_ach.season_points > 0 and v_season_id is not null then
          v_ref_id := ('00000000-0000-4000-8000-' ||
            substr(md5('achievement:' || v_ach.code || ':' || p_user_id::text), 1, 12))::uuid;
          begin
            perform public.award_points(
              v_season_id, p_user_id, v_ach.season_points,
              'achievement', 'achievement', v_ref_id);
          exception when unique_violation then
            null;
          end;
        end if;
        insert into public.posts (author_id, post_type, caption, achievement_id, system_generated)
        values (
          p_user_id, 'achievement',
          format('Logro desbloqueado: %s', v_ach.name),
          v_ach.id, true
        );
        achievement_code := v_ach.code;
        return next;
      end if;
    end if;
  end loop;
end;
$$;

grant execute on function public.evaluate_achievements(uuid, date) to service_role;

-- 4) Battle pass claim: verifies the threshold against the ledger, records
-- the claim, applies title rewards. Authenticated users may call this.
create or replace function public.claim_battle_pass_reward(
  p_season_id uuid,
  p_tier integer
)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_total numeric;
  v_tier record;
  v_claim_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select coalesce(sum(sp.points), 0) into v_total
  from public.season_points sp
  where sp.season_id = p_season_id and sp.user_id = v_user_id;

  select * into v_tier from public.battle_pass_tiers where tier = p_tier;
  if v_tier.id is null then
    raise exception 'Unknown battle pass tier' using errcode = 'check_violation';
  end if;
  if v_total < v_tier.threshold_points then
    raise exception 'Threshold not reached'
      using errcode = 'check_violation';
  end if;

  select id into v_claim_id from public.battle_pass_claims
  where season_id = p_season_id and user_id = v_user_id and tier = p_tier;
  if v_claim_id is not null then
    return 'already_claimed';
  end if;

  insert into public.battle_pass_claims (season_id, user_id, tier)
  values (p_season_id, v_user_id, p_tier);

  if v_tier.reward_type = 'title' then
    update public.profiles
    set profile_title = v_tier.reward_name
    where id = v_user_id;
  end if;

  return 'claimed:' || v_tier.reward_type;
end;
$$;

grant execute on function public.claim_battle_pass_reward(uuid, integer) to authenticated;
grant execute on function public.claim_battle_pass_reward(uuid, integer) to service_role;
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/20260811120200_gamification_functions.sql
git commit -m "feat(db): daily rotation, mission/achievement evaluation, battle pass claims"
```

---

### Task 4: Extender `close_day` (Deno)

**Files:**
- Modify: `supabase/functions/close_day/index.ts` (añadir evaluación tras el bucle de rachas, antes del post diario)

**Interfaces:**
- Consumes: `public.evaluate_missions(date)`, `public.evaluate_achievements(uuid, date)` (Task 3).
- Produces: puntos de misiones/logros y posts de sistema generados al cierre del día.

- [ ] **Step 1: Añadir el bloque de evaluación**

Insertar tras el bloque de rachas (después de la línea con `onConflict: "user_id,streak_type"` y su `}`), antes del comentario `// Publish the daily result post.`:

```ts
  // Evaluate the day's rotating missions and lifetime achievements.
  // Both functions are idempotent through the ledger; retries are safe.
  const { error: missionErr } = await supabaseAdmin.rpc("evaluate_missions", {
    p_date: competitionDate,
  });
  if (missionErr) throw new Error(`mission evaluation failed: ${missionErr.message}`);

  const { data: allProfiles, error: profilesErr } = await supabaseAdmin
    .from("profiles")
    .select("id");
  if (profilesErr) throw new Error(`profiles read failed: ${profilesErr.message}`);
  for (const profile of allProfiles ?? []) {
    const { error: achErr } = await supabaseAdmin.rpc("evaluate_achievements", {
      p_user_id: profile.id,
      p_date: competitionDate,
    });
    if (achErr) throw new Error(`achievement evaluation failed: ${achErr.message}`);
  }
```

- [ ] **Step 2: Verificar sintaxis TypeScript**

Run: `npx --yes esbuild supabase/functions/close_day/index.ts --bundle --format=esm --external:@supabase/* --external:jsr:* --outfile=$env:TEMP\close_day_bundle.js` — Expected: sin errores de sintaxis (bundle generado; los imports de runtime quedan externos). Es aceptable que el bundle no se ejecute aquí.

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/close_day/index.ts
git commit -m "feat: close_day evaluates daily missions and achievements"
```

---

### Task 5: Modelos de dominio de juego (Flutter)

**Files:**
- Modify: `lib/features/game/domain/game_models.dart`

**Interfaces:**
- Produces (usadas por Tasks 6-8):
  - `Mission {String id, String name, String description, String missionType, Map<String,dynamic> rules, int rewardPoints}` + `fromJson`
  - `MissionProgress {String missionId, String? userId, String? progressDate, Map<String,dynamic> progress, bool completed, DateTime? completedAt}` + `fromJson` + `double valueOf(String metric)` + `double targetOf(Map rules)`
  - `Achievement {String id, String code, String name, String description, String icon, bool hidden}` + `fromJson`
  - `UserAchievement {String achievementId, DateTime unlockedAt}` + `fromJson`
  - `Streak {String streakType, int currentCount, int longestCount, DateTime? lastQualifiedDate}` + `fromJson`
  - `BattlePassTier {int tier, int thresholdPoints, String rewardType, String rewardKey, String rewardName, String rewardIcon}` + `fromJson`
  - `BattlePassClaim {int tier, DateTime claimedAt}` + `fromJson`
  - `SeasonResult {String seasonId, String seasonName, int position, double points}` + `fromJson`
  - `SeasonKm {String userId, String displayName, double km}` + `fromJson`

- [ ] **Step 1: Escribir los modelos**

Añadir al final de `game_models.dart` (conservando `SeasonStanding` y `Season`):

```dart
class Mission {
  const Mission({required this.id, required this.name, required this.description,
    required this.missionType, required this.rules, required this.rewardPoints});

  factory Mission.fromJson(Map<String, dynamic> json) => Mission(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Misión',
        description: (json['description'] as String?) ?? '',
        missionType: (json['mission_type'] as String?) ?? 'individual',
        rules: (json['rules'] as Map<String, dynamic>?) ?? const {},
        rewardPoints: ((json['reward_points'] as num?) ?? 0).toInt(),
      );

  final String id;
  final String name;
  final String description;
  final String missionType;
  final Map<String, dynamic> rules;
  final int rewardPoints;
}

class MissionProgress {
  const MissionProgress({required this.missionId, this.userId, this.progressDate,
    required this.progress, required this.completed, this.completedAt});

  factory MissionProgress.fromJson(Map<String, dynamic> json) => MissionProgress(
        missionId: json['mission_id'] as String,
        userId: json['user_id'] as String?,
        progressDate: json['progress_date'] as String?,
        progress: (json['progress'] as Map<String, dynamic>?) ?? const {},
        completed: (json['completed'] as bool?) ?? false,
        completedAt: json['completed_at'] == null
            ? null
            : DateTime.parse(json['completed_at'] as String),
      );

  final String missionId;
  final String? userId;
  final String? progressDate;
  final Map<String, dynamic> progress;
  final bool completed;
  final DateTime? completedAt;

  double valueOf(String metric) => (progress[metric] as num?)?.toDouble() ?? 0;
}

class Achievement {
  const Achievement({required this.id, required this.code, required this.name,
    required this.description, required this.icon, required this.hidden});

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'] as String,
        code: (json['code'] as String?) ?? '',
        name: (json['name'] as String?) ?? 'Logro',
        description: (json['description'] as String?) ?? '',
        icon: (json['icon'] as String?) ?? 'military_tech',
        hidden: (json['hidden'] as bool?) ?? false,
      );

  final String id;
  final String code;
  final String name;
  final String description;
  final String icon;
  final bool hidden;
}

class UserAchievement {
  const UserAchievement({required this.achievementId, required this.unlockedAt});

  factory UserAchievement.fromJson(Map<String, dynamic> json) => UserAchievement(
        achievementId: json['achievement_id'] as String,
        unlockedAt: DateTime.parse(json['unlocked_at'] as String),
      );

  final String achievementId;
  final DateTime unlockedAt;
}

class Streak {
  const Streak({required this.streakType, required this.currentCount,
    required this.longestCount, this.lastQualifiedDate});

  factory Streak.fromJson(Map<String, dynamic> json) => Streak(
        streakType: (json['streak_type'] as String?) ?? '',
        currentCount: ((json['current_count'] as num?) ?? 0).toInt(),
        longestCount: ((json['longest_count'] as num?) ?? 0).toInt(),
        lastQualifiedDate: json['last_qualified_date'] == null
            ? null
            : DateTime.parse(json['last_qualified_date'] as String),
      );

  final String streakType;
  final int currentCount;
  final int longestCount;
  final DateTime? lastQualifiedDate;
}

class BattlePassTier {
  const BattlePassTier({required this.tier, required this.thresholdPoints,
    required this.rewardType, required this.rewardKey, required this.rewardName,
    required this.rewardIcon});

  factory BattlePassTier.fromJson(Map<String, dynamic> json) => BattlePassTier(
        tier: ((json['tier'] as num?) ?? 0).toInt(),
        thresholdPoints: ((json['threshold_points'] as num?) ?? 0).toInt(),
        rewardType: (json['reward_type'] as String?) ?? 'badge',
        rewardKey: (json['reward_key'] as String?) ?? '',
        rewardName: (json['reward_name'] as String?) ?? '',
        rewardIcon: (json['reward_icon'] as String?) ?? 'military_tech',
      );

  final int tier;
  final int thresholdPoints;
  final String rewardType;
  final String rewardKey;
  final String rewardName;
  final String rewardIcon;
}

class BattlePassClaim {
  const BattlePassClaim({required this.tier, required this.claimedAt});

  factory BattlePassClaim.fromJson(Map<String, dynamic> json) => BattlePassClaim(
        tier: ((json['tier'] as num?) ?? 0).toInt(),
        claimedAt: DateTime.parse(json['claimed_at'] as String),
      );

  final int tier;
  final DateTime claimedAt;
}

class SeasonResult {
  const SeasonResult({required this.seasonId, required this.seasonName,
    required this.position, required this.points});

  factory SeasonResult.fromJson(Map<String, dynamic> json) => SeasonResult(
        seasonId: json['season_id'] as String,
        seasonName: (json['season_name'] as String?) ?? 'Temporada',
        position: ((json['position'] as num?) ?? 0).toInt(),
        points: ((json['points'] as num?) ?? 0).toDouble(),
      );

  final String seasonId;
  final String seasonName;
  final int position;
  final double points;
}

class SeasonKm {
  const SeasonKm({required this.userId, required this.displayName, required this.km});

  factory SeasonKm.fromJson(Map<String, dynamic> json) => SeasonKm(
        userId: json['user_id'] as String,
        displayName: (json['display_name'] as String?) ?? 'Desconocido',
        km: ((json['km'] as num?) ?? 0).toDouble(),
      );

  final String userId;
  final String displayName;
  final double km;
}
```

- [ ] **Step 2: Verificar con analyze**

Run: `flutter analyze` — Expected: sin errores nuevos.

- [ ] **Step 3: Commit**

```bash
git add lib/features/game/domain/game_models.dart
git commit -m "feat: game domain models for missions, achievements, streaks, battle pass"
```

---

### Task 6: Repositorio de juego ampliado (Flutter)

**Files:**
- Modify: `lib/features/game/data/supabase_game_repository.dart`

**Interfaces:**
- Consumes: modelos de Task 5, `AppEnvironment.competitionTz` de `lib/shared/config/app_environment.dart`.
- Produces (usadas por Task 7 JUEGO y Task 8 celebraciones):
  - `Future<List<Mission>> dailyMissionsFor(DateTime date)`
  - `Future<List<MissionProgress>> missionProgressFor(DateTime date)`
  - `Future<List<Achievement>> achievements()`
  - `Future<List<UserAchievement>> userAchievements(String userId)`
  - `Future<List<Streak>> streaksFor(String userId)`
  - `Future<List<BattlePassTier>> battlePassTiers()`
  - `Future<List<BattlePassClaim>> battlePassClaims(String userId, String seasonId)`
  - `Future<String> claimBattlePassReward(String seasonId, int tier)`
  - `Future<List<SeasonResult>> seasonHistory()`
  - `Future<List<SeasonKm>> seasonKm(Season season)`

- [ ] **Step 1: Escribir los métodos**

```dart
  Future<List<Mission>> dailyMissionsFor(DateTime date) async {
    final rows = await _client.rpc('daily_missions_for_date', params: {
      'p_date': _dateParam(date),
    });
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Mission.fromJson)
        .toList(growable: false);
  }

  Future<List<MissionProgress>> missionProgressFor(DateTime date) async {
    final rows = await _client
        .from('mission_progress')
        .select('mission_id, user_id, progress_date, progress, completed, completed_at')
        .eq('progress_date', _dateParam(date));
    return rows
        .cast<Map<String, dynamic>>()
        .map(MissionProgress.fromJson)
        .toList(growable: false);
  }

  Future<List<Achievement>> achievements() async {
    final rows = await _client
        .from('achievements')
        .select('id, code, name, description, icon, hidden')
        .order('threshold');
    return rows
        .cast<Map<String, dynamic>>()
        .map(Achievement.fromJson)
        .toList(growable: false);
  }

  Future<List<UserAchievement>> userAchievements(String userId) async {
    final rows = await _client
        .from('user_achievements')
        .select('achievement_id, unlocked_at')
        .eq('user_id', userId);
    return rows
        .cast<Map<String, dynamic>>()
        .map(UserAchievement.fromJson)
        .toList(growable: false);
  }

  Future<List<Streak>> streaksFor(String userId) async {
    final rows = await _client
        .from('streaks')
        .select('streak_type, current_count, longest_count, last_qualified_date')
        .eq('user_id', userId)
        .order('current_count', ascending: false);
    return rows
        .cast<Map<String, dynamic>>()
        .map(Streak.fromJson)
        .toList(growable: false);
  }

  Future<List<BattlePassTier>> battlePassTiers() async {
    final rows = await _client
        .from('battle_pass_tiers')
        .select('tier, threshold_points, reward_type, reward_key, reward_name, reward_icon')
        .order('tier');
    return rows
        .cast<Map<String, dynamic>>()
        .map(BattlePassTier.fromJson)
        .toList(growable: false);
  }

  Future<List<BattlePassClaim>> battlePassClaims(String userId, String seasonId) async {
    final rows = await _client
        .from('battle_pass_claims')
        .select('tier, claimed_at')
        .eq('user_id', userId)
        .eq('season_id', seasonId);
    return rows
        .cast<Map<String, dynamic>>()
        .map(BattlePassClaim.fromJson)
        .toList(growable: false);
  }

  Future<String> claimBattlePassReward(String seasonId, int tier) async {
    final result = await _client.rpc('claim_battle_pass_reward', params: {
      'p_season_id': seasonId,
      'p_tier': tier,
    });
    return result as String;
  }

  Future<List<SeasonResult>> seasonHistory() async {
    final rows = await _client
        .from('season_results')
        .select('season_id, position, points, seasons(name)');
    return rows.cast<Map<String, dynamic>>().map((row) {
      final season = (row['seasons'] as Map<String, dynamic>?) ?? const {};
      return SeasonResult(
        seasonId: row['season_id'] as String,
        seasonName: (season['name'] as String?) ?? 'Temporada',
        position: ((row['position'] as num?) ?? 0).toInt(),
        points: ((row['points'] as num?) ?? 0).toDouble(),
      );
    }).toList(growable: false);
  }

  Future<List<SeasonKm>> seasonKm(Season season) async {
    final rows = await _client
        .from('daily_activity')
        .select('user_id, sum:distance_meters')
        .gte('activity_date', _utcDate(season.startsAt))
        .lte('activity_date', _utcDate(season.endsAt))
        .eq('manual_entry_detected', false);
    final aggregated = <String, double>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      aggregated[row['user_id'] as String] =
          ((row['sum'] as num?) ?? 0).toDouble();
    }
    if (aggregated.isEmpty) return const [];
    final names = <String, String>{};
    final profileRows = await _client
        .from('profiles')
        .select('id, display_name');
    for (final row in profileRows.cast<Map<String, dynamic>>()) {
      names[row['id'] as String] = (row['display_name'] as String?) ?? 'Desconocido';
    }
    final result = aggregated.entries
        .map((e) => SeasonKm(
          userId: e.key,
          displayName: names[e.key] ?? 'Desconocido',
          km: e.value / 1000,
        ))
        .toList();
    result.sort((a, b) => b.km.compareTo(a.km));
    return result;
  }
```

Añadir los helpers privados:

```dart
  // 'yyyy-MM-dd' del valor DateTime recibido (ya en TZ de competencia o UTC).
  String _dateParam(DateTime date) {
    final d = date.toUtc();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  // Los cortes de temporada se crean a medianoche en competition_timezone,
  // por lo que la fecha UTC coincide con la fecha de competencia.
  String _utcDate(DateTime date) {
    final d = date.toUtc();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

- [ ] **Step 2: Verificar**

Run: `flutter analyze` — Expected: sin errores.

- [ ] **Step 3: Commit**

```bash
git add lib/features/game/data/supabase_game_repository.dart
git commit -m "feat: game repository reads missions, achievements, streaks, battle pass"
```

---

### Task 7: Pantalla JUEGO con datos reales (Flutter)

**Files:**
- Modify: `lib/features/game/presentation/game_tab.dart` (reescritura)
- Test: `test/game_tab_test.dart` (nuevo)

**Interfaces:**
- Consumes: Task 5 modelos, Task 6 repositorio.
- Produces: `GameTab({super.key, this.loadFromBackend = true})` — cuando es `false`, el widget NO toca Supabase y muestra un `GameSnapshot` inyectado (contrato de prueba).

- [ ] **Step 1: Escribir el test primero (TDD)**

```dart
// test/game_tab_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/game/domain/game_models.dart';
import 'package:enfermicambio/features/game/presentation/game_tab.dart';

GameSnapshot buildSnapshot() => const GameSnapshot(
      seasonName: 'Temporada Agosto 2026',
      seasonStatus: 'active',
      standings: [
        SeasonStanding(seasonId: 's1', userId: 'u1', displayName: 'Freddy', totalPoints: 120, position: 1),
        SeasonStanding(seasonId: 's1', userId: 'u2', displayName: 'Felipe', totalPoints: 90, position: 2),
      ],
      missions: [
        Mission(id: 'm1', name: 'Madrugador', description: '2.500 pasos antes del mediodía',
          missionType: 'individual', rules: {'metric': 'morning_steps', 'target': 2500}, rewardPoints: 10),
      ],
      missionProgress: {
        'm1': MissionProgress(missionId: 'm1', progressDate: '2026-08-11',
          progress: {'morning_steps': 1250}, completed: false),
      },
      achievements: [
        Achievement(id: 'a1', code: '5K_CLUB', name: 'Club 5K', description: '5.000 pasos en un día',
          icon: 'directions_walk', hidden: false),
      ],
      unlockedAchievements: ['a1'],
      streaks: [Streak(streakType: 'step_goal', currentCount: 3, longestCount: 7)],
      battlePassTiers: [
        BattlePassTier(tier: 1, thresholdPoints: 10, rewardType: 'badge', rewardKey: 'badge_1',
          rewardName: 'Iniciado del mes', rewardIcon: 'military_tech'),
      ],
      battlePassClaims: [],
      seasonKm: [SeasonKm(userId: 'u1', displayName: 'Freddy', km: 42.5)],
    );

void main() {
  testWidgets('JUEGO muestra misiones reales con progreso', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GameTab(loadFromBackend: false, snapshot: buildSnapshot()),
    ));
    expect(find.text('Misiones del Día'), findsOneWidget);
    expect(find.text('Madrugador'), findsOneWidget);
    expect(find.textContaining('1,250'), findsOneWidget);
  });

  testWidgets('JUEGO muestra logros desbloqueados y bloqueados', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GameTab(loadFromBackend: false, snapshot: buildSnapshot()),
    ));
    expect(find.text('Club 5K'), findsOneWidget);
    expect(find.text('Pase de Batalla'), findsOneWidget);
    expect(find.text('Iniciado del mes'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar el test y verificar que falla**

Run: `flutter test test/game_tab_test.dart` — Expected: FAIL (GameSnapshot no existe).

- [ ] **Step 3: Reescribir `game_tab.dart`**

Estructura (los detalles visuales siguen el tema existente `AppColors`):

```dart
class GameSnapshot {
  const GameSnapshot({this.seasonName, this.seasonStatus, this.standings = const [],
    this.missions = const [], this.missionProgress = const {}, this.achievements = const [],
    this.unlockedAchievements = const {}, this.streaks = const [], this.battlePassTiers = const [],
    this.battlePassClaims = const {}, this.seasonKm = const [], this.totalPoints = 0,
    this.myPosition});
  final String? seasonName;
  final String? seasonStatus;
  final List<SeasonStanding> standings;
  final List<Mission> missions;
  final Map<String, MissionProgress> missionProgress; // por missionId
  final List<Achievement> achievements;
  final Set<String> unlockedAchievements; // por achievementId
  final List<Streak> streaks;
  final List<BattlePassTier> battlePassTiers;
  final Set<int> battlePassClaims; // tiers reclamados
  final List<SeasonKm> seasonKm;
  final double totalPoints;
  final int? myPosition;
}

class GameTab extends StatefulWidget {
  const GameTab({super.key, this.loadFromBackend = true, this.snapshot});
  final bool loadFromBackend;
  final GameSnapshot? snapshot;
  ...
}
```

El State, cuando `loadFromBackend == true`, carga en paralelo: season + standings + dailyMissionsFor(hoy competencia) + missionProgressFor + achievements + userAchievements(me) + streaksFor(me) + battlePassTiers + battlePassClaims + seasonKm + seasonHistory, y construye `GameSnapshot` con la lógica:

- `missionProgress` map: para misiones individuales/competitivas la fila con `userId == me`; para cooperativas la fila con `userId == null` (el `where user_id is null` no funciona con `eq`, usar `.isFilter('user_id', null)` en Supabase para cooperativas).
- `unlockedAchievements`: ids de `userAchievements`.
- `battlePassClaims`: tiers de claims.
- `myPosition`: standings.firstWhere(userId == me).
- `totalPoints`: el total del usuario desde standings.

Widgets de sección (orden en la ListView):
1. `_SectionHeader('Pase de Batalla', Icons.military_tech)` + `_BattlePassTrack`: fila horizontal de `_TierChip` (nivel, umbral, icono, estado: reclamado ✓ / alcanzado con botón Reclamar / bloqueado) + barra de progreso `totalPoints / próximo umbral` + texto "X pts de la temporada · posición #N".
2. `_SectionHeader('Misiones del Día', Icons.assignment_turned_in)` + `_MissionCard` por misión (barra `progress / target`, botón/comentario "Completada ✓" cuando `completed`), recompensa `+N pts`, icono por tipo (individual: Icons.person, cooperativa: Icons.group, competitiva: Icons.emoji_events).
3. `_SectionHeader('Rachas', Icons.local_fire_department)` + tarjeta de `step_goal`: "Meta de pasos · X días seguidos" y "Récord: Y días".
4. `_SectionHeader('Logros', Icons.military_tech)` + GridView (3 columnas) de `_BadgeTile`: desbloqueado (color dorado/púrpura) / bloqueado visible (gris) / secreto bloqueado (candado). Tooltip con descripción.
5. `_SectionHeader('Tabla de Puntos', Icons.leaderboard)` + `_StandingCard`s (existentes).
6. `_SectionHeader('Kilómetros de la Temporada', Icons.route)` + filas `_KmCard` (displayName, km con 1 decimal).
7. `_SectionHeader('Historial de Temporadas', Icons.history)` + filas de `_SeasonResultCard` (nombre, posición #N, puntos) — solo si hay historial.

Celebración (Task 8) se integra aquí con un `StreamSubscription` que opcionalmente muestra un SnackBar.

- [ ] **Step 4: Ejecutar el test y verificar que pasa**

Run: `flutter test test/game_tab_test.dart` — Expected: PASS.

- [ ] **Step 5: Verificar suite completa**

Run: `flutter analyze; flutter test` — Expected: todo limpio.

- [ ] **Step 6: Commit**

```bash
git add lib/features/game/presentation/game_tab.dart test/game_tab_test.dart
git commit -m "feat: JUEGO shows real missions, achievements, streaks, battle pass, km, history"
```

---

### Task 8: Celebraciones in-app vía Realtime (Flutter)

**Files:**
- Modify: `lib/features/game/presentation/game_tab.dart` (State), `lib/features/game/data/supabase_game_repository.dart`

**Interfaces:**
- Consumes: `Supabase.instance.client.channel(...)` patrón ya usado en feed; modelos Task 5.
- Produces: SnackBar animado "¡Logro desbloqueado: X!" o "¡Misión completada: X!" + refetch de `_load()`.

- [ ] **Step 1: Añadir la suscripción**

En `_GameTabState`, solo cuando `widget.loadFromBackend == true`:

```dart
  StreamSubscription? _celebrationSub;

  void _subscribeCelebrations() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final channel = Supabase.instance.client.channel('game-celebrations');
    _celebrationSub = channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'user_achievements',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) async {
            final achievementId = (payload.newRecord['achievement_id'] as String?) ?? '';
            if (achievementId.isEmpty || !mounted) return;
            final name = _snapshot?.achievements
                .where((a) => a.id == achievementId)
                .map((a) => a.name)
                .firstOrNull;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('¡Logro desbloqueado: ${name ?? "Nuevo logro"}! 🏅'),
              duration: const Duration(seconds: 4),
            ));
            _load();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mission_progress',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) async {
            final completed = (payload.newRecord['completed'] as bool?) ?? false;
            if (!completed || !mounted) return;
            final missionId = (payload.newRecord['mission_id'] as String?) ?? '';
            final name = _snapshot?.missions
                .where((m) => m.id == missionId)
                .map((m) => m.name)
                .firstOrNull;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('¡Misión completada: ${name ?? "Misión"}! 🎉'),
              duration: const Duration(seconds: 4),
            ));
            _load();
          },
        )
        .subscribe();
  }
```

En `dispose()`: `_celebrationSub?.cancel();` y `Supabase.instance.client.removeChannel(channel)` (guardar referencia al channel). Llamar `_subscribeCelebrations()` en `initState` tras `_load()`.

- [ ] **Step 2: Verificar**

Run: `flutter analyze` — Expected: limpio. (El comportamiento realtime no se testea en widget tests.)

- [ ] **Step 3: Commit**

```bash
git add lib/features/game/presentation/game_tab.dart
git commit -m "feat: in-app celebrations on achievement unlock and mission completion"
```

---

### Task 9: RANKING con datos reales por categoría y período (Flutter)

**Files:**
- Create: `lib/features/ranking/data/ranking_repository.dart`
- Modify: `lib/features/ranking/domain/ranking_models.dart` (mover los enums `RankingCategory`/`RankingTimePeriod` aquí desde el widget para evitar que `data` importe `presentation`)
- Modify: `lib/features/ranking/presentation/ranking_tab.dart`
- Test: `test/ranking_tab_test.dart` (ampliar)

**Interfaces:**
- Consumes: `RankingRow`/`UserFreshness` (existentes), `AppEnvironment.competitionTz`.
- Produces:
  - `class RankingRepository { RankingRepository({required SupabaseClient client}); Future<List<RankingRow>> load({required RankingCategory category, required RankingTimePeriod period, required DateTime now}); }`

- [ ] **Step 1: Escribir el repositorio**

```dart
// lib/features/ranking/data/ranking_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/ranking_models.dart'; // incluye RankingCategory, RankingTimePeriod

class RankingRepository {
  RankingRepository({required SupabaseClient client}) : _client = client;
  final SupabaseClient _client;

  Future<List<RankingRow>> load({
    required RankingCategory category,
    required RankingTimePeriod period,
    required DateTime now,
  }) async {
    final profiles = await _client.from('profiles').select('id, display_name, avatar_url');
    final users = profiles.cast<Map<String, dynamic>>().toList();

    final (start, end) = await _rangeFor(period, now);
    final activity = await _client
        .from('daily_activity')
        .select('user_id, activity_date, daily_steps, morning_steps, afternoon_steps, night_steps, active_calories, distance_meters, synced_at')
        .gte('activity_date', _date(start))
        .lte('activity_date', _date(end))
        .eq('manual_entry_detected', false);

    final workouts = (category == RankingCategory.entrenamientos)
        ? await _client.from('workouts').select('user_id')
            .gte('started_at', start.toUtc().toIso8601String())
            .lte('started_at', end.toUtc().toIso8601String())
        : null;

    final seasonStandings = (category == RankingCategory.puntos && period == RankingTimePeriod.temporada)
        ? await _client.from('season_standings').select('user_id, total_points, position')
        : null;

    final pointsRows = (category == RankingCategory.puntos && period != RankingTimePeriod.temporada)
        ? await _client.from('season_points')
            .select('user_id, points, created_at')
            .gte('created_at', start.toUtc().toIso8601String())
            .lte('created_at', end.toUtc().toIso8601String())
        : null;

    final values = <String, double>{};
    final synced = <String, DateTime>{};
    for (final row in activity.cast<Map<String, dynamic>>()) {
      final userId = row['user_id'] as String;
      final s = DateTime.parse(row['synced_at'] as String);
      final cur = synced[userId];
      if (cur == null || s.isAfter(cur)) synced[userId] = s;
      final metric = switch (category) {
        RankingCategory.pasos => (row['daily_steps'] as num).toDouble(),
        RankingCategory.franjas => _windowSteps(row, now),
        RankingCategory.distancia => (row['distance_meters'] as num?)?.toDouble() ?? 0,
        RankingCategory.entrenamientos => 0,
        RankingCategory.calorias => (row['active_calories'] as num?)?.toDouble() ?? 0,
        RankingCategory.puntos => 0,
      };
      values[userId] = (values[userId] ?? 0) + metric;
    }

    if (workouts != null) {
      for (final row in workouts.cast<Map<String, dynamic>>()) {
        final userId = row['user_id'] as String;
        values[userId] = (values[userId] ?? 0) + 1;
      }
    }
    if (seasonStandings != null) {
      for (final row in seasonStandings.cast<Map<String, dynamic>>()) {
        values[row['user_id'] as String] = ((row['total_points'] as num?) ?? 0).toDouble();
      }
    }
    if (pointsRows != null) {
      for (final row in pointsRows.cast<Map<String, dynamic>>()) {
        final userId = row['user_id'] as String;
        values[userId] = (values[userId] ?? 0) + ((row['points'] as num?) ?? 0).toDouble();
      }
    }

    final sortedIds = values.keys.toList()
      ..sort((a, b) => values[b]!.compareTo(values[a]!));
    final rankByUser = <String, int>{};
    for (var i = 0; i < sortedIds.length; i++) {
      rankByUser[sortedIds[i]] = i + 1;
    }

    final ranked = users.map((profile) {
      final userId = profile['id'] as String;
      final s = synced[userId];
      return RankingRow(
        userId: userId,
        displayName: (profile['display_name'] as String?) ?? 'Desconocido',
        avatarUrl: profile['avatar_url'] as String?,
        value: values[userId] ?? 0,
        freshness: s == null ? UserFreshness.missing : UserFreshness.fresh,
        rank: rankByUser[userId] ?? values.length + 1,
        lastSyncedAt: s,
      );
    }).toList();
    ranked.sort((a, b) => a.rank.compareTo(b.rank));
    return ranked;
  }

  // Franja en curso según la hora local del host (los 4 dispositivos corren
  // en America/Santiago = competition_timezone). 00-06 usa el total del día.
  double _windowSteps(Map<String, dynamic> row, DateTime now) {
    final hour = now.hour;
    if (hour >= 6 && hour < 12) return (row['morning_steps'] as num?)?.toDouble() ?? 0;
    if (hour >= 12 && hour < 18) return (row['afternoon_steps'] as num?)?.toDouble() ?? 0;
    if (hour >= 18 && hour < 24) return (row['night_steps'] as num?)?.toDouble() ?? 0;
    return (row['daily_steps'] as num?)?.toDouble() ?? 0;
  }

  Future<(DateTime, DateTime)> _rangeFor(RankingTimePeriod period, DateTime now) async {
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case RankingTimePeriod.hoy:
        return (today, today);
      case RankingTimePeriod.semana:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return (monday, today);
      case RankingTimePeriod.temporada:
        final rows = await _client
            .from('seasons')
            .select('starts_at, ends_at')
            .eq('status', 'active')
            .order('starts_at', ascending: false)
            .limit(1);
        if (rows.isEmpty) return (today, today);
        final startsAt = DateTime.parse(rows.first['starts_at'] as String).toLocal();
        final endsAt = DateTime.parse(rows.first['ends_at'] as String).toLocal();
        return (DateTime(startsAt.year, startsAt.month, startsAt.day),
            DateTime(endsAt.year, endsAt.month, endsAt.day));
    }
  }

  String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
```

NOTA: el rango de temporada usa `.toLocal()` porque los cortes se crean a medianoche local de Santiago; la fecha local es la fecha de competencia (los 4 dispositivos del grupo corren en Chile).

- [ ] **Step 2: Modificar `ranking_tab.dart`**

En `_load()` (backend mode): reemplazar `DashboardRepository.load` por `RankingRepository.load(category: _selectedCategory, period: _selectedPeriod, now: DateTime.now())`; recargar en `onSelectionChanged` del SegmentedButton y de los `_CategoryChip`s (adicional al `setState`). Mover los enums `RankingTimePeriod` y `RankingCategory` a `ranking_models.dart` (importados por el widget desde ahí; `ranking_tab.dart` los re-exporta si hace falta compatibilidad). Mantener intacto el modo `loadFromBackend: false` con `rows` inyectadas (los tests existentes siguen pasando). Cambiar `_formatValue` para distancia: `'${(val).toStringAsFixed(0)}'` con unidad 'km' cuando `val < 1000`, y `_formatValue` existente para el resto.

- [ ] **Step 3: Helpers de fecha de competencia**

En `lib/shared/config/app_environment.dart` añadir:

```dart
  static String todayInCompetitionTz() {
    final now = DateTime.now().toLocal();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
```

NOTA: los 4 dispositivos del grupo corren en `America/Santiago` (la `competition_timezone`); la fecha local del host es la fecha de competencia. Documentado en CODESTYLE si el host difiere.

- [ ] **Step 4: Ampliar tests**

En `test/ranking_tab_test.dart`, añadir un test del modo backend con `RankingRepository` NO es posible sin Supabase; en su lugar, test de unidad del nuevo helper de fecha:

```dart
test('todayInCompetitionTz returns yyyy-MM-dd', () {
  final date = AppEnvironment.todayInCompetitionTz();
  expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date), isTrue);
});
```

- [ ] **Step 5: Verificar**

Run: `flutter analyze; flutter test` — Expected: todo limpio (los 2 tests existentes de ranking pasan sin cambios de contrato).

- [ ] **Step 6: Commit**

```bash
git add lib/features/ranking/data/ranking_repository.dart lib/features/ranking/presentation/ranking_tab.dart lib/shared/config/app_environment.dart test/ranking_tab_test.dart
git commit -m "feat: RANKING with real per-category per-period data"
```

---

### Task 10: Verificación final y documentación de despliegue

**Files:**
- Modify: `ROADMAP.md` (checkpoints), `docs/checkpoint-gamificacion.md` (nuevo, evidencia de entrega)

- [ ] **Step 1: Suite completa**

Run: `flutter analyze` — Expected: 0 issues.
Run: `flutter test` — Expected: all tests pass.

- [ ] **Step 2: Documentar despliegue backend**

Crear `docs/checkpoint-gamificacion.md` con: lista de migraciones a aplicar (`supabase db push` + `supabase functions deploy close_day`), SQL de verificación (query de misiones del día, claims, logros), y qué evidencia se requiere después de aplicar en remoto.

- [ ] **Step 3: Actualizar ROADMAP.md**

Marcar avance: 3.3 (reglas de puntos: misiones/logros), 3.9 (rotación diaria), 3.11 (JUEGO con misiones/logros/rachas/trofeos/historial), 6.10 (historial de temporadas) y añadir entrada al Checkpoint Log con fecha de hoy y evidencia local.

- [ ] **Step 4: Commit**

```bash
git add ROADMAP.md docs/checkpoint-gamificacion.md
git commit -m "docs: gamification delivery checkpoint and deploy notes"
```
