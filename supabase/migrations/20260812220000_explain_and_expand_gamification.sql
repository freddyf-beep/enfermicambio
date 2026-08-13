-- Make missions and achievements understandable in Spanish and expand the
-- rotation pool. The evaluator continues to use the stable metric keys.

update public.achievements a
set name = v.name,
    description = v.description
from (values
  ('FIRST_BLOOD', 'Primera sincronización', 'Sincroniza tu primer entrenamiento desde Salud o Health Connect.'),
  ('5K_CLUB', 'Club 5K', 'Alcanza 5.000 pasos en un mismo día.'),
  ('10K_CLUB', 'Club 10K', 'Alcanza 10.000 pasos en un mismo día.'),
  ('20K_CLUB', 'Club 20K', 'Alcanza 20.000 pasos en un mismo día.'),
  ('MARATHON_LEGS', 'Piernas de maratón', 'Alcanza 25.000 pasos en un mismo día.'),
  ('GALLO', 'Gallo', 'Gana cinco franjas de la mañana en la competencia.'),
  ('VAMPIRO', 'Vampiro', 'Alcanza 5.000 pasos entre las 18:00 y las 24:00.'),
  ('DICTATOR', 'Dominio del día', 'Gana las tres franjas y también el total de pasos del día.'),
  ('ON_FIRE', 'En racha', 'Cumple tu meta diaria de pasos durante siete días seguidos.'),
  ('GYM_RAT', 'Constancia de entrenamiento', 'Registra cinco entrenamientos dentro de siete días.'),
  ('RUN_FORREST', 'Corre Forrest', 'Completa 5 km en un solo entrenamiento.'),
  ('DOUBLE_DIGITS', 'Doble dígito', 'Completa 10 km en un solo entrenamiento.'),
  ('SOFA_DE_ORO', 'Sofá de oro', 'Queda último en pasos durante tres días seguidos. Es un logro humorístico.'),
  ('PERFECT_DAY', 'Día perfecto', 'En un mismo día, cumple pasos, entrenamiento, calorías y registro de comida.'),
  ('SEASON_CHAMPION', 'Campeón de temporada', 'Termina en el primer lugar de una temporada.'),
  ('KM_25', 'Cuarto de maratón', 'Acumula 25 km en tus registros históricos.'),
  ('KM_50', 'Cincuenta kilómetros', 'Acumula 50 km en tus registros históricos.'),
  ('KM_100', 'Centenario', 'Acumula 100 km en tus registros históricos.'),
  ('KM_250', 'Maratonista de maratones', 'Acumula 250 km en tus registros históricos.')
) as v(code, name, description) 
where a.code = v.code;

update public.missions m
set name = v.new_name,
    description = v.description,
    rules = v.rules
from (values
  ('EARLY BIRD', 'Madrugador', 'Alcanza 2.500 pasos por la mañana.',
    '{"metric":"morning_steps","target":2500,"details":"Solo cuentan los pasos registrados entre las 06:00 y las 12:00."}'::jsonb),
  ('MORNING PUSH', 'Impulso matutino', 'Alcanza 3.500 pasos por la mañana.',
    '{"metric":"morning_steps","target":3500,"details":"Solo cuentan los pasos registrados entre las 06:00 y las 12:00."}'::jsonb),
  ('BEAT YOURSELF', 'Supérate: +20%', 'Haz al menos un 20% más de pasos que tu promedio de 14 días.',
    '{"metric":"vs_14d_avg","target":1.2,"details":"Ejemplo: si tu promedio es 1.000 pasos, necesitas al menos 1.200. Si no hay 14 días de referencia, la misión todavía no puede calcularse."}'::jsonb),
  ('RUN FORREST', 'Corre Forrest', 'Completa al menos 5 km en un solo entrenamiento.',
    '{"metric":"workout_distance_m","target":5000,"details":"Debe existir un entrenamiento sincronizado con una distancia de al menos 5 km."}'::jsonb),
  ('ACTIVE DAY', 'Día activo', 'Cumple tu meta de pasos y registra un entrenamiento.',
    '{"metric":"active_day","target":1,"details":"Se cumplen dos condiciones el mismo día: llegar a tu meta personal de pasos y tener al menos un entrenamiento."}'::jsonb),
  ('BALANCED DAY', 'Día equilibrado', 'Cumple tu meta de pasos, registra comida y respeta tu meta calórica.',
    '{"metric":"balanced_day","target":1,"details":"La app comprueba pasos, alimentos registrados y que las calorías consumidas no superen tu objetivo."}'::jsonb),
  ('THE FOUR', 'Los cuatro: 40.000 pasos', 'Los cuatro usuarios suman 40.000 pasos entre todos.',
    '{"metric":"steps","target":40000,"details":"Se suman los pasos diarios de los cuatro usuarios. No importa quién aporta cada cantidad."}'::jsonb),
  ('TEAM TRAINING', 'Entreno en equipo', 'Al menos 3 de los 4 usuarios registran un entrenamiento.',
    '{"metric":"members_with_workout","target":3,"details":"Cada usuario cuenta una sola vez cuando tiene al menos un entrenamiento registrado ese día."}'::jsonb),
  ('LAST CHANCE', 'Reto nocturno', 'Gana quien tenga más pasos durante la noche.',
    '{"metric":"night_steps","target":1,"details":"Compites contra los demás. Solo cuentan los pasos entre las 18:00 y las 24:00. El número 1 no significa un paso: indica que habrá un ganador."}'::jsonb),
  ('DUEL', 'Duelo de la mañana', 'Gana quien tenga más pasos durante la mañana.',
    '{"metric":"morning_steps","target":1,"details":"Compites contra los demás. Solo cuentan los pasos entre las 06:00 y las 12:00. Gana la mayor cantidad, no quien llegue a un paso concreto."}'::jsonb),
  ('CAMINA 3 KM', 'Camina 3 km hoy', 'Acumula 3 km de distancia durante el día.',
    '{"metric":"distance_meters","target":3000,"details":"Se suma la distancia diaria importada desde Salud o Health Connect. 3.000 metros equivalen a 3 km."}'::jsonb),
  ('CORRE 10 KM', 'Corre 10 km', 'Completa 10 km en un solo entrenamiento.',
    '{"metric":"workout_distance_m","target":10000,"details":"Debe existir un entrenamiento sincronizado con una distancia de al menos 10 km."}'::jsonb),
  ('10 KM DE GRUPO', 'Equipo: 10 km', 'Los cuatro usuarios acumulan 10 km entre todos.',
    '{"metric":"distance_meters","target":10000,"details":"Se suman las distancias diarias de los cuatro usuarios. 10.000 metros equivalen a 10 km."}'::jsonb)
) as v(old_name, new_name, description, rules)
where m.name = v.old_name;

insert into public.missions (name, description, mission_type, rules, reward_points, starts_at, ends_at)
select * from (values
  ('META DE PASOS', 'Alcanza 5.000 pasos durante el día.', 'individual',
    '{"metric":"steps","target":5000,"details":"Cuenta el total de pasos del día, sin importar la hora."}'::jsonb, 10,
    '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz),
  ('PASEO CORTO', 'Acumula 1 km durante el día.', 'individual',
    '{"metric":"distance_meters","target":1000,"details":"1.000 metros equivalen a 1 km. Se toma la distancia diaria importada."}'::jsonb, 10,
    '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz),
  ('PASOS EN EQUIPO', 'Los cuatro suman 20.000 pasos.', 'cooperative',
    '{"metric":"steps","target":20000,"details":"Se suman los pasos del día de los cuatro usuarios."}'::jsonb, 15,
    '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz),
  ('RUTA DEL EQUIPO', 'Los cuatro suman 5 km.', 'cooperative',
    '{"metric":"distance_meters","target":5000,"details":"Se suman las distancias del día. 5.000 metros equivalen a 5 km."}'::jsonb, 15,
    '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz),
  ('TODOS EN ACCIÓN', 'Los cuatro registran un entrenamiento.', 'cooperative',
    '{"metric":"members_with_workout","target":4,"details":"Cada uno de los cuatro debe tener al menos un entrenamiento sincronizado ese día."}'::jsonb, 25,
    '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz),
  ('RETO DE PASOS', 'Gana quien acumule más pasos del día.', 'competitive',
    '{"metric":"steps","target":1,"details":"Es una competencia sin meta fija: gana el usuario con más pasos al cierre del día."}'::jsonb, 10,
    '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz),
  ('RETO DE DISTANCIA', 'Gana quien recorra más distancia del día.', 'competitive',
    '{"metric":"distance_meters","target":1,"details":"Es una competencia sin meta fija: gana el usuario con más metros registrados al cierre del día."}'::jsonb, 10,
    '2026-08-01T00:00:00Z'::timestamptz, '2026-12-31T23:59:59Z'::timestamptz)
) as v(name, description, mission_type, rules, reward_points, starts_at, ends_at)
where not exists (select 1 from public.missions m where m.name = v.name);

