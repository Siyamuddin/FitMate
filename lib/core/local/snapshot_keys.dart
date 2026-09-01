class SnapshotKeys {
  const SnapshotKeys._();

  static const String profile = 'profile';
  static const String personalDetails = 'personal_details';
  static const String activePlan = 'active_plan';
  static const String exerciseCatalog = 'exercise_catalog';
  static const String todayNutrition = 'today_nutrition';
  static const String foodLogsToday = 'food_logs_today';
  static const String foodsCache = 'foods_cache';
  static const String progress = 'progress_snapshot';
  static const String workoutHistory = 'workout_history';
  static const String coachMessages = 'coach_messages';
  static const String nutritionTargets = 'nutrition_targets';
  static const String setLogs = 'set_logs';
  static const String sessions = 'sessions';
}

class OutboxType {
  const OutboxType._();

  static const String upsertSetLog = 'upsertSetLog';
  static const String upsertSession = 'upsertSession';
  static const String insertDay = 'insertDay';
  static const String updateDay = 'updateDay';
  static const String deleteDay = 'deleteDay';
  static const String insertExercise = 'insertExercise';
  static const String updateExercise = 'updateExercise';
  static const String deleteExercise = 'deleteExercise';
  static const String replaceSets = 'replaceSets';
  static const String updatePlan = 'updatePlan';
  static const String updatePreferences = 'updatePreferences';
  static const String upsertCustomExercise = 'upsertCustomExercise';
  static const String insertFoodLog = 'insertFoodLog';
  static const String deleteFoodLog = 'deleteFoodLog';
  static const String updateProfile = 'updateProfile';
  static const String insertBodyMetric = 'insertBodyMetric';
  static const String upsertGoal = 'upsertGoal';
  static const String upsertNutritionTargets = 'upsertNutritionTargets';
  static const String ackAiActions = 'ackAiActions';
}
