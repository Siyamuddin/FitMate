import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/widgets/app_scaffold.dart';
import 'package:fitmate/core/widgets/app_text_field.dart';
import 'package:fitmate/core/widgets/buttons.dart';
import 'package:fitmate/core/widgets/cards.dart';
import 'package:fitmate/core/widgets/food_row.dart';
import 'package:fitmate/core/widgets/states.dart';
import 'package:fitmate/core/sync/sync_engine.dart';
import 'package:fitmate/features/nutrition/data/nutrition_repository.dart';
import 'package:fitmate/services/analytics/analytics_service.dart';

final nutritionRepositoryProvider = Provider<NutritionRepository>((Ref ref) {
  return NutritionRepository(
    store: ref.read(localStoreProvider),
    onChanged: () => notifyLocalChange(ref),
  );
});

final todayNutritionProvider = FutureProvider<DailyNutrition>((Ref ref) async {
  ref.watch(localEpochProvider);
  await ref.read(localStoreProvider).ensureReady();
  return ref.read(nutritionRepositoryProvider).today();
});

final todayFoodLogsProvider = FutureProvider<List<FoodLog>>((Ref ref) async {
  ref.watch(localEpochProvider);
  await ref.read(localStoreProvider).ensureReady();
  return ref.read(nutritionRepositoryProvider).todayLogs();
});

class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DailyNutrition> today = ref.watch(todayNutritionProvider);
    final AsyncValue<List<FoodLog>> logs = ref.watch(todayFoodLogsProvider);
    return AppScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Nutrition')),
      child: today.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const LoadingState(),
        error: (Object error, _) => ErrorState(message: error.toString(), onRetry: () => ref.refresh(todayNutritionProvider)),
        data: (DailyNutrition data) {
          return ListView(
            children: <Widget>[
              const SizedBox(height: AppSpacing.md),
              ProgressCard(
                title: 'Calories',
                current: data.calories,
                target: (data.calorieTarget ?? 2100).toDouble(),
                unit: 'kcal',
              ),
              const SizedBox(height: AppSpacing.sm),
              ProgressCard(
                title: 'Protein',
                current: data.protein,
                target: data.proteinTarget ?? 150,
                unit: 'g',
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(child: MetricCard(label: 'Carbs', value: '${data.carbohydrates.round()}g')),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: MetricCard(label: 'Fat', value: '${data.fat.round()}g')),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Log food',
                onPressed: () => _openSearch(context, ref),
              ),
              const SizedBox(height: AppSpacing.lg),
              logs.when(
                loading: () => const SizedBox.shrink(),
                error: (Object error, _) => const SizedBox.shrink(),
                data: (List<FoodLog> items) {
                  if (items.isEmpty) {
                    return const EmptyState(title: 'Nothing logged', message: 'Search a food to add breakfast, lunch, dinner, or a snack.');
                  }
                    return Column(
                    children: items.map((FoodLog item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: FoodRow(
                          name: item.foodName,
                          detail: '${item.mealSlot} · ${item.quantity.round()} · ${item.calories.round()} kcal',
                          onRemove: () async {
                            await ref.read(nutritionRepositoryProvider).deleteLog(item.id);
                            ref.invalidate(todayNutritionProvider);
                            ref.invalidate(todayFoodLogsProvider);
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openSearch(BuildContext context, WidgetRef ref) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => const FoodSearchSheet(),
    );
  }
}

class FoodSearchSheet extends ConsumerStatefulWidget {
  const FoodSearchSheet({super.key});

  @override
  ConsumerState<FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends ConsumerState<FoodSearchSheet> {
  final TextEditingController _query = TextEditingController();
  List<Food> _results = <Food>[];
  Food? _selected;
  double _quantity = 100;
  String _slot = 'lunch';
  String? _searchError;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String value) async {
    if (value.trim().length < 2) {
      return;
    }
    try {
      final List<Food> results = await ref.read(nutritionRepositoryProvider).search(
        value.trim(),
        online: ref.read(syncStatusProvider).online,
      );
      setState(() {
        _results = results;
        _searchError = results.isEmpty && !ref.read(syncStatusProvider).online
            ? 'Connect to search foods'
            : null;
      });
    } catch (error) {
      setState(() => _searchError = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      padding: const EdgeInsets.all(AppSpacing.page),
      decoration: BoxDecoration(
        color: AppColors.background(brightness),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Text('Log food', style: AppTypography.title(AppColors.ink(brightness))),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _query, placeholder: 'Search foods', onSubmitted: _search),
            if (_searchError != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(_searchError!, style: AppTypography.meta(AppColors.muted(brightness))),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView(
                children: _results.map((Food food) {
                  return CupertinoButton(
                    onPressed: () => setState(() {
                      _selected = food;
                      _quantity = food.servingSize;
                    }),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${food.name} · ${food.calories.round()} kcal / ${food.servingSize.round()}${food.servingUnit}',
                        style: AppTypography.body(AppColors.ink(brightness)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (_selected != null) ...<Widget>[
              Text(_selected!.name, style: AppTypography.headline(AppColors.ink(brightness))),
              Text(
                '${_selected!.scaled(_quantity).calories.round()} kcal · ${_selected!.scaled(_quantity).protein.round()}g protein',
                style: AppTypography.meta(AppColors.muted(brightness)),
              ),
              CupertinoSlider(
                value: _quantity.clamp(10, 400),
                min: 10,
                max: 400,
                onChanged: (double value) => setState(() => _quantity = value),
              ),
              CupertinoSlidingSegmentedControl<String>(
                groupValue: _slot,
                children: const <String, Widget>{
                  'breakfast': Text('Breakfast'),
                  'lunch': Text('Lunch'),
                  'dinner': Text('Dinner'),
                  'snack': Text('Snack'),
                },
                onValueChanged: (String? value) {
                  if (value != null) {
                    setState(() => _slot = value);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Add to $_slot',
                onPressed: () async {
                  await ref.read(nutritionRepositoryProvider).logFood(
                    food: _selected!,
                    mealSlot: _slot,
                    quantity: _quantity,
                  );
                  ref.read(analyticsServiceProvider).track('food_logged');
                  ref.invalidate(todayNutritionProvider);
                  ref.invalidate(todayFoodLogsProvider);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
