import 'package:fitmate/core/utils/formatters.dart';
import 'package:fitmate/features/workout/domain/workout_models.dart';

class ActionPreview {
  const ActionPreview._();

  static List<String> lines(
    List<Map<String, dynamic>> actions, {
    WorkoutPlan? plan,
  }) {
    final List<String> result = <String>[];
    for (final Map<String, dynamic> action in actions) {
      final String? line = _line(action, plan);
      if (line != null && line.isNotEmpty) {
        result.add(line);
      }
    }
    return result;
  }

  static String? _line(Map<String, dynamic> action, WorkoutPlan? plan) {
    final String type = action['type'] as String? ?? '';
    final String targetId = action['target_id'] as String? ?? '';
    final Map<String, dynamic> changes = action['changes'] is Map
        ? Map<String, dynamic>.from(action['changes'] as Map)
        : <String, dynamic>{};
    final String? preview = action['preview'] as String?;
    if (preview != null && preview.trim().isNotEmpty) {
      return preview.trim();
    }

    switch (type) {
      case 'add_exercise':
        return 'Add ${_exerciseLabel(changes, plan, targetId)} · ${_setsReps(changes)} on ${_dayLabel(changes, plan, targetId)}';
      case 'remove_exercise':
        return 'Remove ${_exerciseLabel(changes, plan, targetId)} from ${_dayLabel(changes, plan, targetId)}';
      case 'replace_exercise':
        return 'Replace ${_named(plan, targetId) ?? 'exercise'} with ${_exerciseLabel(changes, plan, targetId)} on ${_dayLabel(changes, plan, targetId)}';
      case 'modify_workout_exercise':
        return 'Update ${_named(plan, targetId) ?? _exerciseLabel(changes, plan, targetId)} to ${_setsReps(changes)}';
      case 'modify_workout_day':
        final int? weekday = Formatters.weekdayFrom(changes['weekday']);
        if (weekday != null) {
          return 'Move ${_dayLabel(changes, plan, targetId)} to ${Formatters.weekdayName(weekday)}';
        }
        if (changes['name'] is String) {
          return 'Rename day to ${changes['name']}';
        }
        return 'Update ${_dayLabel(changes, plan, targetId)}';
      case 'update_training_plan':
      case 'create_workout_plan':
        return _planLine(changes);
      case 'add_food_log':
        final String food = changes['food_name'] as String? ?? 'food';
        final Object? qty = changes['quantity'];
        final String slot = changes['meal_slot'] as String? ?? 'meal';
        if (qty != null) {
          return 'Log $food · $qty for $slot';
        }
        return 'Log $food for $slot';
      case 'update_nutrition_targets':
        final List<String> bits = <String>[];
        if (changes['calories'] != null) {
          bits.add('${changes['calories']} kcal');
        }
        if (changes['protein_g'] != null) {
          bits.add('${changes['protein_g']}g protein');
        }
        if (bits.isEmpty) {
          return 'Update nutrition targets';
        }
        return 'Set ${bits.join(' · ')}';
      case 'update_goal':
        if (changes['target_weight_kg'] != null) {
          return 'Set goal weight to ${changes['target_weight_kg']} kg';
        }
        if (changes['goal_type'] is String) {
          return 'Update goal';
        }
        return 'Update goal';
      case 'record_weight':
        if (changes['weight_kg'] != null) {
          return 'Log weight · ${changes['weight_kg']} kg';
        }
        return 'Log weight';
      case 'update_profile':
        return 'Update profile';
      default:
        return null;
    }
  }

  static String _planLine(Map<String, dynamic> changes) {
    final List<String> lines = <String>[];
    if (changes['days_per_week'] != null) {
      lines.add('Train ${changes['days_per_week']} days per week');
    }
    final int? removeWeekday = Formatters.weekdayFrom(
      changes['remove_weekday'],
    );
    if (removeWeekday != null) {
      lines.add('Drop ${Formatters.weekdayName(removeWeekday)}');
    }
    if (changes['add_workout_day'] is Map) {
      final Map<String, dynamic> day = Map<String, dynamic>.from(
        changes['add_workout_day'] as Map,
      );
      final int? weekday = Formatters.weekdayFrom(day['weekday']);
      final String name = day['name'] as String? ?? 'New workout';
      if (weekday != null) {
        lines.add('Add ${Formatters.weekdayName(weekday)}: $name');
      } else {
        lines.add('Add $name');
      }
    }
    if (lines.isEmpty) {
      return 'Update training plan';
    }
    return lines.join('\n');
  }

  static String _setsReps(Map<String, dynamic> changes) {
    final Object? sets = changes['sets'] ?? changes['target_sets'];
    final Object? reps = changes['reps'] ?? changes['target_reps_min'];
    if (sets != null && reps != null) {
      return '$sets × $reps';
    }
    if (sets != null) {
      return '$sets sets';
    }
    if (reps != null) {
      return '$reps reps';
    }
    return 'as discussed';
  }

  static String _exerciseLabel(
    Map<String, dynamic> changes,
    WorkoutPlan? plan,
    String targetId,
  ) {
    final String named =
        changes['exercise_name'] as String? ?? changes['name'] as String? ?? '';
    if (named.isNotEmpty) {
      return named;
    }
    return _named(plan, targetId) ?? 'exercise';
  }

  static String _dayLabel(
    Map<String, dynamic> changes,
    WorkoutPlan? plan,
    String targetId,
  ) {
    final String dayName = changes['day_name'] as String? ?? '';
    if (dayName.isNotEmpty) {
      return dayName;
    }
    final int? weekday = Formatters.weekdayFrom(changes['weekday']);
    if (weekday != null) {
      return Formatters.weekdayName(weekday);
    }
    if (plan != null) {
      for (final WorkoutDay day in plan.days) {
        if (day.id == targetId) {
          return Formatters.weekdayName(day.weekday);
        }
        for (final WorkoutExercise item in day.exercises) {
          if (item.id == targetId) {
            return Formatters.weekdayName(day.weekday);
          }
        }
      }
    }
    return 'your workout';
  }

  static String? _named(WorkoutPlan? plan, String targetId) {
    if (plan == null || targetId.isEmpty) {
      return null;
    }
    for (final WorkoutDay day in plan.days) {
      if (day.id == targetId) {
        return day.name;
      }
      for (final WorkoutExercise item in day.exercises) {
        if (item.id == targetId) {
          return item.exercise.name;
        }
      }
    }
    return null;
  }
}
