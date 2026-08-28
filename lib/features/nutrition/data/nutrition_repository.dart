import 'package:fitmate/core/errors/error_mapper.dart';
import 'package:fitmate/core/networking/supabase_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Food {
  const Food({
    required this.id,
    required this.name,
    required this.servingSize,
    required this.servingUnit,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    this.brand,
  });

  final String id;
  final String name;
  final double servingSize;
  final String servingUnit;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final String? brand;

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      servingSize: (json['serving_size'] as num).toDouble(),
      servingUnit: json['serving_unit'] as String,
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbohydrates: (json['carbohydrates'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
    );
  }

  Food scaled(double quantity) {
    final double factor = quantity / servingSize;
    return Food(
      id: id,
      name: name,
      brand: brand,
      servingSize: quantity,
      servingUnit: servingUnit,
      calories: calories * factor,
      protein: protein * factor,
      carbohydrates: carbohydrates * factor,
      fat: fat * factor,
    );
  }
}

class DailyNutrition {
  const DailyNutrition({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    this.calorieTarget,
    this.proteinTarget,
  });

  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final int? calorieTarget;
  final double? proteinTarget;
}

class FoodLog {
  const FoodLog({
    required this.id,
    required this.foodName,
    required this.mealSlot,
    required this.calories,
    required this.protein,
    required this.quantity,
  });

  final String id;
  final String foodName;
  final String mealSlot;
  final double calories;
  final double protein;
  final double quantity;
}

class NutritionRepository {
  NutritionRepository({SupabaseClient? client}) : _client = client ?? SupabaseProvider.client;

  final SupabaseClient _client;

  Future<List<Food>> search(String query) async {
    try {
      final List<dynamic> rows = await _client
          .from('foods')
          .select()
          .ilike('name', '%$query%')
          .eq('is_active', true)
          .limit(30);
      return rows.map((dynamic row) => Food.fromJson(Map<String, dynamic>.from(row as Map))).toList();
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<void> logFood({required Food food, required String mealSlot, required double quantity}) async {
    final Food scaled = food.scaled(quantity);
    try {
      await _client.from('food_logs').insert(<String, dynamic>{
        'user_id': _client.auth.currentUser!.id,
        'food_id': food.id,
        'meal_slot': mealSlot,
        'quantity': quantity,
        'unit': food.servingUnit,
        'calories': scaled.calories,
        'protein': scaled.protein,
        'carbohydrates': scaled.carbohydrates,
        'fat': scaled.fat,
        'source': 'manual',
      });
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<DailyNutrition> today() async {
    final DateTime now = DateTime.now().toUtc();
    final String date = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      final dynamic row = await _client.from('nutrition_daily_logs').select().eq('log_date', date).maybeSingle();
      final dynamic targets = await _client.from('nutrition_targets').select().maybeSingle();
      if (row == null) {
        return DailyNutrition(
          calories: 0,
          protein: 0,
          carbohydrates: 0,
          fat: 0,
          calorieTarget: targets == null ? null : (targets as Map)['calories'] as int?,
          proteinTarget: targets == null ? null : ((targets as Map)['protein_g'] as num?)?.toDouble(),
        );
      }
      final Map<String, dynamic> json = Map<String, dynamic>.from(row as Map);
      return DailyNutrition(
        calories: (json['calories'] as num).toDouble(),
        protein: (json['protein'] as num).toDouble(),
        carbohydrates: (json['carbohydrates'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
        calorieTarget: json['calorie_target'] as int? ?? (targets == null ? null : (targets as Map)['calories'] as int?),
        proteinTarget: (json['protein_target'] as num?)?.toDouble(),
      );
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<List<FoodLog>> todayLogs() async {
    final DateTime start = DateTime.now().toUtc().subtract(Duration(hours: DateTime.now().toUtc().hour, minutes: DateTime.now().toUtc().minute));
    try {
      final List<dynamic> rows = await _client
          .from('food_logs')
          .select('id, quantity, calories, protein, meal_slot, foods(name)')
          .gte('logged_at', start.toIso8601String())
          .order('logged_at');
      return rows.map((dynamic row) {
        final Map<String, dynamic> json = Map<String, dynamic>.from(row as Map);
        return FoodLog(
          id: json['id'] as String,
          foodName: (json['foods'] as Map?)?['name'] as String? ?? 'Food',
          mealSlot: json['meal_slot'] as String,
          calories: (json['calories'] as num).toDouble(),
          protein: (json['protein'] as num).toDouble(),
          quantity: (json['quantity'] as num).toDouble(),
        );
      }).toList();
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<void> deleteLog(String id) async {
    await _client.from('food_logs').delete().eq('id', id);
  }
}
