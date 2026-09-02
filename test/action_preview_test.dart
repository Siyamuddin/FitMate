import 'package:fitmate/features/coach/domain/action_preview.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fixtures.dart';

void main() {
  test('preview field overrides generated line', () {
    final List<String> lines = ActionPreview.lines(<Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'add_exercise',
        'preview': '  Custom line  ',
        'changes': <String, dynamic>{'exercise_name': 'Push-up'},
      },
    ]);
    expect(lines, <String>['Custom line']);
  });

  test('add_exercise uses plan day names', () {
    final List<String> lines = ActionPreview.lines(<Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'add_exercise',
        'target_id': 'day-mon',
        'changes': <String, dynamic>{
          'exercise_name': 'Push-up',
          'sets': 3,
          'reps': 10,
        },
      },
    ], plan: testPlan);
    expect(lines.single, 'Add Push-up · 3 × 10 on Monday');
  });

  test('remove and replace use exercise names from the plan', () {
    expect(
      ActionPreview.lines(<Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'remove_exercise',
          'target_id': 'we-pushup',
          'changes': <String, dynamic>{},
        },
      ], plan: testPlan),
      <String>['Remove Push-up from Monday'],
    );
    expect(
      ActionPreview.lines(<Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'replace_exercise',
          'target_id': 'we-pushup',
          'changes': <String, dynamic>{'exercise_name': 'Goblet Squat'},
        },
      ], plan: testPlan).single,
      contains('Goblet Squat'),
    );
  });

  test('covers remaining action types', () {
    final List<String> lines = ActionPreview.lines(<Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'modify_workout_exercise',
        'target_id': 'we-pushup',
        'changes': <String, dynamic>{'sets': 4, 'reps': 8},
      },
      <String, dynamic>{
        'type': 'modify_workout_day',
        'target_id': 'day-mon',
        'changes': <String, dynamic>{
          'weekday': 'Friday',
          'day_name': 'Monday',
        },
      },
      <String, dynamic>{
        'type': 'update_training_plan',
        'changes': <String, dynamic>{
          'days_per_week': 4,
          'remove_weekday': 'Wednesday',
        },
      },
      <String, dynamic>{
        'type': 'add_food_log',
        'changes': <String, dynamic>{
          'food_name': 'chicken',
          'quantity': 150,
          'meal_slot': 'dinner',
        },
      },
      <String, dynamic>{
        'type': 'update_nutrition_targets',
        'changes': <String, dynamic>{'calories': 2200, 'protein_g': 160},
      },
      <String, dynamic>{
        'type': 'update_goal',
        'changes': <String, dynamic>{'target_weight_kg': 68},
      },
      <String, dynamic>{
        'type': 'record_weight',
        'changes': <String, dynamic>{'weight_kg': 74.2},
      },
      <String, dynamic>{'type': 'update_profile', 'changes': <String, dynamic>{}},
    ], plan: testPlan);

    expect(lines, containsAll(<String>[
      'Update Push-up to 4 × 8',
      'Move Monday to Friday',
      'Train 4 days per week\nDrop Wednesday',
      'Log chicken · 150 for dinner',
      'Set 2200 kcal · 160g protein',
      'Set goal weight to 68 kg',
      'Log weight · 74.2 kg',
      'Update profile',
    ]));
  });
}
