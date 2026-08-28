import 'package:fitmate/core/constants/enums.dart';

class NutritionTargets {
  const NutritionTargets({
    required this.bmr,
    required this.tdee,
    required this.calories,
    required this.proteinG,
    required this.carbohydratesG,
    required this.fatG,
  });

  final double bmr;
  final double tdee;
  final int calories;
  final double proteinG;
  final double carbohydratesG;
  final double fatG;
}

class FitnessCalculator {
  const FitnessCalculator._();

  static double bmr({
    required int age,
    required Sex sex,
    required double heightCm,
    required double weightKg,
  }) {
    final double base = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
    switch (sex) {
      case Sex.male:
        return base + 5;
      case Sex.female:
        return base - 161;
      case Sex.other:
        return base - 78;
    }
  }

  static double activityMultiplier(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.lightlyActive:
        return 1.375;
      case ActivityLevel.moderatelyActive:
        return 1.55;
      case ActivityLevel.veryActive:
        return 1.725;
      case ActivityLevel.extraActive:
        return 1.9;
    }
  }

  static double tdee({
    required double bmrKcal,
    required ActivityLevel activityLevel,
  }) {
    return bmrKcal * activityMultiplier(activityLevel);
  }

  static NutritionTargets targets({
    required int age,
    required Sex sex,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activityLevel,
    required GoalType goalType,
  }) {
    final double bmrValue = bmr(
      age: age,
      sex: sex,
      heightCm: heightCm,
      weightKg: weightKg,
    );
    final double tdeeValue = tdee(bmrKcal: bmrValue, activityLevel: activityLevel);

    double calorieTarget = tdeeValue;
    switch (goalType) {
      case GoalType.loseFat:
        calorieTarget = tdeeValue - 500;
      case GoalType.buildMuscle:
        calorieTarget = tdeeValue + 250;
      case GoalType.getStronger:
        calorieTarget = tdeeValue + 150;
      case GoalType.improveFitness:
      case GoalType.maintainWeight:
      case GoalType.custom:
        calorieTarget = tdeeValue;
    }

    final double floor = sex == Sex.male ? 1500 : 1200;
    if (calorieTarget < floor) {
      calorieTarget = floor;
    }

    final double proteinPerKg = switch (goalType) {
      GoalType.loseFat => 2.0,
      GoalType.buildMuscle || GoalType.getStronger => 1.8,
      _ => 1.6,
    };
    final double proteinG = weightKg * proteinPerKg;
    final double proteinKcal = proteinG * 4;
    final double fatG = (calorieTarget * 0.25) / 9;
    final double fatKcal = fatG * 9;
    final double carbKcal = (calorieTarget - proteinKcal - fatKcal).clamp(0, 10000);
    final double carbohydratesG = carbKcal / 4;

    return NutritionTargets(
      bmr: bmrValue,
      tdee: tdeeValue,
      calories: calorieTarget.round(),
      proteinG: double.parse(proteinG.toStringAsFixed(1)),
      carbohydratesG: double.parse(carbohydratesG.toStringAsFixed(1)),
      fatG: double.parse(fatG.toStringAsFixed(1)),
    );
  }

  static double weeklyWeightChangeKg(List<double> chronologicalWeights) {
    if (chronologicalWeights.length < 2) {
      return 0;
    }
    return chronologicalWeights.last - chronologicalWeights.first;
  }

  static double goalProgress({
    required double startWeight,
    required double currentWeight,
    required double targetWeight,
  }) {
    final double total = startWeight - targetWeight;
    if (total.abs() < 0.01) {
      return 1;
    }
    return ((startWeight - currentWeight) / total).clamp(0, 1);
  }
}
