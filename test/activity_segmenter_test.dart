import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'package:enfermicambio/features/health/domain/activity_segmenter.dart';
import 'package:enfermicambio/features/health/domain/health_models.dart';
import 'package:enfermicambio/shared/config/app_config.dart';

void main() {
  setUpAll(timezone_data.initializeTimeZones);

  test('segments records at competition window boundaries', () {
    final location = timezone.getLocation('America/Santiago');
    final day = timezone.TZDateTime(location, 2026, 8, 10);
    final samples = [
      _sample(day.add(const Duration(hours: 5, minutes: 59)), 100),
      _sample(day.add(const Duration(hours: 6)), 200),
      _sample(day.add(const Duration(hours: 12)), 300),
      _sample(day.add(const Duration(hours: 18)), 400),
      _sample(day.add(const Duration(hours: 23, minutes: 59)), 500),
    ];

    final aggregate = const ActivitySegmenter().segment(
      samples: samples,
      competitionDate: day,
      competitionTimezone: 'America/Santiago',
      windows: const CompetitionWindows(
        morning: CompetitionWindow(name: 'morning', startHour: 6, endHour: 12),
        afternoon: CompetitionWindow(
          name: 'afternoon',
          startHour: 12,
          endHour: 18,
        ),
        night: CompetitionWindow(name: 'night', startHour: 18, endHour: 24),
      ),
    );

    expect(aggregate.morningSteps, 200);
    expect(aggregate.afternoonSteps, 300);
    expect(aggregate.nightSteps, 900);
    expect(aggregate.dailySteps, 1500);
  });

  test('excludes manual records and reports the count', () {
    final location = timezone.getLocation('America/Santiago');
    final day = timezone.TZDateTime(location, 2026, 8, 10);
    final aggregate = const ActivitySegmenter().segment(
      samples: [
        _sample(day.add(const Duration(hours: 7)), 250),
        _sample(
          day.add(const Duration(hours: 8)),
          1000,
          recordingMethod: HealthRecordingMethod.manual,
        ),
      ],
      competitionDate: day,
      competitionTimezone: 'America/Santiago',
      windows: const CompetitionWindows(
        morning: CompetitionWindow(name: 'morning', startHour: 6, endHour: 12),
        afternoon: CompetitionWindow(
          name: 'afternoon',
          startHour: 12,
          endHour: 18,
        ),
        night: CompetitionWindow(name: 'night', startHour: 18, endHour: 24),
      ),
    );

    expect(aggregate.dailySteps, 250);
    expect(aggregate.manualRecordsExcluded, 1);
  });
}

HealthStepSample _sample(
  DateTime start,
  int value, {
  HealthRecordingMethod recordingMethod = HealthRecordingMethod.automatic,
}) {
  return HealthStepSample(
    value: value.toDouble(),
    dateFrom: start,
    dateTo: start.add(const Duration(minutes: 1)),
    sourceApp: 'fixture',
    sourceDevice: 'fixture-device',
    recordingMethod: recordingMethod,
  );
}
