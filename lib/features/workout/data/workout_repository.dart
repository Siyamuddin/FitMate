import 'package:uuid/uuid.dart';
import 'package:fitmate/core/errors/app_exception.dart';
import 'package:fitmate/core/local/local_store.dart';
import 'package:fitmate/core/local/snapshot_keys.dart';
import 'package:fitmate/core/networking/supabase_provider.dart';
import 'package:fitmate/features/progress/domain/progress_snapshot.dart';
import 'package:fitmate/features/workout/domain/workout_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkoutRepository {
  WorkoutRepository({
    required LocalStore store,
    VoidCallback? onChanged,
    SupabaseClient? client,
  })  : _store = store,
        _onChanged = onChanged,
        _client = client ?? SupabaseProvider.client;

  final LocalStore _store;
  final VoidCallback? _onChanged;
  final SupabaseClient _client;
  int _quietDepth = 0;

  Future<T> transact<T>(Future<T> Function() body) async {
    _quietDepth++;
    try {
      return await body();
    } finally {
      _quietDepth--;
      if (_quietDepth == 0) {
        _notify();
      }
    }
  }

  void _notify() {
    if (_quietDepth == 0) {
      _onChanged?.call();
    }
  }

  Future<WorkoutPlan?> cachedPlan() async {
    await _store.ensureReady();
    final Map<String, dynamic>? json = await _store.getJson(SnapshotKeys.activePlan);
    if (json == null) {
      return null;
    }
    return WorkoutPlan.fromJson(json);
  }

  Future<List<Exercise>> cachedCatalog() async {
    await _store.ensureReady();
    final List<dynamic>? rows = await _store.getList(SnapshotKeys.exerciseCatalog);
    if (rows == null) {
      return <Exercise>[];
    }
    return rows.map((dynamic row) => Exercise.fromJson(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<List<WorkoutSessionSummary>> cachedHistory() async {
    await _store.ensureReady();
    final List<dynamic>? rows = await _store.getList(SnapshotKeys.workoutHistory);
    if (rows != null) {
      return rows
          .map((dynamic row) => WorkoutSessionSummary.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    }
    return (await _store.completedSessions())
        .map(WorkoutSessionSummary.fromJson)
        .toList();
  }

  Future<String> startSession({required String planId, required String dayId}) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppException('Sign in to start a workout.');
    }
    final String id = const Uuid().v4();
    final Map<String, dynamic> row = <String, dynamic>{
      'id': id,
      'user_id': userId,
      'plan_id': planId,
      'day_id': dayId,
      'status': 'in_progress',
      'started_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _store.saveSession(row);
    await _store.enqueue(type: OutboxType.upsertSession, entity: SnapshotKeys.sessions, payload: row);
    _notify();
    return id;
  }

  Future<void> upsertSetLog(String sessionId, SetLog log) async {
    final Map<String, dynamic> row = log.toJson(sessionId);
    await _store.saveSetLog(sessionId, row);
    await _store.enqueue(
      type: OutboxType.upsertSetLog,
      entity: SnapshotKeys.setLogs,
      payload: <String, dynamic>{'session_id': sessionId, 'row': row},
      id: log.clientId,
    );
    _notify();
  }

  Future<void> completeSession(String sessionId, int durationSeconds) async {
    final String completedAt = DateTime.now().toUtc().toIso8601String();
    final Map<String, dynamic> existing = await _store.sessionById(sessionId) ?? <String, dynamic>{'id': sessionId};
    final Map<String, dynamic> row = <String, dynamic>{
      ...existing,
      'id': sessionId,
      'status': 'completed',
      'completed_at': completedAt,
      'duration_seconds': durationSeconds,
    };
    await _store.saveSession(row);
    await _store.enqueue(type: OutboxType.upsertSession, entity: SnapshotKeys.sessions, payload: row);
    final WorkoutPlan? plan = await cachedPlan();
    String? dayName;
    final String? dayId = row['day_id'] as String?;
    if (plan != null && dayId != null) {
      for (final WorkoutDay day in plan.days) {
        if (day.id == dayId) {
          dayName = day.name;
          break;
        }
      }
    }
    final List<WorkoutSessionSummary> history = await cachedHistory();
    final WorkoutSessionSummary summary = WorkoutSessionSummary(
      id: sessionId,
      startedAt: DateTime.tryParse(row['started_at'] as String? ?? '') ?? DateTime.now(),
      completedAt: DateTime.parse(completedAt),
      durationSeconds: durationSeconds,
      dayName: dayName,
    );
    final List<WorkoutSessionSummary> next = <WorkoutSessionSummary>[
      summary,
      ...history.where((WorkoutSessionSummary item) => item.id != sessionId),
    ];
    await _store.setList(SnapshotKeys.workoutHistory, next.map((WorkoutSessionSummary item) => item.toJson()).toList());
    final Map<String, dynamic>? progressJson = await _store.getJson(SnapshotKeys.progress);
    if (progressJson != null) {
      final ProgressSnapshot progress = ProgressSnapshot.fromJson(progressJson);
      await _store.setJson(
        SnapshotKeys.progress,
        progress.copyWith(workoutsThisWeek: progress.workoutsThisWeek + 1).toJson(),
      );
    }
    _notify();
  }

  Future<List<SetLog>> previousSetLogs(String workoutExerciseId) async {
    await _store.ensureReady();
    final List<Map<String, dynamic>> rows = await _store.setLogsForExercise(workoutExerciseId);
    return rows.map((Map<String, dynamic> json) {
      return SetLog(
        clientId: json['client_id'] as String? ?? json['id'] as String,
        workoutExerciseId: json['workout_exercise_id'] as String? ?? workoutExerciseId,
        setNumber: json['set_number'] as int,
        weightKg: (json['weight_kg'] as num?)?.toDouble(),
        reps: json['reps'] as int?,
        completed: json['completed'] as bool? ?? true,
      );
    }).toList();
  }

  Future<Exercise> findOrCreateCustomExercise(String name) async {
    final String trimmed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) {
      throw const AppException('Name your exercise.');
    }
    if (trimmed.length > 80) {
      throw const AppException('Use a shorter exercise name.');
    }
    final List<Exercise> catalog = await cachedCatalog();
    for (final Exercise exercise in catalog) {
      if (exercise.name.toLowerCase() == trimmed.toLowerCase()) {
        return exercise;
      }
    }
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppException('Sign in to add an exercise.');
    }
    final Exercise created = Exercise(
      id: const Uuid().v4(),
      name: trimmed,
      primaryMuscle: 'other',
    );
    final List<Exercise> next = <Exercise>[created, ...catalog];
    await _store.setList(SnapshotKeys.exerciseCatalog, next.map((Exercise item) => item.toJson()).toList());
    await _store.enqueue(
      type: OutboxType.upsertCustomExercise,
      entity: SnapshotKeys.exerciseCatalog,
      payload: <String, dynamic>{
        'id': created.id,
        'name': trimmed,
        'user_id': userId,
        'primary_muscle': 'other',
        'equipment': 'other',
        'compatible_equipment': <String>['other'],
        'difficulty': 'beginner',
        'is_active': true,
      },
    );
    _notify();
    return created;
  }

  Future<String> addDay({
    required String planId,
    required String name,
    required int weekday,
    String? description,
    int estimatedDurationMinutes = 45,
    List<WorkoutExercise>? exercises,
  }) async {
    final WorkoutPlan plan = await _requirePlan(planId);
    if (plan.days.any((WorkoutDay day) => day.weekday == weekday)) {
      throw const AppException('That day already has a workout.');
    }
    final int sortOrder = plan.days.fold<int>(-1, (int max, WorkoutDay day) => day.weekday > max ? day.weekday : max) + 1;
    final String id = const Uuid().v4();
    final WorkoutDay day = WorkoutDay(
      id: id,
      planId: planId,
      weekday: weekday,
      name: name,
      description: description,
      estimatedDurationMinutes: estimatedDurationMinutes,
      exercises: exercises ?? <WorkoutExercise>[],
    );
    await _savePlan(plan.copyWith(days: <WorkoutDay>[...plan.days, day]));
    await _store.enqueue(
      type: OutboxType.insertDay,
      entity: SnapshotKeys.activePlan,
      payload: <String, dynamic>{
        'id': id,
        'plan_id': planId,
        'name': name,
        'weekday': weekday,
        'sort_order': sortOrder,
        'estimated_duration_minutes': estimatedDurationMinutes,
        'description': description,
        'status': 'scheduled',
      },
    );
    await _syncSchedule(planId);
    return id;
  }

  Future<void> updateDay({
    required String dayId,
    String? name,
    int? weekday,
    String? description,
  }) async {
    final WorkoutPlan? plan = await cachedPlan();
    if (plan == null) {
      throw const AppException('No plan yet.');
    }
    final List<WorkoutDay> days = plan.days.map((WorkoutDay day) {
      if (day.id != dayId) {
        return day;
      }
      return day.copyWith(name: name, weekday: weekday, description: description);
    }).toList();
    await _savePlan(plan.copyWith(days: days));
    final Map<String, dynamic> patch = <String, dynamic>{};
    if (name != null) {
      patch['name'] = name;
    }
    if (weekday != null) {
      patch['weekday'] = weekday;
    }
    if (description != null) {
      patch['description'] = description;
    }
    if (patch.isNotEmpty) {
      await _store.enqueue(
        type: OutboxType.updateDay,
        entity: SnapshotKeys.activePlan,
        payload: <String, dynamic>{'id': dayId, 'patch': patch},
      );
    }
    await _syncSchedule(plan.id);
  }

  Future<void> deleteDay({required String dayId, required String planId, required int remainingDays}) async {
    if (remainingDays <= 1) {
      throw const AppException('Keep at least one training day.');
    }
    final WorkoutPlan plan = await _requirePlan(planId);
    await _savePlan(plan.copyWith(days: plan.days.where((WorkoutDay day) => day.id != dayId).toList()));
    await _store.enqueue(
      type: OutboxType.deleteDay,
      entity: SnapshotKeys.activePlan,
      payload: <String, dynamic>{'id': dayId},
    );
    await _syncSchedule(planId);
  }

  Future<String> addExercise({
    required String dayId,
    required String exerciseId,
    int sets = 3,
    int reps = 10,
    int restSeconds = 90,
    int? sortOrder,
    String? notes,
  }) async {
    final WorkoutPlan? plan = await cachedPlan();
    if (plan == null) {
      throw const AppException('No plan yet.');
    }
    final List<Exercise> catalog = await cachedCatalog();
    final Exercise exercise = catalog.firstWhere(
      (Exercise item) => item.id == exerciseId,
      orElse: () => Exercise(id: exerciseId, name: 'Exercise', primaryMuscle: ''),
    );
    String? createdId;
    final List<WorkoutDay> days = plan.days.map((WorkoutDay day) {
      if (day.id != dayId) {
        return day;
      }
      final int order = sortOrder ?? (day.exercises.isEmpty ? 0 : day.exercises.map((WorkoutExercise item) => item.sortOrder).reduce((int a, int b) => a > b ? a : b) + 1);
      createdId = const Uuid().v4();
      final WorkoutExercise added = WorkoutExercise(
        id: createdId!,
        exercise: exercise,
        sortOrder: order,
        targetSets: sets,
        targetRepsMin: reps,
        targetRepsMax: reps,
        restSeconds: restSeconds,
      );
      return day.copyWith(exercises: <WorkoutExercise>[...day.exercises, added]);
    }).toList();
    if (createdId == null) {
      throw const AppException('That day is no longer on your plan.');
    }
    await _savePlan(plan.copyWith(days: days));
    await _store.enqueue(
      type: OutboxType.insertExercise,
      entity: SnapshotKeys.activePlan,
      payload: <String, dynamic>{
        'id': createdId,
        'day_id': dayId,
        'exercise_id': exerciseId,
        'sort_order': sortOrder ?? 0,
        'target_sets': sets,
        'target_reps_min': reps,
        'target_reps_max': reps,
        'rest_seconds': restSeconds,
        'notes': notes,
      },
    );
    await _enqueueReplaceSets(createdId!, sets: sets, reps: reps);
    _notify();
    return createdId!;
  }

  Future<void> updateExercise({
    required String workoutExerciseId,
    int? sets,
    int? reps,
    int? restSeconds,
  }) async {
    if (sets != null && (sets < 1 || sets > 8)) {
      throw const AppException('Sets must be between 1 and 8.');
    }
    if (reps != null && (reps < 1 || reps > 50)) {
      throw const AppException('Reps must be between 1 and 50.');
    }
    final WorkoutPlan? plan = await cachedPlan();
    if (plan == null) {
      throw const AppException('No plan yet.');
    }
    int nextSets = sets ?? 3;
    int nextReps = reps ?? 10;
    final List<WorkoutDay> days = plan.days.map((WorkoutDay day) {
      return day.copyWith(
        exercises: day.exercises.map((WorkoutExercise item) {
          if (item.id != workoutExerciseId) {
            return item;
          }
          nextSets = sets ?? item.targetSets;
          nextReps = reps ?? item.targetRepsMin ?? 10;
          return item.copyWith(
            targetSets: sets,
            targetRepsMin: reps,
            targetRepsMax: reps,
            restSeconds: restSeconds,
          );
        }).toList(),
      );
    }).toList();
    await _savePlan(plan.copyWith(days: days));
    final Map<String, dynamic> patch = <String, dynamic>{};
    if (sets != null) {
      patch['target_sets'] = sets;
    }
    if (reps != null) {
      patch['target_reps_min'] = reps;
      patch['target_reps_max'] = reps;
    }
    if (restSeconds != null) {
      patch['rest_seconds'] = restSeconds;
    }
    if (patch.isNotEmpty) {
      await _store.enqueue(
        type: OutboxType.updateExercise,
        entity: SnapshotKeys.activePlan,
        payload: <String, dynamic>{'id': workoutExerciseId, 'patch': patch},
      );
    }
    if (sets != null || reps != null) {
      await _enqueueReplaceSets(workoutExerciseId, sets: nextSets, reps: nextReps);
    }
    _notify();
  }

  Future<void> deleteExercise(String workoutExerciseId) async {
    final WorkoutPlan? plan = await cachedPlan();
    if (plan == null) {
      return;
    }
    final List<WorkoutDay> days = plan.days
        .map(
          (WorkoutDay day) => day.copyWith(
            exercises: day.exercises.where((WorkoutExercise item) => item.id != workoutExerciseId).toList(),
          ),
        )
        .toList();
    await _savePlan(plan.copyWith(days: days));
    await _store.enqueue(
      type: OutboxType.deleteExercise,
      entity: SnapshotKeys.activePlan,
      payload: <String, dynamic>{'id': workoutExerciseId},
    );
    _notify();
  }

  Future<void> savePlan(WorkoutPlan plan) => _savePlan(plan);

  Future<void> _enqueueReplaceSets(String workoutExerciseId, {required int sets, required int reps}) {
    return _store.enqueue(
      type: OutboxType.replaceSets,
      entity: SnapshotKeys.activePlan,
      payload: <String, dynamic>{
        'workout_exercise_id': workoutExerciseId,
        'rows': <Map<String, dynamic>>[
          for (int setNumber = 1; setNumber <= sets; setNumber++)
            <String, dynamic>{
              'workout_exercise_id': workoutExerciseId,
              'set_number': setNumber,
              'target_reps': reps,
            },
        ],
      },
    );
  }

  Future<void> _syncSchedule(String planId) async {
    final WorkoutPlan plan = await _requirePlan(planId);
    final List<int> weekdays = plan.days.map((WorkoutDay day) => day.weekday).toSet().toList()..sort();
    final int count = weekdays.length;
    String name = plan.name;
    if (RegExp(r'\b\d+-day\b', caseSensitive: false).hasMatch(name)) {
      name = name.replaceFirst(RegExp(r'\b\d+-day\b', caseSensitive: false), '$count-Day');
    }
    await _savePlan(plan.copyWith(name: name));
    await _store.enqueue(
      type: OutboxType.updatePlan,
      entity: SnapshotKeys.activePlan,
      payload: <String, dynamic>{
        'id': planId,
        'patch': <String, dynamic>{'days_per_week': count, 'name': name},
      },
    );
    final String? userId = _client.auth.currentUser?.id;
    if (userId != null && weekdays.isNotEmpty) {
      await _store.enqueue(
        type: OutboxType.updatePreferences,
        entity: SnapshotKeys.activePlan,
        payload: <String, dynamic>{
          'user_id': userId,
          'patch': <String, dynamic>{
            'training_days_per_week': count,
            'preferred_weekdays': weekdays,
          },
        },
      );
    }
    final Map<String, dynamic>? progressJson = await _store.getJson(SnapshotKeys.progress);
    if (progressJson != null) {
      await _store.setJson(
        SnapshotKeys.progress,
        ProgressSnapshot.fromJson(progressJson).copyWith(workoutsPlanned: count).toJson(),
      );
    }
    _notify();
  }

  Future<WorkoutPlan> _requirePlan(String planId) async {
    final WorkoutPlan? plan = await cachedPlan();
    if (plan == null || plan.id != planId) {
      throw const AppException('No plan yet.');
    }
    return plan;
  }

  Future<void> _savePlan(WorkoutPlan plan) async {
    await _store.setJson(SnapshotKeys.activePlan, plan.toJson());
  }
}

typedef VoidCallback = void Function();
