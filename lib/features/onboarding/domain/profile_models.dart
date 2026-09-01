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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'display_name': displayName,
      'age': age,
      'sex': sex?.name,
      'height_cm': heightCm,
      'activity_level': activityLevel == null ? null : activityLevelValues[activityLevel],
      'training_experience': trainingExperience?.name,
      'training_environment': trainingEnvironment == null
          ? null
          : const <TrainingEnvironment, String>{
              TrainingEnvironment.home: 'home',
              TrainingEnvironment.gym: 'gym',
              TrainingEnvironment.outdoor: 'outdoor',
              TrainingEnvironment.combination: 'combination',
            }[trainingEnvironment],
      'role': role,
      'onboarding_completed_at': onboardingCompletedAt?.toUtc().toIso8601String(),
    };
  }

  Profile copyWith({
    String? displayName,
    int? age,
    Sex? sex,
    double? heightCm,
    ActivityLevel? activityLevel,
    TrainingExperience? trainingExperience,
    TrainingEnvironment? trainingEnvironment,
  }) {
    return Profile(
      id: id,
      userId: userId,
      displayName: displayName ?? this.displayName,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      heightCm: heightCm ?? this.heightCm,
      activityLevel: activityLevel ?? this.activityLevel,
      trainingExperience: trainingExperience ?? this.trainingExperience,
      trainingEnvironment: trainingEnvironment ?? this.trainingEnvironment,
      role: role,
      onboardingCompletedAt: onboardingCompletedAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        userId,
        displayName,
        age,
        sex,
        heightCm,
        activityLevel,
        trainingExperience,
        trainingEnvironment,
        role,
        onboardingCompletedAt,
      ];
}

class PersonalDetails extends Equatable {
  const PersonalDetails({
    required this.profile,
    this.currentWeightKg,
    this.targetWeightKg,
    this.goalType,
  });

  final Profile profile;
  final double? currentWeightKg;
  final double? targetWeightKg;
  final GoalType? goalType;

  PersonalDetails copyWith({
    Profile? profile,
    double? currentWeightKg,
    double? targetWeightKg,
    GoalType? goalType,
  }) {
    return PersonalDetails(
      profile: profile ?? this.profile,
      currentWeightKg: currentWeightKg ?? this.currentWeightKg,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      goalType: goalType ?? this.goalType,
    );
  }

  factory PersonalDetails.fromJson(Map<String, dynamic> json) {
    return PersonalDetails(
      profile: Profile.fromJson(Map<String, dynamic>.from(json['profile'] as Map)),
      currentWeightKg: (json['current_weight_kg'] as num?)?.toDouble(),
      targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble(),
      goalType: json['goal_type'] == null
          ? null
          : enumFromValue(goalTypeValues, json['goal_type'] as String?, GoalType.maintainWeight),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'profile': profile.toJson(),
      'current_weight_kg': currentWeightKg,
      'target_weight_kg': targetWeightKg,
      'goal_type': goalType == null ? null : goalTypeValues[goalType],
    };
  }

  @override
  List<Object?> get props => <Object?>[profile, currentWeightKg, targetWeightKg, goalType];
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
