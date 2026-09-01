import 'package:flutter_test/flutter_test.dart';
import 'package:fitmate/features/workout/domain/workout_models.dart';

void main() {
  test('WorkoutExercise.fromJson accepts missing nested exercise and string numbers', () {
    final WorkoutExercise item = WorkoutExercise.fromJson(<String, dynamic>{
      'id': 'we-1',
      'exercise_id': 'ex-1',
      'name': 'Goblet Squat',
      'sort_order': '2',
      'target_sets': '4',
      'target_reps_min': 10.0,
      'rest_seconds': '60',
    });
    expect(item.id, 'we-1');
    expect(item.exercise.id, 'ex-1');
    expect(item.exercise.name, 'Goblet Squat');
    expect(item.sortOrder, 2);
    expect(item.targetSets, 4);
    expect(item.targetRepsMin, 10);
    expect(item.restSeconds, 60);
  });

  test('WorkoutDay.fromJson accepts weekday as double', () {
    final WorkoutDay day = WorkoutDay.fromJson(<String, dynamic>{
      'id': 'day-1',
      'plan_id': 'plan-1',
      'weekday': 3.0,
      'name': 'Push',
      'workout_exercises': <dynamic>[],
    });
    expect(day.weekday, 3);
    expect(day.exercises, isEmpty);
  });
}
