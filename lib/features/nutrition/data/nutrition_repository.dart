import 'package:uuid/uuid.dart';
import 'package:fitmate/core/errors/app_exception.dart';
import 'package:fitmate/core/errors/error_mapper.dart';
import 'package:fitmate/core/local/local_store.dart';
import 'package:fitmate/core/local/snapshot_keys.dart';
import 'package:fitmate/core/networking/supabase_provider.dart';
import 'package:fitmate/core/utils/fitness_calc.dart';
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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'brand': brand,
      'serving_size': servingSize,
      'serving_unit': servingUnit,
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fat': fat,
    };
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

  DailyNutrition copyWith({
    double? calories,
    double? protein,
    double? carbohydrates,
    double? fat,
    int? calorieTarget,
    double? proteinTarget,
  }) {
    return DailyNutrition(
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbohydrates: carbohydrates ?? this.carbohydrates,
      fat: fat ?? this.fat,
      calorieTarget: calorieTarget ?? this.calorieTarget,
      proteinTarget: proteinTarget ?? this.proteinTarget,
    );
  }

  factory DailyNutrition.fromJson(Map<String, dynamic> json) {
    return DailyNutrition(
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbohydrates: (json['carbohydrates'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      calorieTarget:
          json['calorie_target'] as int? ?? (json['calories_target'] as int?),
      proteinTarget: (json['protein_target'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fat': fat,
      'calorie_target': calorieTarget,
      'protein_target': proteinTarget,
    };
  }
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

  factory FoodLog.fromJson(Map<String, dynamic> json) {
    return FoodLog(
      id: json['id'] as String,
      foodName:
          json['food_name'] as String? ??
          (json['foods'] as Map?)?['name'] as String? ??
          'Food',
      mealSlot: json['meal_slot'] as String,
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      quantity: (json['quantity'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'food_name': foodName,
      'meal_slot': mealSlot,
      'calories': calories,
      'protein': protein,
      'quantity': quantity,
    };
  }
}

class NutritionRepository {
  NutritionRepository({
    required LocalStore store,
    VoidCallback? onChanged,
    SupabaseClient? client,
  }) : _store = store,
       _onChanged = onChanged,
       _client = client ?? SupabaseProvider.client;

  final LocalStore _store;
  final VoidCallback? _onChanged;
  final SupabaseClient _client;

  Future<List<Food>> cachedFoods() async {
    await _store.ensureReady();
    final List<dynamic>? rows = await _store.getList(SnapshotKeys.foodsCache);
    if (rows == null) {
      return <Food>[];
    }
    return rows
        .map(
          (dynamic row) => Food.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<Food>> search(String query, {required bool online}) async {
    final String needle = query.trim().toLowerCase();
    final List<Food> cached = await cachedFoods();
    List<Food> matches = cached
        .where((Food food) => food.name.toLowerCase().contains(needle))
        .take(30)
        .toList();
    if (online) {
      try {
        final List<dynamic> rows = await _client
            .from('foods')
            .select()
            .ilike('name', '%$query%')
            .eq('is_active', true)
            .limit(30);
        final List<Food> remote = rows
            .map(
              (dynamic row) =>
                  Food.fromJson(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
        final Map<String, Food> byId = <String, Food>{
          for (final Food food in cached) food.id: food,
          for (final Food food in remote) food.id: food,
        };
        await _store.setList(
          SnapshotKeys.foodsCache,
          byId.values.map((Food food) => food.toJson()).toList(),
        );
        matches = remote;
        _onChanged?.call();
      } catch (error) {
        if (matches.isEmpty) {
          throw ErrorMapper.map(error);
        }
      }
    }
    return matches;
  }

  Future<void> logFood({
    required Food food,
    required String mealSlot,
    required double quantity,
  }) async {
    final Food scaled = food.scaled(quantity);
    final String id = const Uuid().v4();
    final FoodLog log = FoodLog(
      id: id,
      foodName: food.name,
      mealSlot: mealSlot,
      calories: scaled.calories,
      protein: scaled.protein,
      quantity: quantity,
    );
    final List<FoodLog> logs = await todayLogs();
    logs.add(log);
    await _store.setList(
      SnapshotKeys.foodLogsToday,
      logs.map((FoodLog item) => item.toJson()).toList(),
    );
    final DailyNutrition today = await this.today();
    await _store.setJson(
      SnapshotKeys.todayNutrition,
      today
          .copyWith(
            calories: today.calories + scaled.calories,
            protein: today.protein + scaled.protein,
            carbohydrates: today.carbohydrates + scaled.carbohydrates,
            fat: today.fat + scaled.fat,
          )
          .toJson(),
    );
    await _store.enqueue(
      type: OutboxType.insertFoodLog,
      entity: SnapshotKeys.foodLogsToday,
      payload: <String, dynamic>{
        'id': id,
        'user_id': _client.auth.currentUser?.id,
        'food_id': food.id,
        'meal_slot': mealSlot,
        'quantity': quantity,
        'unit': food.servingUnit,
        'calories': scaled.calories,
        'protein': scaled.protein,
        'carbohydrates': scaled.carbohydrates,
        'fat': scaled.fat,
        'source': 'manual',
        'logged_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    _onChanged?.call();
  }

  Future<void> updateTargets({
    int? calories,
    double? proteinG,
    double? carbohydratesG,
    double? fatG,
  }) async {
    await _store.ensureReady();
    final Map<String, dynamic> current =
        await _store.getJson(SnapshotKeys.nutritionTargets) ??
        <String, dynamic>{};
    if (calories != null && (calories < 800 || calories > 6000)) {
      throw const AppException('That calorie target looks off.');
    }
    if (proteinG != null && (proteinG < 20 || proteinG > 400)) {
      throw const AppException('That protein target looks off.');
    }
    final int nextCalories = calories ?? current['calories'] as int? ?? 0;
    final double nextProtein =
        proteinG ?? (current['protein_g'] as num?)?.toDouble() ?? 0;
    final double nextCarbs =
        carbohydratesG ?? (current['carbohydrates_g'] as num?)?.toDouble() ?? 0;
    final double nextFat = fatG ?? (current['fat_g'] as num?)?.toDouble() ?? 0;
    final NutritionTargets targets = NutritionTargets(
      bmr: (current['bmr'] as num?)?.toDouble() ?? 0,
      tdee: (current['tdee'] as num?)?.toDouble() ?? 0,
      calories: nextCalories,
      proteinG: nextProtein,
      carbohydratesG: nextCarbs,
      fatG: nextFat,
    );
    await _store.setJson(SnapshotKeys.nutritionTargets, targets.toJson());
    final DailyNutrition today = await this.today();
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
        'user_id': _client.auth.currentUser?.id,
        'calories': targets.calories,
        'protein_g': targets.proteinG,
        'carbohydrates_g': targets.carbohydratesG,
        'fat_g': targets.fatG,
        'bmr': targets.bmr,
        'tdee': targets.tdee,
      },
    );
    _onChanged?.call();
  }

  Future<DailyNutrition> today() async {
    await _store.ensureReady();
    final Map<String, dynamic>? json = await _store.getJson(
      SnapshotKeys.todayNutrition,
    );
    if (json != null) {
      return DailyNutrition.fromJson(json);
    }
    final Map<String, dynamic>? targets = await _store.getJson(
      SnapshotKeys.nutritionTargets,
    );
    return DailyNutrition(
      calories: 0,
      protein: 0,
      carbohydrates: 0,
      fat: 0,
      calorieTarget: targets?['calories'] as int?,
      proteinTarget: (targets?['protein_g'] as num?)?.toDouble(),
    );
  }

  Future<List<FoodLog>> todayLogs() async {
    await _store.ensureReady();
    final List<dynamic>? rows = await _store.getList(
      SnapshotKeys.foodLogsToday,
    );
    if (rows == null) {
      return <FoodLog>[];
    }
    return rows
        .map(
          (dynamic row) =>
              FoodLog.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<void> deleteLog(String id) async {
    final List<FoodLog> logs = await todayLogs();
    FoodLog? removed;
    final List<FoodLog> next = <FoodLog>[];
    for (final FoodLog log in logs) {
      if (log.id == id) {
        removed = log;
      } else {
        next.add(log);
      }
    }
    await _store.setList(
      SnapshotKeys.foodLogsToday,
      next.map((FoodLog item) => item.toJson()).toList(),
    );
    if (removed != null) {
      final DailyNutrition today = await this.today();
      await _store.setJson(
        SnapshotKeys.todayNutrition,
        today
            .copyWith(
              calories: (today.calories - removed.calories).clamp(
                0,
                double.infinity,
              ),
              protein: (today.protein - removed.protein).clamp(
                0,
                double.infinity,
              ),
            )
            .toJson(),
      );
    }
    await _store.enqueue(
      type: OutboxType.deleteFoodLog,
      entity: SnapshotKeys.foodLogsToday,
      payload: <String, dynamic>{'id': id},
    );
    _onChanged?.call();
  }
}

typedef VoidCallback = void Function();
