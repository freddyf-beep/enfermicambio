class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.entryDate,
    required this.weightKg,
    required this.source,
    required this.createdAt,
  });

  final String id;
  final DateTime entryDate;
  final double weightKg;
  final String source;
  final DateTime createdAt;

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      id: json['id'] as String,
      entryDate: DateTime.parse(json['entry_date'] as String),
      weightKg: (json['weight_kg'] as num).toDouble(),
      source: (json['source'] as String?) ?? 'manual',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
