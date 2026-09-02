import 'dart:convert';

import 'package:fitmate/core/constants/enums.dart';
import 'package:fitmate/core/errors/app_exception.dart';
import 'package:fitmate/core/local/local_store.dart';
import 'package:fitmate/core/local/snapshot_keys.dart';
import 'package:fitmate/core/utils/formatters.dart';
import 'package:fitmate/features/nutrition/data/nutrition_repository.dart';
import 'package:fitmate/features/onboarding/data/profile_repository.dart';
import 'package:fitmate/features/workout/data/workout_repository.dart';
import 'package:fitmate/features/workout/domain/workout_models.dart';

class AiActionApplier {
  AiActionApplier({
    required WorkoutRepository workouts,
    required ProfileRepository profiles,
    required LocalStore store,
    NutritionRepository? nutrition,
  }) : _workouts = workouts,
       _profiles = profiles,
       _store = store,
       _nutrition = nutrition;

  final WorkoutRepository _workouts;
  final ProfileRepository _profiles;
  final LocalStore _store;
  final NutritionRepository? _nutrition;

  static const List<String> _conditioning = <String>[
    'Mountain Climber',
    'Plank',
    'Crunch',
    'Sit-up',
  ];

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
            case 'add_exercise':
              await _addExercise(targetId, changes);
              break;
            case 'remove_exercise':
              await _removeExercise(targetId, changes);
              break;
            case 'replace_exercise':
              await _replaceExercise(targetId, changes);
              break;
            case 'modify_workout_day':
              await _workouts.updateDay(
                dayId: await _requireDayId(targetId, changes),
                name: changes['name'] as String?,
                weekday: Formatters.weekdayFrom(changes['weekday']),
                description: changes['description'] as String?,
              );
              break;
            case 'update_training_plan':
            case 'create_workout_plan':
              await _updatePlan(targetId, changes);
              break;
            case 'add_food_log':
              await _addFoodLog(changes);
              break;
            case 'update_nutrition_targets':
              await _updateNutritionTargets(changes);
              break;
            case 'update_goal':
              await _updateGoal(changes);
              break;
            case 'record_weight':
              final double weight = _asDouble(changes['weight_kg']) ?? 0;
              if (weight < 30 || weight > 400) {
                throw const AppException('That weight looks off.');
              }
              await _profiles.logWeight(weight);
              break;
            case 'update_profile':
              await _updateProfile(changes);
              break;
            default:
              throw const AppException(
                'I could not save that kind of change yet.',
              );
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

  Future<void> _modifyExercise(
    String targetId,
    Map<String, dynamic> changes,
  ) async {
    final String id = await _requireExerciseRowId(targetId, changes);
    await _workouts.updateExercise(
      workoutExerciseId: id,
      sets: _sets(changes['sets'] ?? changes['target_sets']),
      reps: _reps(changes['reps'] ?? changes['target_reps_min']),
    );
  }

  Future<void> _addExercise(
    String targetId,
    Map<String, dynamic> changes,
  ) async {
    final WorkoutDay day = await _requireDay(targetId, changes);
    final Exercise exercise = await _requireCatalogExercise(changes);
    await _workouts.addExercise(
      dayId: day.id,
      exerciseId: exercise.id,
      sets: _sets(changes['sets'] ?? changes['target_sets']) ?? 3,
      reps: _reps(changes['reps'] ?? changes['target_reps_min']) ?? 10,
      restSeconds: _asInt(changes['rest_seconds']) ?? 60,
    );
  }

  Future<void> _removeExercise(
    String targetId,
    Map<String, dynamic> changes,
  ) async {
    final String id = await _requireExerciseRowId(targetId, changes);
    await _workouts.deleteExercise(id);
  }

  Future<void> _replaceExercise(
    String targetId,
    Map<String, dynamic> changes,
  ) async {
    final WorkoutExerciseMatch match = await _requireExerciseMatch(
      targetId,
      changes,
    );
    final Exercise next = await _requireCatalogExercise(changes);
    await _workouts.deleteExercise(match.item.id);
    await _workouts.addExercise(
      dayId: match.day.id,
      exerciseId: next.id,
      sets:
          _sets(changes['sets'] ?? changes['target_sets']) ??
          match.item.targetSets,
      reps:
          _reps(changes['reps'] ?? changes['target_reps_min']) ??
          match.item.targetRepsMin ??
          10,
      restSeconds: _asInt(changes['rest_seconds']) ?? match.item.restSeconds,
    );
  }

  Future<void> _addFoodLog(Map<String, dynamic> changes) async {
    final NutritionRepository? nutrition = _nutrition;
    if (nutrition == null) {
      throw const AppException('Could not log that food.');
    }
    final String slot = (changes['meal_slot'] as String? ?? 'snack')
        .toLowerCase();
    if (!<String>{'breakfast', 'lunch', 'dinner', 'snack'}.contains(slot)) {
      throw const AppException('Choose breakfast, lunch, dinner, or snack.');
    }
    final Food food = await _requireFood(nutrition, changes);
    final double quantity = _asDouble(changes['quantity']) ?? food.servingSize;
    if (quantity <= 0) {
      throw const AppException('That serving looks off.');
    }
    await nutrition.logFood(food: food, mealSlot: slot, quantity: quantity);
  }

  Future<void> _updateNutritionTargets(Map<String, dynamic> changes) async {
    final NutritionRepository? nutrition = _nutrition;
    if (nutrition == null) {
      throw const AppException('Could not update nutrition targets.');
    }
    await nutrition.updateTargets(
      calories: _asInt(changes['calories']),
      proteinG: _asDouble(changes['protein_g'] ?? changes['protein']),
      carbohydratesG: _asDouble(changes['carbohydrates_g'] ?? changes['carbs']),
      fatG: _asDouble(changes['fat_g'] ?? changes['fat']),
    );
  }

  Future<void> _updateGoal(Map<String, dynamic> changes) async {
    final double? target = _asDouble(changes['target_weight_kg']);
    final GoalType? goalType = _goalType(changes['goal_type']);
    if (target == null && goalType == null) {
      throw const AppException('Missing goal change.');
    }
    await _profiles.updateActiveGoal(
      targetWeightKg: target,
      goalType: goalType,
    );
  }

  Future<void> _updateProfile(Map<String, dynamic> changes) async {
    await _profiles.updateProfileFields(
      age: _asInt(changes['age']),
      heightCm: _asDouble(changes['height_cm']),
      activityLevel: _activityLevel(changes['activity_level']),
      trainingExperience: _experience(changes['training_experience']),
      trainingEnvironment: _environment(changes['training_environment']),
      recalculateNutrition: changes['activity_level'] != null,
    );
  }

  Future<Food> _requireFood(
    NutritionRepository nutrition,
    Map<String, dynamic> changes,
  ) async {
    final List<Food> foods = await nutrition.cachedFoods();
    final String id = changes['food_id'] as String? ?? '';
    if (id.isNotEmpty) {
      for (final Food food in foods) {
        if (food.id == id) {
          return food;
        }
      }
    }
    final String name =
        (changes['food_name'] as String? ?? changes['name'] as String? ?? '')
            .trim();
    if (name.isEmpty) {
      throw const AppException("I couldn't find that food.");
    }
    Food? match = _bestFood(foods, name);
    if (match != null) {
      return match;
    }
    final List<Food> searched = await nutrition.search(name, online: true);
    match = _bestFood(searched, name);
    if (match == null) {
      throw const AppException("I couldn't find that food.");
    }
    return match;
  }

  Food? _bestFood(List<Food> foods, String name) {
    final String needle = _norm(name);
    Food? contains;
    for (final Food food in foods) {
      final String hay = _norm(food.name);
      if (hay == needle) {
        return food;
      }
      if (contains == null && hay.contains(needle)) {
        contains = food;
      }
    }
    return contains;
  }

  Future<String> _requireDayId(
    String targetId,
    Map<String, dynamic> changes,
  ) async {
    final WorkoutDay day = await _requireDay(targetId, changes);
    return day.id;
  }

  Future<WorkoutDay> _requireDay(
    String targetId,
    Map<String, dynamic> changes,
  ) async {
    final WorkoutPlan? plan = await _workouts.cachedPlan();
    if (plan == null) {
      throw const AppException('No plan yet.');
    }
    final String dayId = targetId.isNotEmpty
        ? targetId
        : changes['day_id'] as String? ?? '';
    for (final WorkoutDay day in plan.days) {
      if (day.id == dayId) {
        return day;
      }
    }
    final int? weekday = Formatters.weekdayFrom(
      changes['weekday'] ?? changes['day'],
    );
    if (weekday != null) {
      for (final WorkoutDay day in plan.days) {
        if (day.weekday == weekday) {
          return day;
        }
      }
    }
    final String name = _norm(
      changes['day_name'] as String? ?? changes['name'] as String? ?? '',
    );
    if (name.isNotEmpty) {
      for (final WorkoutDay day in plan.days) {
        if (_norm(day.name) == name ||
            _norm(Formatters.weekdayName(day.weekday)) == name) {
          return day;
        }
      }
    }
    throw const AppException("I couldn't find that day.");
  }

  Future<String> _requireExerciseRowId(
    String targetId,
    Map<String, dynamic> changes,
  ) async {
    final WorkoutExerciseMatch match = await _requireExerciseMatch(
      targetId,
      changes,
    );
    return match.item.id;
  }

  Future<WorkoutExerciseMatch> _requireExerciseMatch(
    String targetId,
    Map<String, dynamic> changes,
  ) async {
    final WorkoutPlan? plan = await _workouts.cachedPlan();
    if (plan == null) {
      throw const AppException('No plan yet.');
    }
    if (targetId.isNotEmpty) {
      for (final WorkoutDay day in plan.days) {
        for (final WorkoutExercise item in day.exercises) {
          if (item.id == targetId) {
            return WorkoutExerciseMatch(day: day, item: item);
          }
        }
      }
    }
    WorkoutDay? scoped;
    try {
      scoped = await _requireDay('', changes);
    } on AppException {
      scoped = null;
    }
    final String needle = _norm(
      changes['exercise_name'] as String? ?? changes['name'] as String? ?? '',
    );
    if (needle.isNotEmpty) {
      final List<WorkoutDay> days = scoped == null
          ? plan.days
          : <WorkoutDay>[scoped];
      for (final WorkoutDay day in days) {
        for (final WorkoutExercise item in day.exercises) {
          if (_norm(item.exercise.name) == needle ||
              _norm(item.exercise.name).contains(needle)) {
            return WorkoutExerciseMatch(day: day, item: item);
          }
        }
      }
    }
    throw const AppException("I couldn't find that exercise.");
  }

  Future<Exercise> _requireCatalogExercise(Map<String, dynamic> changes) async {
    final List<Exercise> catalog = await _workouts.cachedCatalog();
    final String id =
        changes['exercise_id'] as String? ??
        changes['new_exercise_id'] as String? ??
        '';
    if (id.isNotEmpty) {
      for (final Exercise exercise in catalog) {
        if (exercise.id == id) {
          return exercise;
        }
      }
    }
    final String name =
        (changes['exercise_name'] as String? ??
                changes['name'] as String? ??
                changes['new_exercise_name'] as String? ??
                '')
            .trim();
    if (name.isEmpty) {
      throw const AppException("I couldn't find that exercise.");
    }
    final String needle = _norm(name);
    Exercise? contains;
    for (final Exercise exercise in catalog) {
      final String hay = _norm(exercise.name);
      if (hay == needle) {
        return exercise;
      }
      if (contains == null && hay.contains(needle)) {
        contains = exercise;
      }
    }
    if (contains == null) {
      throw const AppException("I couldn't find that exercise.");
    }
    return contains;
  }

  String _norm(String value) {
    return value
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  GoalType? _goalType(Object? value) {
    if (value is! String) {
      return null;
    }
    final String key = value.trim().toLowerCase().replaceAll(' ', '_');
    for (final MapEntry<GoalType, String> entry in goalTypeValues.entries) {
      if (entry.value == key || entry.key.name.toLowerCase() == key) {
        return entry.key;
      }
    }
    return null;
  }

  ActivityLevel? _activityLevel(Object? value) {
    if (value is! String) {
      return null;
    }
    final String key = value.trim().toLowerCase().replaceAll(' ', '_');
    for (final MapEntry<ActivityLevel, String> entry
        in activityLevelValues.entries) {
      if (entry.value == key || entry.key.name.toLowerCase() == key) {
        return entry.key;
      }
    }
    return null;
  }

  TrainingExperience? _experience(Object? value) {
    if (value is! String) {
      return null;
    }
    switch (value.trim().toLowerCase()) {
      case 'beginner':
        return TrainingExperience.beginner;
      case 'intermediate':
        return TrainingExperience.intermediate;
      case 'advanced':
        return TrainingExperience.advanced;
      default:
        return null;
    }
  }

  TrainingEnvironment? _environment(Object? value) {
    if (value is! String) {
      return null;
    }
    switch (value.trim().toLowerCase()) {
      case 'home':
        return TrainingEnvironment.home;
      case 'gym':
        return TrainingEnvironment.gym;
      case 'outdoor':
        return TrainingEnvironment.outdoor;
      case 'combination':
      case 'mixed':
        return TrainingEnvironment.combination;
      default:
        return null;
    }
  }

  Future<void> _updatePlan(
    String targetId,
    Map<String, dynamic> changes,
  ) async {
    final WorkoutPlan? plan = await _workouts.cachedPlan();
    if (plan == null) {
      throw const AppException('No plan yet.');
    }
    final int? daysPerWeek = _intInRange(changes['days_per_week'], 1, 7);
    await _removeDays(plan, changes);
    WorkoutPlan latest = (await _workouts.cachedPlan())!;
    final List<dynamic> listed = changes['workout_days'] is List
        ? changes['workout_days'] as List<dynamic>
        : <dynamic>[];
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
      final int? open = _firstOpen(
        latest.days.map((WorkoutDay day) => day.weekday).toList(),
      );
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

  Future<void> _removeDays(
    WorkoutPlan plan,
    Map<String, dynamic> changes,
  ) async {
    final Set<String> ids = <String>{};
    final Set<int> weekdays = <int>{};
    final Object? oneId = changes['remove_workout_day_id'];
    if (oneId is String && oneId.isNotEmpty) {
      ids.add(oneId);
    }
    if (changes['remove_workout_day_ids'] is List) {
      for (final dynamic id
          in changes['remove_workout_day_ids'] as List<dynamic>) {
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
        .where(
          (WorkoutDay day) =>
              ids.contains(day.id) || weekdays.contains(day.weekday),
        )
        .toList();
    if (toDelete.isEmpty) {
      throw const AppException('Could not find that day.');
    }
    if (toDelete.length >= plan.days.length) {
      throw const AppException('Keep at least one training day.');
    }
    int remaining = plan.days.length;
    for (final WorkoutDay day in toDelete) {
      await _workouts.deleteDay(
        dayId: day.id,
        planId: plan.id,
        remainingDays: remaining,
      );
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
    final Set<int> used = plan.days
        .map((WorkoutDay day) => day.weekday)
        .toSet();
    if (weekday != null && used.contains(weekday)) {
      return;
    }
    weekday ??= _firstOpen(used.toList());
    if (weekday == null) {
      return;
    }
    final String dayId = await _workouts.addDay(
      planId: planId,
      name: (spec['name'] as String?)?.trim().isNotEmpty == true
          ? spec['name'] as String
          : 'Day ${plan.days.length + 1}',
      weekday: weekday,
      description: (spec['note'] ?? spec['description']) as String?,
      estimatedDurationMinutes:
          _asInt(spec['estimated_duration_minutes']) ?? 30,
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
    return Formatters.weekdayFrom(value);
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
      return int.tryParse(value.trim()) ??
          double.tryParse(value.trim())?.toInt();
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

class WorkoutExerciseMatch {
  const WorkoutExerciseMatch({required this.day, required this.item});

  final WorkoutDay day;
  final WorkoutExercise item;
}
