import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class Exercise extends Equatable {
  const Exercise({
    required this.id,
    required this.name,
    required this.primaryMuscle,
    this.instructions,
  });

  final String id;
  final String name;
  final String primaryMuscle;
  final String? instructions;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Exercise',
      primaryMuscle: json['primary_muscle'] as String? ?? '',
      instructions: json['instructions'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'primary_muscle': primaryMuscle,
      'instructions': instructions,
    };
  }

  @override
  List<Object?> get props => <Object?>[id, name];
}

class WorkoutExercise extends Equatable {
  const WorkoutExercise({
    required this.id,
    required this.exercise,
    required this.sortOrder,
    required this.targetSets,
    this.targetRepsMin,
    this.targetRepsMax,
    this.targetWeightKg,
    this.restSeconds = 90,
  });

  final String id;
  final Exercise exercise;
  final int sortOrder;
  final int targetSets;
  final int? targetRepsMin;
  final int? targetRepsMax;
  final double? targetWeightKg;
  final int restSeconds;

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    final Object? nested = json['exercises'] ?? json['exercise'];
    final Map<String, dynamic> exerciseJson = nested is Map
        ? Map<String, dynamic>.from(nested)
        : <String, dynamic>{
            'id': json['exercise_id'] as String? ?? '',
            'name': json['name'] as String? ?? 'Exercise',
            'primary_muscle': json['primary_muscle'] as String? ?? '',
          };
    return WorkoutExercise(
      id: json['id'] as String? ?? '',
      exercise: Exercise.fromJson(exerciseJson),
      sortOrder: _jsonInt(json['sort_order']) ?? 0,
      targetSets: _jsonInt(json['target_sets']) ?? 3,
      targetRepsMin: _jsonInt(json['target_reps_min']),
      targetRepsMax: _jsonInt(json['target_reps_max']),
      targetWeightKg: _jsonDouble(json['target_weight_kg']),
      restSeconds: _jsonInt(json['rest_seconds']) ?? 90,
    );
  }

  WorkoutExercise copyWith({
    Exercise? exercise,
    int? sortOrder,
    int? targetSets,
    int? targetRepsMin,
    int? targetRepsMax,
    double? targetWeightKg,
    int? restSeconds,
  }) {
    return WorkoutExercise(
      id: id,
      exercise: exercise ?? this.exercise,
      sortOrder: sortOrder ?? this.sortOrder,
      targetSets: targetSets ?? this.targetSets,
      targetRepsMin: targetRepsMin ?? this.targetRepsMin,
      targetRepsMax: targetRepsMax ?? this.targetRepsMax,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      restSeconds: restSeconds ?? this.restSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sort_order': sortOrder,
      'target_sets': targetSets,
      'target_reps_min': targetRepsMin,
      'target_reps_max': targetRepsMax,
      'target_weight_kg': targetWeightKg,
      'rest_seconds': restSeconds,
      'exercises': exercise.toJson(),
      'exercise_id': exercise.id,
    };
  }

  @override
  List<Object?> get props => <Object?>[id, exercise, targetSets, targetRepsMin];
}

class WorkoutDay extends Equatable {
  const WorkoutDay({
    required this.id,
    required this.planId,
    required this.weekday,
    required this.name,
    required this.exercises,
    this.estimatedDurationMinutes,
    this.description,
  });

  final String id;
  final String planId;
  final int weekday;
  final String name;
  final List<WorkoutExercise> exercises;
  final int? estimatedDurationMinutes;
  final String? description;

  factory WorkoutDay.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = json['workout_exercises'] as List<dynamic>? ?? <dynamic>[];
    return WorkoutDay(
      id: json['id'] as String? ?? '',
      planId: json['plan_id'] as String? ?? '',
      weekday: _jsonInt(json['weekday']) ?? 1,
      name: json['name'] as String? ?? 'Workout',
      estimatedDurationMinutes: _jsonInt(json['estimated_duration_minutes']),
      description: json['description'] as String?,
      exercises: raw.map((dynamic row) => WorkoutExercise.fromJson(Map<String, dynamic>.from(row as Map))).toList()
        ..sort((WorkoutExercise a, WorkoutExercise b) => a.sortOrder.compareTo(b.sortOrder)),
    );
  }

  WorkoutDay copyWith({
    int? weekday,
    String? name,
    List<WorkoutExercise>? exercises,
    int? estimatedDurationMinutes,
    String? description,
  }) {
    return WorkoutDay(
      id: id,
      planId: planId,
      weekday: weekday ?? this.weekday,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'plan_id': planId,
      'weekday': weekday,
      'name': name,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'description': description,
      'workout_exercises': exercises.map((WorkoutExercise item) => item.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => <Object?>[id, name, weekday, exercises];
}

class WorkoutPlan extends Equatable {
  const WorkoutPlan({
    required this.id,
    required this.name,
    required this.days,
    this.status = 'active',
  });

  final String id;
  final String name;
  final List<WorkoutDay> days;
  final String status;

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = json['workout_days'] as List<dynamic>? ?? <dynamic>[];
    return WorkoutPlan(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Plan',
      status: json['status'] as String? ?? 'active',
      days: raw.map((dynamic row) => WorkoutDay.fromJson(Map<String, dynamic>.from(row as Map))).toList()
        ..sort((WorkoutDay a, WorkoutDay b) => a.weekday.compareTo(b.weekday)),
    );
  }

  WorkoutPlan copyWith({
    String? name,
    List<WorkoutDay>? days,
    String? status,
  }) {
    return WorkoutPlan(
      id: id,
      name: name ?? this.name,
      days: days ?? this.days,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'status': status,
      'workout_days': days.map((WorkoutDay day) => day.toJson()).toList(),
    };
  }

  WorkoutDay? today([DateTime? now]) {
    final int weekday = (now ?? DateTime.now()).weekday % 7;
    for (final WorkoutDay day in days) {
      if (day.weekday == weekday) {
        return day;
      }
    }
    return days.isEmpty ? null : days.first;
  }

  @override
  List<Object?> get props => <Object?>[id, name, days];
}

class SetLog {
  SetLog({
    required this.clientId,
    required this.workoutExerciseId,
    required this.setNumber,
    this.weightKg,
    this.reps,
    this.completed = false,
    this.skipped = false,
  });

  final String clientId;
  final String workoutExerciseId;
  final int setNumber;
  double? weightKg;
  int? reps;
  bool completed;
  bool skipped;

  factory SetLog.create({
    required String workoutExerciseId,
    required int setNumber,
    double? weightKg,
    int? reps,
  }) {
    return SetLog(
      clientId: const Uuid().v4(),
      workoutExerciseId: workoutExerciseId,
      setNumber: setNumber,
      weightKg: weightKg,
      reps: reps,
    );
  }

  Map<String, dynamic> toJson(String sessionId) {
    return <String, dynamic>{
      'session_id': sessionId,
      'workout_exercise_id': workoutExerciseId,
      'set_number': setNumber,
      'weight_kg': weightKg,
      'reps': reps,
      'completed': completed,
      'skipped': skipped,
      'completed_at': completed ? DateTime.now().toUtc().toIso8601String() : null,
      'client_id': clientId,
    };
  }
}

class WorkoutSessionSummary extends Equatable {
  const WorkoutSessionSummary({
    required this.id,
    required this.startedAt,
    this.completedAt,
    this.durationSeconds,
    this.status = 'completed',
    this.dayName,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? durationSeconds;
  final String status;
  final String? dayName;

  factory WorkoutSessionSummary.fromJson(Map<String, dynamic> json) {
    return WorkoutSessionSummary(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] == null ? null : DateTime.parse(json['completed_at'] as String),
      durationSeconds: _jsonInt(json['duration_seconds']),
      status: json['status'] as String? ?? 'completed',
      dayName: (json['workout_days'] as Map?)?['name'] as String? ?? json['day_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'started_at': startedAt.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'duration_seconds': durationSeconds,
      'status': status,
      'day_name': dayName,
      'workout_days': <String, dynamic>{'name': dayName},
    };
  }

  @override
  List<Object?> get props => <Object?>[id, startedAt];
}

int? _jsonInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? double.tryParse(value.trim())?.toInt();
  }
  return null;
}

double? _jsonDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}
