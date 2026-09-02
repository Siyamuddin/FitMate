import 'package:fitmate/core/constants/enums.dart';
import 'package:fitmate/core/errors/app_exception.dart';
import 'package:fitmate/features/coach/domain/ai_action_applier.dart';
import 'package:fitmate/features/nutrition/data/nutrition_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/fakes.dart';
import 'helpers/fixtures.dart';
import 'helpers/pump_app.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  setUpAll(registerTestFallbacks);

  late FakeLocalStore store;
  late MockWorkoutRepository workouts;
  late MockProfileRepository profiles;
  late MockNutritionRepository nutrition;
  late AiActionApplier applier;

  setUp(() {
    store = FakeLocalStore();
    workouts = MockWorkoutRepository();
    profiles = MockProfileRepository();
    nutrition = MockNutritionRepository();
    when(() => workouts.cachedPlan()).thenAnswer((_) async => testPlan);
    when(() => workouts.cachedCatalog()).thenAnswer((_) async => testCatalog);
    when(
      () => workouts.addExercise(
        dayId: any(named: 'dayId'),
        exerciseId: any(named: 'exerciseId'),
        sets: any(named: 'sets'),
        reps: any(named: 'reps'),
        restSeconds: any(named: 'restSeconds'),
      ),
    ).thenAnswer((_) async => 'we-new');
    when(() => workouts.deleteExercise(any())).thenAnswer((_) async {});
    when(
      () => nutrition.cachedFoods(),
    ).thenAnswer((_) async => <Food>[chicken]);
    when(
      () => nutrition.logFood(
        food: any(named: 'food'),
        mealSlot: any(named: 'mealSlot'),
        quantity: any(named: 'quantity'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => nutrition.updateTargets(
        calories: any(named: 'calories'),
        proteinG: any(named: 'proteinG'),
        carbohydratesG: any(named: 'carbohydratesG'),
        fatG: any(named: 'fatG'),
      ),
    ).thenAnswer((Invocation invocation) async {
      final int? calories = invocation.namedArguments[#calories] as int?;
      final double? protein = invocation.namedArguments[#proteinG] as double?;
      if (calories != null && (calories < 800 || calories > 6000)) {
        throw const AppException('That calorie target looks off.');
      }
      if (protein != null && (protein < 20 || protein > 400)) {
        throw const AppException('That protein target looks off.');
      }
    });
    when(
      () => profiles.updateProfileFields(
        age: any(named: 'age'),
        heightCm: any(named: 'heightCm'),
        activityLevel: any(named: 'activityLevel'),
        trainingExperience: any(named: 'trainingExperience'),
        trainingEnvironment: any(named: 'trainingEnvironment'),
        recalculateNutrition: any(named: 'recalculateNutrition'),
      ),
    ).thenAnswer((_) async {});
    applier = AiActionApplier(
      workouts: workouts,
      profiles: profiles,
      store: store,
      nutrition: nutrition,
    );
  });

  test('add_exercise resolves Monday and catalog name', () async {
    await applier.apply(<Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'add_exercise',
        'changes': <String, dynamic>{
          'weekday': 'Monday',
          'exercise_name': 'Goblet Squat',
          'sets': 3,
          'reps': 10,
        },
      },
    ]);
    verify(
      () => workouts.addExercise(
        dayId: 'day-mon',
        exerciseId: 'ex-squat',
        sets: 3,
        reps: 10,
        restSeconds: 60,
      ),
    ).called(1);
    expect(store.pending(), completion(isNotEmpty));
  });

  test('remove_exercise matches by name', () async {
    await applier.apply(<Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'remove_exercise',
        'changes': <String, dynamic>{'exercise_name': 'Push-up', 'weekday': 1},
      },
    ]);
    verify(() => workouts.deleteExercise('we-pushup')).called(1);
  });

  test('replace_exercise deletes then adds on the same day', () async {
    await applier.apply(<Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'replace_exercise',
        'target_id': 'we-pushup',
        'changes': <String, dynamic>{'exercise_name': 'Goblet Squat'},
      },
    ]);
    verify(() => workouts.deleteExercise('we-pushup')).called(1);
    verify(
      () => workouts.addExercise(
        dayId: 'day-mon',
        exerciseId: 'ex-squat',
        sets: 3,
        reps: 10,
        restSeconds: 60,
      ),
    ).called(1);
  });

  test('add_food_log writes a dinner entry', () async {
    await applier.apply(<Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'add_food_log',
        'changes': <String, dynamic>{
          'food_name': 'Chicken',
          'meal_slot': 'dinner',
          'quantity': 150,
        },
      },
    ]);
    verify(
      () => nutrition.logFood(
        food: chicken,
        mealSlot: 'dinner',
        quantity: 150,
      ),
    ).called(1);
  });

  test('unknown day throws', () async {
    await expectLater(
      applier.apply(<Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'add_exercise',
          'changes': <String, dynamic>{
            'weekday': 'Sunday',
            'exercise_name': 'Push-up',
          },
        },
      ]),
      throwsA(
        isA<AppException>().having(
          (AppException e) => e.message,
          'message',
          "I couldn't find that day.",
        ),
      ),
    );
  });

  test('unknown food throws', () async {
    when(() => nutrition.cachedFoods()).thenAnswer((_) async => <Food>[]);
    when(
      () => nutrition.search(any(), online: any(named: 'online')),
    ).thenAnswer((_) async => <Food>[]);
    await expectLater(
      applier.apply(<Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'add_food_log',
          'changes': <String, dynamic>{
            'food_name': 'unicorn steak',
            'meal_slot': 'lunch',
          },
        },
      ]),
      throwsA(isA<AppException>()),
    );
  });

  test('update_nutrition_targets rejects out-of-range calories', () async {
    await expectLater(
      applier.apply(<Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'update_nutrition_targets',
          'changes': <String, dynamic>{'calories': 500},
        },
      ]),
      throwsA(
        isA<AppException>().having(
          (AppException e) => e.message,
          'message',
          'That calorie target looks off.',
        ),
      ),
    );
  });

  test('update_profile forwards gym environment', () async {
    await applier.apply(<Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'update_profile',
        'changes': <String, dynamic>{
          'age': 26,
          'training_environment': 'gym',
        },
      },
    ]);
    verify(
      () => profiles.updateProfileFields(
        age: 26,
        heightCm: null,
        activityLevel: null,
        trainingExperience: null,
        trainingEnvironment: TrainingEnvironment.gym,
        recalculateNutrition: false,
      ),
    ).called(1);
  });

  test('NutritionRepository.updateTargets validates before writing', () async {
    final NutritionRepository repo = NutritionRepository(
      store: FakeLocalStore(),
      client: MockSupabaseClient(),
    );
    await expectLater(
      repo.updateTargets(calories: 500),
      throwsA(isA<AppException>()),
    );
    await expectLater(
      repo.updateTargets(proteinG: 10),
      throwsA(isA<AppException>()),
    );
  });
}
