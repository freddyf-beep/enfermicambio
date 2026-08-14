-- Keep GPS signal gaps as separate route segments. The client uses the EMA
-- smoothed coordinates and increments this marker after a gap over 30 seconds.
alter table public.workout_route_points
  add column if not exists segment_index integer not null default 0;

alter table public.workout_route_points
  drop constraint if exists workout_route_points_segment_index_check;

alter table public.workout_route_points
  add constraint workout_route_points_segment_index_check
  check (segment_index >= 0);

create index if not exists workout_route_points_workout_segment_timestamp_idx
  on public.workout_route_points (workout_id, segment_index, "timestamp");

-- The game screen explains every mission when it is tapped. These additional
-- entries are deliberately data-driven so the daily rotation can vary without
-- shipping another app binary.
insert into public.missions
  (name, description, mission_type, rules, reward_points, starts_at, ends_at)
select v.name, v.description, v.mission_type, v.rules, v.reward_points,
       '2026-08-01T00:00:00Z'::timestamptz,
       '2027-12-31T23:59:59Z'::timestamptz
from (values
  ('NOCTURNO', 'Alcanza 4.000 pasos entre las 18:00 y las 24:00.', 'individual',
   '{"metric":"night_steps","target":4000,"details":"Solo cuentan los pasos registrados en la franja nocturna local, desde las 18:00 hasta las 24:00."}'::jsonb, 10),
  ('TROTÓN', 'Recorre 8 km durante el día.', 'individual',
   '{"metric":"distance_meters","target":8000,"details":"Acumula al menos 8.000 metros en la actividad diaria importada desde Salud o Health Connect."}'::jsonb, 12),
  ('MEDIA MARATÓN', 'Completa 21 km en un solo entrenamiento.', 'individual',
   '{"metric":"workout_distance_m","target":21000,"details":"Necesitas un entrenamiento sincronizado con una distancia de al menos 21.000 metros."}'::jsonb, 20),
  ('MARATÓN GRUPAL', 'Los cuatro usuarios suman 42 km.', 'cooperative',
   '{"metric":"distance_meters","target":42000,"details":"Se suman las distancias diarias de los cuatro usuarios. La meta conjunta es 42.000 metros."}'::jsonb, 25),
  ('PAREJAS ACTIVAS', 'Al menos dos usuarios registran un entrenamiento.', 'cooperative',
   '{"metric":"members_with_workout","target":2,"details":"Cada usuario cuenta una sola vez cuando tiene al menos un entrenamiento sincronizado durante el día."}'::jsonb, 15),
  ('KM SUPREMO', 'Gana quien haga el entrenamiento más largo.', 'competitive',
   '{"metric":"workout_distance_m","target":1,"details":"No hay una meta fija: al cerrar el día gana quien tenga el entrenamiento individual más largo."}'::jsonb, 15),
  ('EL MÁS RÁPIDO DEL DÍA', 'Gana quien acumule más distancia diaria.', 'competitive',
   '{"metric":"distance_meters","target":1,"details":"No significa alcanzar un metro concreto. Se comparan los metros diarios de los cuatro usuarios y gana el valor más alto."}'::jsonb, 15)
) as v(name, description, mission_type, rules, reward_points)
where not exists (
  select 1 from public.missions m where m.name = v.name
);

-- Expanded achievement pack. Codes are stable identifiers used by the
-- evaluator; text can be translated later without changing unlocked rows.
insert into public.achievements
  (code, name, description, icon, metric, operator, threshold,
   time_window, repeatable, hidden, season_points)
values
  ('NOCTAMBULO', 'Noctámbulo', 'Alcanza 10.000 pasos entre las 18:00 y las 24:00.', 'nightlight', 'night_steps', 'gte', 10000, '18:00-24:00', false, false, 3),
  ('TITAN', 'Titán', 'Alcanza 30.000 pasos en un mismo día.', 'directions_run', 'daily_steps', 'gte', 30000, 'day', false, false, 5),
  ('MEDIA_MARATON', 'Media maratón', 'Completa 21 km en un solo entrenamiento.', 'directions_run', 'workout_distance_m', 'gte', 21000, 'workout', false, false, 5),
  ('MARATONISTA', 'Maratonista', 'Completa 42 km en un solo entrenamiento.', 'emoji_events', 'workout_distance_m', 'gte', 42000, 'workout', false, false, 10),
  ('SENOR_MANANA', 'Señor de la mañana', 'Gana 15 franjas de la mañana.', 'wb_twilight', 'morning_round_wins', 'gte', 15, 'season', false, false, 5),
  ('LLAMA_ETERNA', 'Llama eterna', 'Cumple la meta de pasos durante 30 días seguidos.', 'local_fire_department', 'step_goal_streak', 'gte', 30, 'streak', false, false, 10),
  ('SEMANA_PERFECTA', 'Semana perfecta', 'Completa 5 días perfectos.', 'star', 'perfect_day', 'gte', 5, 'lifetime', false, false, 5),
  ('BICAMPEON', 'Bicampeón', 'Termina en primer lugar en dos temporadas.', 'workspace_premium', 'season_wins', 'gte', 2, 'lifetime', false, false, 10),
  ('REY_DEL_SOFA', 'Rey del sofá', 'Queda último durante 7 días seguidos. Logro humorístico.', 'weekend', 'last_place_streak', 'gte', 7, 'streak', false, false, 1),
  ('ULTRACAMINANTE', 'Ultracaminante', 'Acumula 500 km en tus registros históricos.', 'route', 'lifetime_distance_m', 'gte', 500000, 'lifetime', false, false, 10),
  ('ENTRENADOR_10', 'Entrenador constante', 'Sincroniza 10 entrenamientos.', 'fitness_center', 'workouts_synced', 'gte', 10, 'lifetime', false, false, 3),
  ('ENTRENADOR_50', 'Entrenador dedicado', 'Sincroniza 50 entrenamientos.', 'fitness_center', 'workouts_synced', 'gte', 50, 'lifetime', false, false, 5),
  ('ENTRENADOR_100', 'Entrenador legendario', 'Sincroniza 100 entrenamientos.', 'fitness_center', 'workouts_synced', 'gte', 100, 'lifetime', false, false, 10),
  ('NOCHE_SECRETA', '???', 'Hay algo que solo se descubre caminando de noche.', 'lock', 'night_steps', 'gte', 1, '18:00-24:00', false, true, 2),
  ('RUTA_SECRETA', '???', 'Una pequeña ruta puede revelar un logro oculto.', 'lock', 'lifetime_distance_m', 'gte', 1000, 'lifetime', false, true, 2)
on conflict (code) do update set
  name = excluded.name,
  description = excluded.description,
  icon = excluded.icon,
  metric = excluded.metric,
  operator = excluded.operator,
  threshold = excluded.threshold,
  time_window = excluded.time_window,
  hidden = excluded.hidden,
  season_points = excluded.season_points;
