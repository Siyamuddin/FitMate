import 'package:fitmate/core/constants/enums.dart';
import 'package:fitmate/core/utils/fitness_calc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Mifflin-St Jeor male BMR', () {
    final double value = FitnessCalculator.bmr(
      age: 25,
      sex: Sex.male,
      heightCm: 170,
      weightKg: 74,
    );
    expect(value, closeTo(10 * 74 + 6.25 * 170 - 5 * 25 + 5, 0.01));
  });

  test('fat loss calories stay above the floor', () {
    final NutritionTargets result = FitnessCalculator.targets(
      age: 25,
      sex: Sex.female,
      heightCm: 160,
      weightKg: 50,
      activityLevel: ActivityLevel.sedentary,
      goalType: GoalType.loseFat,
    );
    expect(result.calories, greaterThanOrEqualTo(1200));
    expect(result.proteinG, closeTo(100, 0.2));
  });

  test('weekly weight change uses first and last samples', () {
    expect(FitnessCalculator.weeklyWeightChangeKg(<double>[74.8, 74.3, 74.0, 73.7]), closeTo(-1.1, 0.01));
  });

  test('goal progress is clamped', () {
    expect(FitnessCalculator.goalProgress(startWeight: 74, currentWeight: 71, targetWeight: 68), closeTo(0.5, 0.01));
    expect(FitnessCalculator.goalProgress(startWeight: 74, currentWeight: 60, targetWeight: 68), 1);
  });
}
