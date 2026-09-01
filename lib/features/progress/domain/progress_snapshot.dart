class ProgressSnapshot {
  const ProgressSnapshot({
    required this.weights,
    this.currentWeight,
    this.targetWeight,
    this.workoutsThisWeek = 0,
    this.workoutsPlanned = 0,
  });

  final List<double> weights;
  final double? currentWeight;
  final double? targetWeight;
  final int workoutsThisWeek;
  final int workoutsPlanned;

  ProgressSnapshot copyWith({
    List<double>? weights,
    double? currentWeight,
    double? targetWeight,
    int? workoutsThisWeek,
    int? workoutsPlanned,
  }) {
    return ProgressSnapshot(
      weights: weights ?? this.weights,
      currentWeight: currentWeight ?? this.currentWeight,
      targetWeight: targetWeight ?? this.targetWeight,
      workoutsThisWeek: workoutsThisWeek ?? this.workoutsThisWeek,
      workoutsPlanned: workoutsPlanned ?? this.workoutsPlanned,
    );
  }

  factory ProgressSnapshot.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = json['weights'] as List<dynamic>? ?? <dynamic>[];
    final List<double> weights = raw.map<double>((dynamic item) {
      if (item is num) {
        return item.toDouble();
      }
      if (item is Map) {
        return (item['weight_kg'] as num?)?.toDouble() ?? 0;
      }
      return 0;
    }).toList();
    return ProgressSnapshot(
      weights: weights,
      currentWeight: (json['current_weight'] as num?)?.toDouble() ?? (weights.isEmpty ? null : weights.last),
      targetWeight: (json['target_weight'] as num?)?.toDouble(),
      workoutsThisWeek: json['workouts_this_week'] as int? ?? 0,
      workoutsPlanned: json['workouts_planned'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'weights': weights,
      'current_weight': currentWeight,
      'target_weight': targetWeight,
      'workouts_this_week': workoutsThisWeek,
      'workouts_planned': workoutsPlanned,
    };
  }
}
