enum Sex { male, female, other }

enum ActivityLevel {
  sedentary,
  lightlyActive,
  moderatelyActive,
  veryActive,
  extraActive,
}

enum TrainingExperience { beginner, intermediate, advanced }

enum TrainingEnvironment { home, gym, outdoor, combination }

enum GoalType {
  loseFat,
  buildMuscle,
  getStronger,
  improveFitness,
  maintainWeight,
  custom,
}

enum EquipmentType {
  bodyweight,
  dumbbells,
  barbell,
  bench,
  resistanceBands,
  pullUpBar,
  machines,
  cableMachine,
  kettlebells,
  other,
}

enum DietType {
  noPreference,
  balanced,
  highProtein,
  vegetarian,
  vegan,
  halal,
  keto,
  mediterranean,
}

enum CookingAbility { none, basic, intermediate, advanced }

enum FoodBudget { low, medium, flexible }

enum MealSlot { breakfast, lunch, dinner, snack }

enum WorkoutSessionStatus { inProgress, paused, completed, abandoned }

enum PlanStatus { draft, active, completed, archived }

const Map<GoalType, String> goalTypeValues = <GoalType, String>{
  GoalType.loseFat: 'lose_fat',
  GoalType.buildMuscle: 'build_muscle',
  GoalType.getStronger: 'get_stronger',
  GoalType.improveFitness: 'improve_fitness',
  GoalType.maintainWeight: 'maintain_weight',
  GoalType.custom: 'custom',
};

const Map<ActivityLevel, String> activityLevelValues = <ActivityLevel, String>{
  ActivityLevel.sedentary: 'sedentary',
  ActivityLevel.lightlyActive: 'lightly_active',
  ActivityLevel.moderatelyActive: 'moderately_active',
  ActivityLevel.veryActive: 'very_active',
  ActivityLevel.extraActive: 'extra_active',
};

const Map<EquipmentType, String> equipmentValues = <EquipmentType, String>{
  EquipmentType.bodyweight: 'bodyweight',
  EquipmentType.dumbbells: 'dumbbells',
  EquipmentType.barbell: 'barbell',
  EquipmentType.bench: 'bench',
  EquipmentType.resistanceBands: 'resistance_bands',
  EquipmentType.pullUpBar: 'pull_up_bar',
  EquipmentType.machines: 'machines',
  EquipmentType.cableMachine: 'cable_machine',
  EquipmentType.kettlebells: 'kettlebells',
  EquipmentType.other: 'other',
};

T enumFromValue<T extends Enum>(Map<T, String> values, String? raw, T fallback) {
  if (raw == null) {
    return fallback;
  }
  for (final MapEntry<T, String> entry in values.entries) {
    if (entry.value == raw) {
      return entry.key;
    }
  }
  return fallback;
}
