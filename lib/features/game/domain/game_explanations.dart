import 'package:enfermicambio/shared/text/text_encoding.dart';

import 'game_models.dart';

String missionTypeLabel(String type) => switch (type) {
  'competitive' => 'Reto entre jugadores',
  'cooperative' => 'Reto del equipo',
  _ => 'Reto personal',
};

String missionMetricLabel(String metric) => switch (metric) {
  'steps' ||
  'daily_steps' ||
  'morning_steps' ||
  'afternoon_steps' ||
  'night_steps' => 'pasos',
  'distance_meters' => 'distancia recorrida',
  'workout_distance_m' => 'distancia de un entrenamiento',
  'members_with_workout' => 'personas con entrenamiento',
  'workout' => 'entrenamiento registrado',
  'calorie_target' => 'meta calórica',
  'vs_14d_avg' => 'promedio de pasos',
  'active_day' => 'día activo',
  'balanced_day' => 'día equilibrado',
  'active_calories' => 'calorías activas',
  'exercise_minutes' => 'minutos de ejercicio',
  _ => metric.replaceAll('_', ' '),
};

String missionTimeWindow(String metric) => switch (metric) {
  'morning_steps' => 'entre las 06:00 y las 12:00',
  'afternoon_steps' => 'entre las 12:00 y las 18:00',
  'night_steps' => 'entre las 18:00 y las 24:00',
  'workout_distance_m' => 'en un solo entrenamiento',
  'workout' => 'durante el día',
  'calorie_target' => 'durante el día',
  'vs_14d_avg' => 'comparado con tus últimos 14 días',
  _ => 'durante el día',
};

String formatGameValue(String metric, double value) {
  if (metric == 'distance_meters' || metric == 'workout_distance_m') {
    return value >= 1000
        ? '${(value / 1000).toStringAsFixed(1)} km'
        : '${value.round()} m';
  }
  if (metric == 'vs_14d_avg') return '${(value * 100).round()}%';
  if (metric == 'active_calories') return '${value.round()} kcal';
  if (metric == 'exercise_minutes') return '${value.round()} min';
  if (metric == 'workout' || metric == 'calorie_target') {
    return value >= 1 ? 'cumplido' : 'pendiente';
  }
  if (metric == 'active_day' || metric == 'balanced_day') {
    return value >= 1 ? 'cumplido' : 'pendiente';
  }
  return '${formatGameNumber(value)} ${missionMetricLabel(metric)}';
}

String formatGameNumber(double value) {
  final rounded = value.round();
  final digits = rounded.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) buffer.write('.');
  }
  return buffer.toString();
}

String missionTargetText(Mission mission) {
  final metric = (mission.rules['metric'] as String?) ?? 'steps';
  final target = ((mission.rules['target'] as num?) ?? 0).toDouble();
  if (mission.missionType == 'competitive') {
    return 'La meta no es un número fijo: gana quien consiga más '
        '${missionMetricLabel(metric)} ${missionTimeWindow(metric)}.';
  }
  if (metric == 'vs_14d_avg') {
    return 'Consigue al menos ${(target * 100).round()}% de tu promedio '
        'diario de pasos de los últimos 14 días, es decir, un ${((target - 1) * 100).round()}% más.';
  }
  if (metric == 'active_day') {
    return 'Cumple tu meta diaria de pasos y registra al menos un entrenamiento '
        'durante el día.';
  }
  if (metric == 'balanced_day') {
    return 'Cumple tu meta diaria de pasos, registra comida y mantente dentro '
        'de tu meta calórica.';
  }
  if (metric == 'workout') {
    return 'Registra al menos un entrenamiento sincronizado durante el día.';
  }
  if (metric == 'calorie_target') {
    return 'Registra comida y termina el día dentro de tu meta calórica configurada.';
  }
  if (metric == 'members_with_workout') {
    return 'Consigan que al menos ${target.round()} de los 4 usuarios registren '
        'un entrenamiento durante el día.';
  }
  final targetText = formatGameValue(metric, target);
  final verb = metric == 'workout_distance_m' ? 'Registra' : 'Alcanza';
  return '$verb $targetText ${missionTimeWindow(metric)}.';
}

String missionProgressText(Mission mission, double value, bool completed) {
  final metric = (mission.rules['metric'] as String?) ?? 'steps';
  if (mission.missionType == 'competitive') {
    return 'Tu marca: ${formatGameValue(metric, value)}. '
        '${completed ? 'Ganaste este reto.' : 'Todavía estás compitiendo.'}';
  }
  if (metric == 'active_day' ||
      metric == 'balanced_day' ||
      metric == 'workout' ||
      metric == 'calorie_target') {
    return completed ? 'Requisito cumplido.' : 'Requisito pendiente.';
  }
  final target = ((mission.rules['target'] as num?) ?? 0).toDouble();
  return '${formatGameValue(metric, value)} de ${formatGameValue(metric, target)}.';
}

String achievementRequirement(Achievement achievement) {
  final threshold = achievement.threshold;
  final metric = achievement.metric;
  final name = repairMojibake(achievement.name);
  switch (metric) {
    case 'workouts_synced':
      return 'Sincroniza al menos ${threshold.round()} entrenamiento'
          '${threshold.round() == 1 ? '' : 's'} desde Salud o Health Connect.';
    case 'daily_steps':
      return 'Alcanza ${formatGameValue(metric, threshold)} en un mismo día.';
    case 'night_steps':
      return 'Alcanza ${formatGameValue(metric, threshold)} entre las 18:00 y las 24:00.';
    case 'morning_round_wins':
      return 'Gana ${threshold.round()} franjas de la mañana en la competencia.';
    case 'rounds_and_total_wins':
      return 'Gana las tres franjas y también el total de pasos del día.';
    case 'step_goal_streak':
      return 'Cumple tu meta diaria de pasos durante ${threshold.round()} días seguidos.';
    case 'workouts_7d':
      return 'Registra ${threshold.round()} entrenamientos dentro de un período de 7 días.';
    case 'workout_distance_m':
      return 'Completa ${formatGameValue(metric, threshold)} en un solo entrenamiento.';
    case 'last_place_streak':
      return 'Queda último en pasos durante ${threshold.round()} días seguidos. '
          'Es un logro humorístico: no premia ser el más rápido.';
    case 'perfect_day':
      return 'En un mismo día, cumple pasos, entrenamiento, calorías y registro de comida.';
    case 'season_wins':
      return 'Termina en el primer lugar de una temporada.';
    case 'lifetime_distance_m':
      return 'Acumula ${formatGameValue(metric, threshold)} en tus registros históricos.';
    default:
      return '$name: alcanza el objetivo registrado en la aplicación.';
  }
}
