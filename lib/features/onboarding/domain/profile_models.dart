import 'package:equatable/equatable.dart';
import 'package:fitmate/core/constants/enums.dart';

class Profile extends Equatable {
  const Profile({
    required this.id,
    required this.userId,
    this.displayName,
    this.age,
    this.sex,
    this.heightCm,
    this.activityLevel,
    this.trainingExperience,
    this.trainingEnvironment,
    this.role = 'user',
    this.onboardingCompletedAt,
  });

  final String id;
  final String userId;
  final String? displayName;
  final int? age;
  final Sex? sex;
  final double? heightCm;
  final ActivityLevel? activityLevel;
  final TrainingExperience? trainingExperience;
  final TrainingEnvironment? trainingEnvironment;
  final String role;
  final DateTime? onboardingCompletedAt;

  bool get hasCompletedOnboarding => onboardingCompletedAt != null;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      age: json['age'] as int?,
      sex: json['sex'] == null ? null : enumFromValue(
        const <Sex, String>{Sex.male: 'male', Sex.female: 'female', Sex.other: 'other'},
        json['sex'] as String?,
        Sex.other,
      ),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      activityLevel: json['activity_level'] == null
          ? null
          : enumFromValue(activityLevelValues, json['activity_level'] as String?, ActivityLevel.moderatelyActive),
      trainingExperience: json['training_experience'] == null
          ? null
          : enumFromValue(
              const <TrainingExperience, String>{
                TrainingExperience.beginner: 'beginner',
                TrainingExperience.intermediate: 'intermediate',
                TrainingExperience.advanced: 'advanced',
              },
              json['training_experience'] as String?,
              TrainingExperience.beginner,
            ),
      trainingEnvironment: json['training_environment'] == null
          ? null
          : enumFromValue(
              const <TrainingEnvironment, String>{
                TrainingEnvironment.home: 'home',
                TrainingEnvironment.gym: 'gym',
                TrainingEnvironment.outdoor: 'outdoor',
                TrainingEnvironment.combination: 'combination',
              },
              json['training_environment'] as String?,
              TrainingEnvironment.home,
            ),
      role: json['role'] as String? ?? 'user',
      onboardingCompletedAt: json['onboarding_completed_at'] == null
          ? null
          : DateTime.parse(json['onboarding_completed_at'] as String),
    );
  }

  @override
  List<Object?> get props => <Object?>[id, userId, onboardingCompletedAt, displayName];
}

class OnboardingDraft {
  GoalType goalType = GoalType.loseFat;
  String? customGoal;
  int age = 25;
  Sex sex = Sex.male;
  double heightCm = 170;
  double weightKg = 74;
  double targetWeightKg = 68;
  ActivityLevel activityLevel = ActivityLevel.moderatelyActive;
  TrainingExperience experience = TrainingExperience.beginner;
  TrainingEnvironment environment = TrainingEnvironment.home;
  List<EquipmentType> equipment = <EquipmentType>[EquipmentType.bodyweight, EquipmentType.dumbbells];
  int daysPerWeek = 4;
  List<int> preferredWeekdays = <int>[1, 2, 4, 5];
  int sessionMinutes = 45;
  DietType dietType = DietType.balanced;
  int mealsPerDay = 3;
  CookingAbility cookingAbility = CookingAbility.basic;
  FoodBudget foodBudget = FoodBudget.medium;
  List<String> allergies = <String>[];
  List<String> dislikedFoods = <String>[];
  double? bodyFat;
  double? waistCm;
  double? sleepHours;
  String? injuries;
  String? limitations;
}
