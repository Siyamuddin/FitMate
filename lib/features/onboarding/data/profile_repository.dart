import 'package:fitmate/core/constants/enums.dart';
import 'package:fitmate/core/errors/app_exception.dart';
import 'package:fitmate/core/errors/error_mapper.dart';
import 'package:fitmate/core/networking/edge_functions.dart';
import 'package:fitmate/core/networking/supabase_provider.dart';
import 'package:fitmate/core/utils/fitness_calc.dart';
import 'package:fitmate/features/onboarding/domain/profile_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  ProfileRepository({SupabaseClient? client}) : _client = client ?? SupabaseProvider.client;

  final SupabaseClient _client;

  Future<Profile?> fetchCurrent() async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }
    try {
      final dynamic row = await _client.from('profiles').select().eq('user_id', userId).maybeSingle();
      if (row == null) {
        return null;
      }
      return Profile.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<void> completeOnboarding(OnboardingDraft draft) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailure('You need to sign in first.');
    }
    try {
      await _client.from('profiles').update(<String, dynamic>{
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
      }).eq('user_id', userId);

      await _client.from('fitness_goals').update(<String, dynamic>{'is_active': false}).eq('user_id', userId);
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
      await _client.from('user_equipment').insert(
        draft.equipment
            .map((EquipmentType item) => <String, dynamic>{
                  'user_id': userId,
                  'equipment': equipmentValues[item],
                })
            .toList(),
      );

      await _client.from('user_food_rules').delete().eq('user_id', userId);
      final List<Map<String, dynamic>> rules = <Map<String, dynamic>>[
        ...draft.allergies.map((String value) => <String, dynamic>{
              'user_id': userId,
              'rule_type': 'allergy',
              'value': value,
            }),
        ...draft.dislikedFoods.map((String value) => <String, dynamic>{
              'user_id': userId,
              'rule_type': 'dislike',
              'value': value,
            }),
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
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<Map<String, dynamic>> generatePlan() {
    return EdgeFunctions.invoke('generate-plan');
  }
}
