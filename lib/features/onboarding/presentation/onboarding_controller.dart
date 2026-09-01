import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/constants/enums.dart';
import 'package:fitmate/core/sync/sync_engine.dart';
import 'package:fitmate/features/onboarding/data/profile_repository.dart';
import 'package:fitmate/features/onboarding/domain/profile_models.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((Ref ref) {
  return ProfileRepository(
    store: ref.read(localStoreProvider),
    onChanged: () => notifyLocalChange(ref),
  );
});

final currentProfileProvider = FutureProvider<Profile?>((Ref ref) async {
  ref.watch(localEpochProvider);
  await ref.read(localStoreProvider).ensureReady();
  return ref.read(profileRepositoryProvider).fetchCurrent();
});

final personalDetailsProvider = FutureProvider<PersonalDetails?>((Ref ref) async {
  ref.watch(localEpochProvider);
  await ref.read(localStoreProvider).ensureReady();
  return ref.read(profileRepositoryProvider).fetchPersonalDetails();
});

class OnboardingController extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => OnboardingDraft();

  void setGoal(GoalType type) {
    state.goalType = type;
    state = _copy();
  }

  void setBody({int? age, Sex? sex, double? heightCm, double? weightKg, double? targetWeightKg}) {
    if (age != null) state.age = age;
    if (sex != null) state.sex = sex;
    if (heightCm != null) state.heightCm = heightCm;
    if (weightKg != null) state.weightKg = weightKg;
    if (targetWeightKg != null) state.targetWeightKg = targetWeightKg;
    state = _copy();
  }

  void setActivity(ActivityLevel level) {
    state.activityLevel = level;
    state = _copy();
  }

  void setExperience(TrainingExperience value) {
    state.experience = value;
    state = _copy();
  }

  void setEnvironment(TrainingEnvironment value) {
    state.environment = value;
    state = _copy();
  }

  void toggleEquipment(EquipmentType value) {
    if (state.equipment.contains(value)) {
      state.equipment.remove(value);
    } else {
      state.equipment.add(value);
    }
    state = _copy();
  }

  void setSchedule({int? days, List<int>? weekdays, int? minutes}) {
    if (days != null) state.daysPerWeek = days;
    if (weekdays != null) state.preferredWeekdays = weekdays;
    if (minutes != null) state.sessionMinutes = minutes;
    state = _copy();
  }

  void setDiet(DietType type) {
    state.dietType = type;
    state = _copy();
  }

  Future<void> submit() {
    return ref.read(profileRepositoryProvider).completeOnboarding(state);
  }

  OnboardingDraft _copy() {
    final OnboardingDraft next = OnboardingDraft()
      ..goalType = state.goalType
      ..customGoal = state.customGoal
      ..age = state.age
      ..sex = state.sex
      ..heightCm = state.heightCm
      ..weightKg = state.weightKg
      ..targetWeightKg = state.targetWeightKg
      ..activityLevel = state.activityLevel
      ..experience = state.experience
      ..environment = state.environment
      ..equipment = List<EquipmentType>.from(state.equipment)
      ..daysPerWeek = state.daysPerWeek
      ..preferredWeekdays = List<int>.from(state.preferredWeekdays)
      ..sessionMinutes = state.sessionMinutes
      ..dietType = state.dietType
      ..mealsPerDay = state.mealsPerDay
      ..cookingAbility = state.cookingAbility
      ..foodBudget = state.foodBudget
      ..allergies = List<String>.from(state.allergies)
      ..dislikedFoods = List<String>.from(state.dislikedFoods)
      ..bodyFat = state.bodyFat
      ..waistCm = state.waistCm
      ..sleepHours = state.sleepHours
      ..injuries = state.injuries
      ..limitations = state.limitations;
    return next;
  }
}

final onboardingControllerProvider = NotifierProvider<OnboardingController, OnboardingDraft>(
  OnboardingController.new,
);
