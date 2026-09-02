import 'package:uuid/uuid.dart';
import 'package:fitmate/core/constants/enums.dart';
import 'package:fitmate/core/errors/app_exception.dart';
import 'package:fitmate/core/errors/error_mapper.dart';
import 'package:fitmate/core/local/local_store.dart';
import 'package:fitmate/core/local/snapshot_keys.dart';
import 'package:fitmate/core/networking/edge_functions.dart';
import 'package:fitmate/core/networking/supabase_provider.dart';
import 'package:fitmate/core/utils/fitness_calc.dart';
import 'package:fitmate/features/nutrition/data/nutrition_repository.dart';
import 'package:fitmate/features/onboarding/domain/profile_models.dart';
import 'package:fitmate/features/progress/domain/progress_snapshot.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  ProfileRepository({
    required LocalStore store,
    VoidCallback? onChanged,
    SupabaseClient? client,
  }) : _store = store,
       _onChanged = onChanged,
       _client = client ?? SupabaseProvider.client;

  final LocalStore _store;
  final VoidCallback? _onChanged;
  final SupabaseClient _client;
  int _quietDepth = 0;

  Future<T> transact<T>(Future<T> Function() body) async {
    _quietDepth++;
    try {
      return await body();
    } finally {
      _quietDepth--;
      if (_quietDepth == 0) {
        _notify();
      }
    }
  }

  void _notify() {
    if (_quietDepth == 0) {
      _onChanged?.call();
    }
  }

  Future<Profile?> fetchCurrent() async {
    await _store.ensureReady();
    final Map<String, dynamic>? cached = await _store.getJson(
      SnapshotKeys.profile,
    );
    if (cached != null) {
      return Profile.fromJson(cached);
    }
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }
    try {
      final dynamic row = await _client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      final Profile profile = Profile.fromJson(
        Map<String, dynamic>.from(row as Map),
      );
      await _store.setJson(SnapshotKeys.profile, profile.toJson());
      return profile;
    } catch (_) {
      return null;
    }
  }

  Future<void> completeOnboarding(OnboardingDraft draft) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailure('You need to sign in first.');
    }
    try {
      await _client
          .from('profiles')
          .update(<String, dynamic>{
            'age': draft.age,
            'sex': draft.sex.name,
            'height_cm': draft.heightCm,
            'activity_level': activityLevelValues[draft.activityLevel],
            'training_experience': draft.experience.name,
            'training_environment': const <TrainingEnvironment, String>{
              TrainingEnvironment.home: 'home',
              TrainingEnvironment.gym: 'gym',
              TrainingEnvironment.outdoor: 'outdoor',
              TrainingEnvironment.combination: 'combination',
            }[draft.environment],
            'onboarding_completed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', userId);

      await _client
          .from('fitness_goals')
          .update(<String, dynamic>{'is_active': false})
          .eq('user_id', userId);
      await _client.from('fitness_goals').insert(<String, dynamic>{
        'user_id': userId,
        'goal_type': goalTypeValues[draft.goalType],
        'custom_goal_text': draft.customGoal,
        'target_weight_kg': draft.targetWeightKg,
        'is_active': true,
      });

      await _client.from('body_metrics').insert(<String, dynamic>{
        'user_id': userId,
        'weight_kg': draft.weightKg,
        'body_fat_percentage': draft.bodyFat,
        'waist_cm': draft.waistCm,
      });

      await _client.from('user_preferences').upsert(<String, dynamic>{
        'user_id': userId,
        'training_days_per_week': draft.daysPerWeek,
        'preferred_weekdays': draft.preferredWeekdays,
        'session_duration_minutes': draft.sessionMinutes,
        'diet_type': const <DietType, String>{
          DietType.noPreference: 'no_preference',
          DietType.balanced: 'balanced',
          DietType.highProtein: 'high_protein',
          DietType.vegetarian: 'vegetarian',
          DietType.vegan: 'vegan',
          DietType.halal: 'halal',
          DietType.keto: 'keto',
          DietType.mediterranean: 'mediterranean',
        }[draft.dietType],
        'meals_per_day': draft.mealsPerDay,
        'cooking_ability': draft.cookingAbility.name,
        'food_budget': draft.foodBudget.name,
        'sleep_hours': draft.sleepHours,
        'injuries': draft.injuries,
        'limitations': draft.limitations,
      }, onConflict: 'user_id');

      await _client.from('user_equipment').delete().eq('user_id', userId);
      await _client
          .from('user_equipment')
          .insert(
            draft.equipment
                .map(
                  (EquipmentType item) => <String, dynamic>{
                    'user_id': userId,
                    'equipment': equipmentValues[item],
                  },
                )
                .toList(),
          );

      await _client.from('user_food_rules').delete().eq('user_id', userId);
      final List<Map<String, dynamic>> rules = <Map<String, dynamic>>[
        ...draft.allergies.map(
          (String value) => <String, dynamic>{
            'user_id': userId,
            'rule_type': 'allergy',
            'value': value,
          },
        ),
        ...draft.dislikedFoods.map(
          (String value) => <String, dynamic>{
            'user_id': userId,
            'rule_type': 'dislike',
            'value': value,
          },
        ),
      ];
      if (rules.isNotEmpty) {
        await _client.from('user_food_rules').insert(rules);
      }

      final NutritionTargets targets = FitnessCalculator.targets(
        age: draft.age,
        sex: draft.sex,
        heightCm: draft.heightCm,
        weightKg: draft.weightKg,
        activityLevel: draft.activityLevel,
        goalType: draft.goalType,
      );
      await _client.from('nutrition_targets').upsert(<String, dynamic>{
        'user_id': userId,
        'calories': targets.calories,
        'protein_g': targets.proteinG,
        'carbohydrates_g': targets.carbohydratesG,
        'fat_g': targets.fatG,
        'bmr': targets.bmr,
        'tdee': targets.tdee,
      }, onConflict: 'user_id');
      final Profile? profile = await fetchCurrent();
      if (profile != null) {
        final Profile onboarded = profile.copyWith();
        await _store.setJson(
          SnapshotKeys.profile,
          Profile(
            id: onboarded.id,
            userId: onboarded.userId,
            displayName: onboarded.displayName,
            age: draft.age,
            sex: draft.sex,
            heightCm: draft.heightCm,
            activityLevel: draft.activityLevel,
            trainingExperience: draft.experience,
            trainingEnvironment: draft.environment,
            role: onboarded.role,
            onboardingCompletedAt: DateTime.now().toUtc(),
          ).toJson(),
        );
        await _store.setJson(
          SnapshotKeys.personalDetails,
          PersonalDetails(
            profile: Profile.fromJson(
              (await _store.getJson(SnapshotKeys.profile))!,
            ),
            currentWeightKg: draft.weightKg,
            targetWeightKg: draft.targetWeightKg,
            goalType: draft.goalType,
          ).toJson(),
        );
        await _store.setJson(SnapshotKeys.nutritionTargets, targets.toJson());
        _notify();
      }
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<PersonalDetails?> fetchPersonalDetails() async {
    await _store.ensureReady();
    final Map<String, dynamic>? cached = await _store.getJson(
      SnapshotKeys.personalDetails,
    );
    if (cached != null) {
      return PersonalDetails.fromJson(cached);
    }
    final Profile? profile = await fetchCurrent();
    if (profile == null) {
      return null;
    }
    return PersonalDetails(profile: profile);
  }

  Future<void> updateProfileFields({
    String? displayName,
    int? age,
    Sex? sex,
    double? heightCm,
    ActivityLevel? activityLevel,
    TrainingExperience? trainingExperience,
    TrainingEnvironment? trainingEnvironment,
    bool recalculateNutrition = false,
  }) async {
    final String userId = _requireUserId();
    final Map<String, dynamic> patch = <String, dynamic>{};
    if (displayName != null) {
      patch['display_name'] = displayName;
    }
    if (age != null) {
      patch['age'] = age;
    }
    if (sex != null) {
      patch['sex'] = sex.name;
    }
    if (heightCm != null) {
      patch['height_cm'] = heightCm;
    }
    if (activityLevel != null) {
      patch['activity_level'] = activityLevelValues[activityLevel];
    }
    if (trainingExperience != null) {
      patch['training_experience'] = trainingExperience.name;
    }
    if (trainingEnvironment != null) {
      patch['training_environment'] = const <TrainingEnvironment, String>{
        TrainingEnvironment.home: 'home',
        TrainingEnvironment.gym: 'gym',
        TrainingEnvironment.outdoor: 'outdoor',
        TrainingEnvironment.combination: 'combination',
      }[trainingEnvironment];
    }
    if (patch.isEmpty) {
      return;
    }
    try {
      final Profile? current = await fetchCurrent();
      if (current != null) {
        final Profile next = current.copyWith(
          displayName: displayName,
          age: age,
          sex: sex,
          heightCm: heightCm,
          activityLevel: activityLevel,
          trainingExperience: trainingExperience,
          trainingEnvironment: trainingEnvironment,
        );
        await _store.setJson(SnapshotKeys.profile, next.toJson());
        final PersonalDetails? details = await fetchPersonalDetails();
        if (details != null) {
          await _store.setJson(
            SnapshotKeys.personalDetails,
            details.copyWith(profile: next).toJson(),
          );
        }
      }
      await _store.enqueue(
        type: OutboxType.updateProfile,
        entity: SnapshotKeys.profile,
        payload: <String, dynamic>{'user_id': userId, 'patch': patch},
      );
      if (recalculateNutrition) {
        await _recalculateNutritionTargets();
      }
      _notify();
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<void> logWeight(double weightKg) async {
    final String userId = _requireUserId();
    final String id = const Uuid().v4();
    try {
      final PersonalDetails? details = await fetchPersonalDetails();
      if (details != null) {
        await _store.setJson(
          SnapshotKeys.personalDetails,
          details.copyWith(currentWeightKg: weightKg).toJson(),
        );
      }
      final Map<String, dynamic>? progressJson = await _store.getJson(
        SnapshotKeys.progress,
      );
      final ProgressSnapshot progress = progressJson == null
          ? ProgressSnapshot(
              weights: <double>[weightKg],
              currentWeight: weightKg,
            )
          : ProgressSnapshot.fromJson(progressJson);
      await _store.setJson(
        SnapshotKeys.progress,
        progress
            .copyWith(
              weights: <double>[...progress.weights, weightKg],
              currentWeight: weightKg,
            )
            .toJson(),
      );
      await _store.enqueue(
        type: OutboxType.insertBodyMetric,
        entity: SnapshotKeys.progress,
        payload: <String, dynamic>{
          'id': id,
          'user_id': userId,
          'weight_kg': weightKg,
          'recorded_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      await _recalculateNutritionTargets();
      _notify();
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<void> updateActiveGoal({
    GoalType? goalType,
    double? targetWeightKg,
  }) async {
    final String userId = _requireUserId();
    try {
      final PersonalDetails? details = await fetchPersonalDetails();
      if (details != null) {
        await _store.setJson(
          SnapshotKeys.personalDetails,
          details
              .copyWith(goalType: goalType, targetWeightKg: targetWeightKg)
              .toJson(),
        );
      }
      final Map<String, dynamic>? progressJson = await _store.getJson(
        SnapshotKeys.progress,
      );
      if (progressJson != null && targetWeightKg != null) {
        await _store.setJson(
          SnapshotKeys.progress,
          ProgressSnapshot.fromJson(
            progressJson,
          ).copyWith(targetWeight: targetWeightKg).toJson(),
        );
      }
      await _store.enqueue(
        type: OutboxType.upsertGoal,
        entity: SnapshotKeys.personalDetails,
        payload: <String, dynamic>{
          'row': <String, dynamic>{
            'id': const Uuid().v4(),
            'user_id': userId,
            'goal_type':
                goalTypeValues[goalType ??
                    details?.goalType ??
                    GoalType.improveFitness],
            'target_weight_kg': targetWeightKg ?? details?.targetWeightKg,
            'is_active': true,
          },
        },
      );
      await _recalculateNutritionTargets();
      _notify();
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<Map<String, dynamic>> generatePlan() {
    return EdgeFunctions.invoke('generate-plan');
  }

  String _requireUserId() {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailure('You need to sign in first.');
    }
    return userId;
  }

  Future<void> _recalculateNutritionTargets() async {
    final PersonalDetails? details = await fetchPersonalDetails();
    final Profile? profile = details?.profile;
    final double? weightKg = details?.currentWeightKg;
    if (profile == null ||
        profile.age == null ||
        profile.sex == null ||
        profile.heightCm == null ||
        profile.activityLevel == null ||
        weightKg == null) {
      return;
    }
    final NutritionTargets targets = FitnessCalculator.targets(
      age: profile.age!,
      sex: profile.sex!,
      heightCm: profile.heightCm!,
      weightKg: weightKg,
      activityLevel: profile.activityLevel!,
      goalType: details?.goalType ?? GoalType.maintainWeight,
    );
    await _store.setJson(SnapshotKeys.nutritionTargets, targets.toJson());
    final DailyNutrition today = DailyNutrition.fromJson(
      await _store.getJson(SnapshotKeys.todayNutrition) ?? <String, dynamic>{},
    );
    await _store.setJson(
      SnapshotKeys.todayNutrition,
      today
          .copyWith(
            calorieTarget: targets.calories,
            proteinTarget: targets.proteinG,
          )
          .toJson(),
    );
    await _store.enqueue(
      type: OutboxType.upsertNutritionTargets,
      entity: SnapshotKeys.nutritionTargets,
      payload: <String, dynamic>{
        'user_id': profile.userId,
        'calories': targets.calories,
        'protein_g': targets.proteinG,
        'carbohydrates_g': targets.carbohydratesG,
        'fat_g': targets.fatG,
        'bmr': targets.bmr,
        'tdee': targets.tdee,
      },
    );
  }
}

typedef VoidCallback = void Function();
