import 'dart:convert';

import 'package:fitmate/core/errors/app_exception.dart';
import 'package:fitmate/core/local/local_store.dart';
import 'package:fitmate/core/local/snapshot_keys.dart';
import 'package:fitmate/features/onboarding/data/profile_repository.dart';
import 'package:fitmate/features/workout/data/workout_repository.dart';
import 'package:fitmate/features/workout/domain/workout_models.dart';

class AiActionApplier {
  AiActionApplier({
    required WorkoutRepository workouts,
    required ProfileRepository profiles,
    required LocalStore store,
  })  : _workouts = workouts,
        _profiles = profiles,
        _store = store;

  final WorkoutRepository _workouts;
  final ProfileRepository _profiles;
  final LocalStore _store;

  static const List<String> _conditioning = <String>['Mountain Climber', 'Plank', 'Crunch', 'Sit-up'];

  Future<void> apply(List<Map<String, dynamic>> actions) async {
    if (actions.isEmpty) {
      throw const AppException('Nothing to apply.');
    }
    final Map<String, dynamic> payload;
    try {
      payload = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(<String, dynamic>{'actions': actions})) as Map,
      );
    } catch (_) {
      throw const AppException('Could not save that change.');
    }
    await _workouts.transact(() async {
      await _profiles.transact(() async {
        for (final Map<String, dynamic> action in actions) {
          final String type = action['type'] as String? ?? '';
          final String targetId = action['target_id'] as String? ?? '';
          final Map<String, dynamic> changes = action['changes'] is Map
              ? Map<String, dynamic>.from(action['changes'] as Map)
              : <String, dynamic>{};
          switch (type) {
            case 'modify_workout_exercise':
              await _modifyExercise(targetId, changes);
              break;
            case 'modify_workout_day':
              await _workouts.updateDay(
                dayId: targetId,
                name: changes['name'] as String?,
                weekday: _weekday(changes['weekday']),
                description: changes['description'] as String?,
              );
              break;
            case 'update_training_plan':
            case 'create_workout_plan':
              await _updatePlan(targetId, changes);
              break;
            case 'update_goal':
              final double? target = _asDouble(changes['target_weight_kg']);
              if (target == null) {
                throw const AppException('Missing goal change.');
              }
              await _profiles.updateActiveGoal(targetWeightKg: target);
              break;
            case 'record_weight':
              final double weight = _asDouble(changes['weight_kg']) ?? 0;
              if (weight < 30 || weight > 400) {
                throw const AppException('That weight looks off.');
              }
              await _profiles.logWeight(weight);
              break;
            default:
              throw AppException('Could not apply $type.');
          }
        }
        await _store.enqueue(
          type: OutboxType.ackAiActions,
          entity: SnapshotKeys.coachMessages,
          payload: payload,
        );
      });
    });
  }

  Future<void> _modifyExercise(String targetId, Map<String, dynamic> changes) async {
    if (targetId.isEmpty) {
      throw const AppException('Missing exercise.');
    }
    await _workouts.updateExercise(
      workoutExerciseId: targetId,
      sets: _sets(changes['sets'] ?? changes['target_sets']),
      reps: _reps(changes['reps'] ?? changes['target_reps_min']),
    );
  }

  Future<void> _updatePlan(String targetId, Map<String, dynamic> changes) async {
    final WorkoutPlan? plan = await _workouts.cachedPlan();
    if (plan == null) {
      throw const AppException('No plan yet.');
    }
    final int? daysPerWeek = _intInRange(changes['days_per_week'], 1, 7);
    await _removeDays(plan, changes);
    WorkoutPlan latest = (await _workouts.cachedPlan())!;
    final List<dynamic> listed = changes['workout_days'] is List ? changes['workout_days'] as List<dynamic> : <dynamic>[];
    for (final dynamic spec in listed) {
      if (spec is Map) {
        await _upsertDay(latest.id, Map<String, dynamic>.from(spec));
        latest = (await _workouts.cachedPlan())!;
      }
    }
    final Map<String, dynamic> added = changes['add_workout_day'] is Map
        ? Map<String, dynamic>.from(changes['add_workout_day'] as Map)
        : <String, dynamic>{};
    if (added.isNotEmpty) {
      await _upsertDay(latest.id, added);
      latest = (await _workouts.cachedPlan())!;
    }
    if (daysPerWeek != null && latest.days.length < daysPerWeek) {
      final int? open = _firstOpen(latest.days.map((WorkoutDay day) => day.weekday).toList());
      if (open != null) {
        final String dayId = await _workouts.addDay(
          planId: latest.id,
          name: 'Conditioning & Core',
          weekday: open,
          estimatedDurationMinutes: 30,
        );
        await _addDefaultConditioning(dayId);
      }
    }
  }

  Future<void> _removeDays(WorkoutPlan plan, Map<String, dynamic> changes) async {
    final Set<String> ids = <String>{};
    final Set<int> weekdays = <int>{};
    final Object? oneId = changes['remove_workout_day_id'];
    if (oneId is String && oneId.isNotEmpty) {
      ids.add(oneId);
    }
    if (changes['remove_workout_day_ids'] is List) {
      for (final dynamic id in changes['remove_workout_day_ids'] as List<dynamic>) {
        if (id is String && id.isNotEmpty) {
          ids.add(id);
        }
      }
    }
    final Object? remove = changes['remove_workout_day'];
    if (remove is String && remove.isNotEmpty) {
      ids.add(remove);
    }
    if (remove is Map) {
      final Object? id = remove['id'];
      if (id is String && id.isNotEmpty) {
        ids.add(id);
      }
      final int? weekday = _weekday(remove['weekday']);
      if (weekday != null) {
        weekdays.add(weekday);
      }
    }
    final int? weekday = _weekday(changes['remove_weekday']);
    if (weekday != null) {
      weekdays.add(weekday);
    }
    if (changes['remove_weekdays'] is List) {
      for (final dynamic item in changes['remove_weekdays'] as List<dynamic>) {
        final int? value = _weekday(item);
        if (value != null) {
          weekdays.add(value);
        }
      }
    }
    if (ids.isEmpty && weekdays.isEmpty) {
      return;
    }
    final List<WorkoutDay> toDelete = plan.days
        .where((WorkoutDay day) => ids.contains(day.id) || weekdays.contains(day.weekday))
        .toList();
    if (toDelete.isEmpty) {
      throw const AppException('Could not find that day.');
    }
    if (toDelete.length >= plan.days.length) {
      throw const AppException('Keep at least one training day.');
    }
    int remaining = plan.days.length;
    for (final WorkoutDay day in toDelete) {
      await _workouts.deleteDay(dayId: day.id, planId: plan.id, remainingDays: remaining);
      remaining--;
    }
  }

  Future<void> _upsertDay(String planId, Map<String, dynamic> spec) async {
    final WorkoutPlan? plan = await _workouts.cachedPlan();
    if (plan == null) {
      return;
    }
    final String existingId = spec['id'] as String? ?? '';
    WorkoutDay? existing;
    for (final WorkoutDay day in plan.days) {
      if (day.id == existingId) {
        existing = day;
        break;
      }
    }
    if (existing != null) {
      await _workouts.updateDay(
        dayId: existing.id,
        name: spec['name'] as String?,
        weekday: _weekday(spec['weekday']),
        description: (spec['note'] ?? spec['description']) as String?,
      );
      return;
    }
    int? weekday = _weekday(spec['weekday']);
    final Set<int> used = plan.days.map((WorkoutDay day) => day.weekday).toSet();
    if (weekday != null && used.contains(weekday)) {
      return;
    }
    weekday ??= _firstOpen(used.toList());
    if (weekday == null) {
      return;
    }
    final String dayId = await _workouts.addDay(
      planId: planId,
      name: (spec['name'] as String?)?.trim().isNotEmpty == true ? spec['name'] as String : 'Day ${plan.days.length + 1}',
      weekday: weekday,
      description: (spec['note'] ?? spec['description']) as String?,
      estimatedDurationMinutes: _asInt(spec['estimated_duration_minutes']) ?? 30,
    );
    final String sourceId = spec['source_workout_day_id'] as String? ?? '';
    if (sourceId.isNotEmpty) {
      WorkoutDay? source;
      for (final WorkoutDay day in plan.days) {
        if (day.id == sourceId) {
          source = day;
          break;
        }
      }
      if (source != null) {
        for (final WorkoutExercise item in source.exercises) {
          await _workouts.addExercise(
            dayId: dayId,
            exerciseId: item.exercise.id,
            sets: item.targetSets,
            reps: item.targetRepsMin ?? 10,
            restSeconds: item.restSeconds,
          );
        }
      }
      return;
    }
    final List<dynamic> exercises = spec['exercises'] is List
        ? spec['exercises'] as List<dynamic>
        : spec['workout_exercises'] is List
            ? spec['workout_exercises'] as List<dynamic>
            : <dynamic>[];
    if (exercises.isNotEmpty) {
      for (final dynamic item in exercises) {
        if (item is! Map) {
          continue;
        }
        final Map<String, dynamic> row = Map<String, dynamic>.from(item);
        final String exerciseId = row['exercise_id'] as String? ?? '';
        if (exerciseId.isEmpty) {
          continue;
        }
        await _workouts.addExercise(
          dayId: dayId,
          exerciseId: exerciseId,
          sets: _sets(row['sets'] ?? row['target_sets']) ?? 3,
          reps: _reps(row['reps'] ?? row['target_reps_min']) ?? 10,
          restSeconds: _asInt(row['rest_seconds']) ?? 60,
        );
      }
      return;
    }
    await _addDefaultConditioning(dayId);
  }

  Future<void> _addDefaultConditioning(String dayId) async {
    final List<Exercise> catalog = await _workouts.cachedCatalog();
    for (final String name in _conditioning) {
      Exercise? match;
      for (final Exercise exercise in catalog) {
        if (exercise.name == name) {
          match = exercise;
          break;
        }
      }
      if (match == null) {
        continue;
      }
      await _workouts.addExercise(
        dayId: dayId,
        exerciseId: match.id,
        sets: 3,
        reps: name.toLowerCase().contains('plank') ? 30 : 12,
        restSeconds: 60,
      );
    }
  }

  int? _sets(Object? value) {
    if (value == null) {
      return null;
    }
    final int? n = _asInt(value);
    if (n == null) {
      throw const AppException('Sets must be a number.');
    }
    if (n < 1 || n > 8) {
      throw const AppException('Sets must be between 1 and 8.');
    }
    return n;
  }

  int? _reps(Object? value) {
    if (value == null) {
      return null;
    }
    final int? n = _asInt(value);
    if (n == null) {
      throw const AppException('Reps must be a number.');
    }
    if (n < 1 || n > 50) {
      throw const AppException('Reps must be between 1 and 50.');
    }
    return n;
  }

  int? _intInRange(Object? value, int min, int max) {
    final int? n = _asInt(value);
    if (n == null || n < min || n > max) {
      return null;
    }
    return n;
  }

  int? _weekday(Object? value) {
    final int? n = _asInt(value);
    if (n == null || n < 0 || n > 6) {
      return null;
    }
    return n;
  }

  int? _asInt(Object? value) {
    if (value == null) {
      return null;
    }
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

  double? _asDouble(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  int? _firstOpen(List<int> used) {
    const List<int> order = <int>[1, 2, 3, 4, 5, 6, 0];
    for (final int day in order) {
      if (!used.contains(day)) {
        return day;
      }
    }
    return null;
  }
}
