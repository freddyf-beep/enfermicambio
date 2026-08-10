import 'package:timezone/timezone.dart' as timezone;

import '../../../shared/config/app_config.dart';
import 'health_models.dart';

class ActivitySegmenter {
  const ActivitySegmenter();

  DailyActivityAggregate segment({
    required Iterable<HealthStepSample> samples,
    required DateTime competitionDate,
    required String competitionTimezone,
    required CompetitionWindows windows,
    DateTime? syncedAt,
    String sourcePlatform = 'unknown',
    String? sourceApp,
    String? sourceDevice,
    String recordingMethod = 'automatic',
    Map<String, dynamic> sourceMetadata = const {},
  }) {
    final location = timezone.getLocation(competitionTimezone);
    final localDate = timezone.TZDateTime(
      location,
      competitionDate.year,
      competitionDate.month,
      competitionDate.day,
    );
    final dayStart = localDate.toUtc();
    final dayEnd = localDate.add(const Duration(days: 1)).toUtc();
    final windowTotals = <String, double>{
      windows.morning.name: 0,
      windows.afternoon.name: 0,
      windows.night.name: 0,
    };
    var dailyTotal = 0.0;
    var manualRecordsExcluded = 0;

    for (final sample in samples) {
      if (sample.isManual) {
        manualRecordsExcluded++;
        continue;
      }

      final sampleStart = sample.dateFrom.toUtc();
      final sampleEnd = sample.dateTo.toUtc();
      final clippedStart = sampleStart.isAfter(dayStart)
          ? sampleStart
          : dayStart;
      final clippedEnd = sampleEnd.isBefore(dayEnd) ? sampleEnd : dayEnd;
      if (!clippedStart.isBefore(clippedEnd) && sampleStart != sampleEnd) {
        continue;
      }

      final duration = sampleEnd.difference(sampleStart);
      if (duration <= Duration.zero) {
        final localPoint = timezone.TZDateTime.from(sampleStart, location);
        for (final window in windows.all) {
          if (_contains(localPoint, localDate, window)) {
            windowTotals[window.name] =
                windowTotals[window.name]! + sample.value;
            break;
          }
        }
        if (!sampleStart.isBefore(dayStart) && sampleStart.isBefore(dayEnd)) {
          dailyTotal += sample.value;
        }
        continue;
      }

      if (clippedStart.isBefore(clippedEnd)) {
        final clippedMilliseconds = clippedEnd
            .difference(clippedStart)
            .inMilliseconds;
        dailyTotal +=
            sample.value * clippedMilliseconds / duration.inMilliseconds;
      }
      for (final window in windows.all) {
        final windowStart = timezone.TZDateTime(
          location,
          localDate.year,
          localDate.month,
          localDate.day,
          window.startHour,
        ).toUtc();
        final windowEnd = timezone.TZDateTime(
          location,
          localDate.year,
          localDate.month,
          localDate.day + (window.endHour == 24 ? 1 : 0),
          window.endHour == 24 ? 0 : window.endHour,
        ).toUtc();
        final overlapStart = clippedStart.isAfter(windowStart)
            ? clippedStart
            : windowStart;
        final overlapEnd = clippedEnd.isBefore(windowEnd)
            ? clippedEnd
            : windowEnd;
        if (overlapStart.isBefore(overlapEnd)) {
          final overlapSeconds = overlapEnd
              .difference(overlapStart)
              .inMilliseconds;
          final durationMilliseconds = duration.inMilliseconds;
          windowTotals[window.name] =
              windowTotals[window.name]! +
              sample.value * overlapSeconds / durationMilliseconds;
        }
      }
    }

    final morningSteps = windowTotals[windows.morning.name]!.round();
    final afternoonSteps = windowTotals[windows.afternoon.name]!.round();
    final nightSteps = windowTotals[windows.night.name]!.round();
    return DailyActivityAggregate(
      date: DateTime.utc(
        competitionDate.year,
        competitionDate.month,
        competitionDate.day,
      ),
      morningSteps: morningSteps,
      afternoonSteps: afternoonSteps,
      nightSteps: nightSteps,
      dailySteps: dailyTotal.round(),
      syncedAt: syncedAt ?? DateTime.now().toUtc(),
      manualRecordsExcluded: manualRecordsExcluded,
      sourcePlatform: sourcePlatform,
      sourceApp: sourceApp,
      sourceDevice: sourceDevice,
      recordingMethod: recordingMethod,
      sourceMetadata: sourceMetadata,
    );
  }

  bool _contains(
    timezone.TZDateTime value,
    timezone.TZDateTime localDate,
    CompetitionWindow window,
  ) {
    final start = timezone.TZDateTime(
      localDate.location,
      localDate.year,
      localDate.month,
      localDate.day,
      window.startHour,
    );
    final end = timezone.TZDateTime(
      localDate.location,
      localDate.year,
      localDate.month,
      localDate.day + (window.endHour == 24 ? 1 : 0),
      window.endHour == 24 ? 0 : window.endHour,
    );
    return !value.isBefore(start) && value.isBefore(end);
  }
}
