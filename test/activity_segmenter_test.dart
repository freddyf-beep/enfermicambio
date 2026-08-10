import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'package:enfermicambio/features/health/domain/activity_segmenter.dart';
import 'package:enfermicambio/features/health/domain/health_models.dart';
import 'package:enfermicambio/shared/config/app_config.dart';

void main() {
  setUpAll(timezone_data.initializeTimeZones);

  const windows = CompetitionWindows(
    morning: CompetitionWindow(name: 'morning', startHour: 6, endHour: 12),
    afternoon: CompetitionWindow(name: 'afternoon', startHour: 12, endHour: 18),
    night: CompetitionWindow(name: 'night', startHour: 18, endHour: 24),
  );

  test('segments records at competition window boundaries', () {
    final location = timezone.getLocation('America/Santiago');
    final day = timezone.TZDateTime(location, 2026, 8, 10);
    final samples = [
      _step(day.add(const Duration(hours: 5, minutes: 59)), 100),
      _step(day.add(const Duration(hours: 6)), 200),
      _step(day.add(const Duration(hours: 12)), 300),
      _step(day.add(const Duration(hours: 18)), 400),
      _step(day.add(const Duration(hours: 23, minutes: 59)), 500),
    ];

    final aggregate = const ActivitySegmenter().segment(
      samples: samples,
      competitionDate: day,
      competitionTimezone: 'America/Santiago',
      windows: windows,
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
        _step(day.add(const Duration(hours: 7)), 250),
        _step(
          day.add(const Duration(hours: 8)),
          1000,
          recordingMethod: HealthRecordingMethod.manual,
        ),
      ],
      competitionDate: day,
      competitionTimezone: 'America/Santiago',
      windows: windows,
    );

    expect(aggregate.dailySteps, 250);
    expect(aggregate.manualRecordsExcluded, 1);
  });

  test('includes early morning steps in daily total before 06:00', () {
    final location = timezone.getLocation('America/Santiago');
    final day = timezone.TZDateTime(location, 2026, 8, 10);
    final aggregate = const ActivitySegmenter().segment(
      samples: [
        _step(day.add(const Duration(hours: 2)), 800),
        _step(day.add(const Duration(hours: 7)), 200),
      ],
      competitionDate: day,
      competitionTimezone: 'America/Santiago',
      windows: windows,
    );

    expect(aggregate.dailySteps, 1000);
    expect(aggregate.morningSteps, 200);
    expect(aggregate.nightSteps, 0);
  });

  test('exact midnight boundary starts a new day', () {
    final location = timezone.getLocation('America/Santiago');
    final day = timezone.TZDateTime(location, 2026, 8, 10);
    final aggregate = const ActivitySegmenter().segment(
      samples: [
        _step(day, 300),
        _step(day.add(const Duration(hours: 23, minutes: 59)), 200),
      ],
      competitionDate: day,
      competitionTimezone: 'America/Santiago',
      windows: windows,
    );

    expect(aggregate.dailySteps, 500);
    expect(aggregate.nightSteps, 200);
  });

  test('aggregates active calories, distance, and exercise minutes', () {
    final location = timezone.getLocation('America/Santiago');
    final day = timezone.TZDateTime(location, 2026, 8, 10);
    final aggregate = const ActivitySegmenter().segment(
      samples: [
        _step(day.add(const Duration(hours: 9)), 2000),
        _sample(
          HealthMetricType.activeCalories,
          day.add(const Duration(hours: 9)),
          350.5,
        ),
        _sample(
          HealthMetricType.distance,
          day.add(const Duration(hours: 9)),
          1200.0,
        ),
        _sample(
          HealthMetricType.exerciseMinutes,
          day.add(const Duration(hours: 9)),
          40.0,
        ),
      ],
      competitionDate: day,
      competitionTimezone: 'America/Santiago',
      windows: windows,
    );

    expect(aggregate.dailySteps, 2000);
    expect(aggregate.activeCalories, closeTo(350.5, 0.001));
    expect(aggregate.distanceMeters, closeTo(1200.0, 0.001));
    expect(aggregate.exerciseMinutes, closeTo(40.0, 0.001));
  });
}

HealthSample _step(
  DateTime start,
  int value, {
  HealthRecordingMethod recordingMethod = HealthRecordingMethod.automatic,
}) {
  return _sample(
    HealthMetricType.steps,
    start,
    value.toDouble(),
    recordingMethod: recordingMethod,
  );
}

HealthSample _sample(
  HealthMetricType type,
  DateTime start,
  double value, {
  HealthRecordingMethod recordingMethod = HealthRecordingMethod.automatic,
}) {
  return HealthSample(
    type: type,
    value: value,
    dateFrom: start,
    dateTo: start.add(const Duration(minutes: 1)),
    sourceApp: 'fixture',
    sourceDevice: 'fixture-device',
    recordingMethod: recordingMethod,
  );
}
