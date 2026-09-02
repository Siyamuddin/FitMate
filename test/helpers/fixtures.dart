import 'package:fitmate/core/constants/enums.dart';
import 'package:fitmate/features/auth/domain/auth_repository.dart';
import 'package:fitmate/features/nutrition/data/nutrition_repository.dart';
import 'package:fitmate/features/onboarding/domain/profile_models.dart';
import 'package:fitmate/features/progress/domain/progress_snapshot.dart';
import 'package:fitmate/features/workout/domain/workout_models.dart';
import 'package:fitmate/services/health/health_service.dart';

const AppUser testUser = AppUser(id: 'user-1', email: 'siyam@test.com');

const Exercise pushUp = Exercise(
  id: 'ex-pushup',
  name: 'Push-up',
  primaryMuscle: 'chest',
);

const Exercise gobletSquat = Exercise(
  id: 'ex-squat',
  name: 'Goblet Squat',
  primaryMuscle: 'legs',
);

const WorkoutExercise mondayPushUp = WorkoutExercise(
  id: 'we-pushup',
  exercise: pushUp,
  sortOrder: 0,
  targetSets: 3,
  targetRepsMin: 10,
  targetRepsMax: 10,
  restSeconds: 60,
);

final WorkoutDay mondayDay = WorkoutDay(
  id: 'day-mon',
  planId: 'plan-1',
  weekday: 1,
  name: 'Push',
  estimatedDurationMinutes: 45,
  exercises: const <WorkoutExercise>[mondayPushUp],
);

final WorkoutDay todayDay = WorkoutDay(
  id: 'day-today',
  planId: 'plan-1',
  weekday: DateTime.now().weekday % 7,
  name: 'Today Strength',
  estimatedDurationMinutes: 40,
  exercises: const <WorkoutExercise>[mondayPushUp],
);

final WorkoutPlan testPlan = WorkoutPlan(
  id: 'plan-1',
  name: 'Foundation',
  days: <WorkoutDay>[mondayDay, todayDay],
);

final List<Exercise> testCatalog = <Exercise>[pushUp, gobletSquat];

final Profile onboardedProfile = Profile(
  id: 'profile-1',
  userId: testUser.id,
  displayName: 'Siyam',
  age: 25,
  sex: Sex.male,
  heightCm: 170,
  activityLevel: ActivityLevel.moderatelyActive,
  trainingExperience: TrainingExperience.beginner,
  trainingEnvironment: TrainingEnvironment.gym,
  onboardingCompletedAt: DateTime.utc(2026, 1, 1),
);

const Profile incompleteProfile = Profile(
  id: 'profile-1',
  userId: 'user-1',
  displayName: 'Siyam',
);

final PersonalDetails testDetails = PersonalDetails(
  profile: onboardedProfile,
  currentWeightKg: 74,
  targetWeightKg: 68,
  goalType: GoalType.loseFat,
);

const DailyNutrition testNutrition = DailyNutrition(
  calories: 420,
  protein: 32,
  carbohydrates: 40,
  fat: 12,
  calorieTarget: 2100,
  proteinTarget: 150,
);

const FoodLog testFoodLog = FoodLog(
  id: 'log-1',
  foodName: 'Chicken',
  mealSlot: 'lunch',
  calories: 250,
  protein: 32,
  quantity: 150,
);

const Food chicken = Food(
  id: 'food-chicken',
  name: 'Chicken',
  servingSize: 100,
  servingUnit: 'g',
  calories: 165,
  protein: 31,
  carbohydrates: 0,
  fat: 3.6,
);

const ProgressSnapshot testProgress = ProgressSnapshot(
  weights: <double>[74.8, 74.3, 74.0],
  currentWeight: 74,
  targetWeight: 68,
  workoutsThisWeek: 2,
  workoutsPlanned: 4,
);

const HealthData testHealth = HealthData(steps: 4321, activeEnergy: 220);
