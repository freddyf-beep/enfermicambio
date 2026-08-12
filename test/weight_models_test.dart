import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/weight/domain/weight_models.dart';

void main() {
  group('WeightEntry parses rows', () {
    test('fromJson maps all fields', () {
      final entry = WeightEntry.fromJson({
        'id': 'w1',
        'entry_date': '2026-08-11',
        'weight_kg': 79.5,
        'source': 'manual',
        'created_at': '2026-08-11T20:00:00Z',
      });
      expect(entry.id, 'w1');
      expect(entry.weightKg, 79.5);
      expect(entry.source, 'manual');
      expect(entry.entryDate.year, 2026);
    });

    test('defaults source to manual', () {
      final entry = WeightEntry.fromJson({
        'id': 'w2',
        'entry_date': '2026-08-10',
        'weight_kg': 80.0,
        'created_at': '2026-08-10T20:00:00Z',
      });
      expect(entry.source, 'manual');
    });
  });
}
