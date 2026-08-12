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
