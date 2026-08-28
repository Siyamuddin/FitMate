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
      id: json['id'] as String,
      name: json['name'] as String,
      primaryMuscle: json['primary_muscle'] as String? ?? '',
      instructions: json['instructions'] as String?,
    );
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
    return WorkoutExercise(
      id: json['id'] as String,
      exercise: Exercise.fromJson(Map<String, dynamic>.from(json['exercises'] as Map)),
      sortOrder: json['sort_order'] as int? ?? 0,
      targetSets: json['target_sets'] as int? ?? 3,
      targetRepsMin: json['target_reps_min'] as int?,
      targetRepsMax: json['target_reps_max'] as int?,
      targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble(),
      restSeconds: json['rest_seconds'] as int? ?? 90,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, exercise];
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
      id: json['id'] as String,
      planId: json['plan_id'] as String,
      weekday: json['weekday'] as int,
      name: json['name'] as String,
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int?,
      description: json['description'] as String?,
      exercises: raw.map((dynamic row) => WorkoutExercise.fromJson(Map<String, dynamic>.from(row as Map))).toList()
        ..sort((WorkoutExercise a, WorkoutExercise b) => a.sortOrder.compareTo(b.sortOrder)),
    );
  }

  @override
  List<Object?> get props => <Object?>[id, name, weekday];
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
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String? ?? 'active',
      days: raw.map((dynamic row) => WorkoutDay.fromJson(Map<String, dynamic>.from(row as Map))).toList()
        ..sort((WorkoutDay a, WorkoutDay b) => a.weekday.compareTo(b.weekday)),
    );
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
  List<Object?> get props => <Object?>[id, name];
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
      durationSeconds: json['duration_seconds'] as int?,
      status: json['status'] as String? ?? 'completed',
      dayName: (json['workout_days'] as Map?)?['name'] as String?,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, startedAt];
}
