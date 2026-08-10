import '../domain/health_models.dart';

class InMemoryActivitySink implements DailyActivitySink {
  DailyActivityAggregate? latest;

  @override
  Future<void> upsert(DailyActivityAggregate aggregate) async {
    latest = aggregate;
  }
}
