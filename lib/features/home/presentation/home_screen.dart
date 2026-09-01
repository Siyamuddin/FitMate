import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/utils/formatters.dart';
import 'package:fitmate/core/widgets/app_scaffold.dart';
import 'package:fitmate/core/widgets/buttons.dart';
import 'package:fitmate/core/widgets/cards.dart';
import 'package:fitmate/core/widgets/insight_card.dart';
import 'package:fitmate/core/widgets/states.dart';
import 'package:fitmate/features/nutrition/presentation/nutrition_screen.dart';
import 'package:fitmate/features/onboarding/presentation/onboarding_controller.dart';
import 'package:fitmate/features/progress/presentation/progress_screen.dart';
import 'package:fitmate/features/workout/domain/workout_models.dart';
import 'package:fitmate/features/workout/presentation/workout_providers.dart';
import 'package:fitmate/services/health/health_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final plan = ref.watch(activePlanProvider);
    final nutrition = ref.watch(todayNutritionProvider);
    final progress = ref.watch(progressSnapshotProvider);
    final health = ref.watch(todayHealthProvider);
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);

    return profile.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const AppScaffold(child: LoadingState()),
      error: (Object error, _) => AppScaffold(child: ErrorState(message: error.toString())),
      data: (profileData) {
        final WorkoutDay? today = plan.value?.today();
        final String name = profileData?.displayName ?? 'there';
        return AppScaffold(
          child: ListView(
            children: <Widget>[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${Formatters.greeting(DateTime.now())}, $name',
                      style: AppTypography.display(AppColors.ink(brightness)),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => context.push('/profile'),
                    child: const Icon(CupertinoIcons.person_crop_circle),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: MetricCard(
                      label: 'Weight',
                      value: progress.value?.currentWeight == null
                          ? '—'
                          : Formatters.kg(progress.value!.currentWeight!),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: MetricCard(
                      label: 'Goal',
                      value: progress.value?.targetWeight == null
                          ? '—'
                          : Formatters.kg(progress.value!.targetWeight!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Today\'s workout', style: AppTypography.headline(AppColors.ink(brightness))),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                semanticLabel: today?.name ?? 'Rest day',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(today?.name ?? 'Rest or mobility', style: AppTypography.title(AppColors.ink(brightness))),
                    if (today != null)
                      Text(
                        '${today.exercises.length} exercises · ${today.estimatedDurationMinutes ?? 45} min',
                        style: AppTypography.meta(AppColors.muted(brightness)),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      label: today == null ? 'Browse workouts' : 'Start Workout',
                      onPressed: () {
                        if (today == null) {
                          context.go('/workout');
                        } else {
                          context.push('/active-workout/${today.id}');
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ProgressCard(
                title: 'Nutrition',
                current: nutrition.value?.calories ?? 0,
                target: (nutrition.value?.calorieTarget ?? 2100).toDouble(),
                unit: 'kcal',
              ),
              const SizedBox(height: AppSpacing.sm),
              ProgressCard(
                title: 'Protein',
                current: nutrition.value?.protein ?? 0,
                target: nutrition.value?.proteinTarget ?? 150,
                unit: 'g',
              ),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(label: 'Log Food', onPressed: () => context.go('/nutrition')),
              if (health.value?.steps != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                MetricCard(label: 'Steps', value: '${health.value!.steps}'),
              ],
              const SizedBox(height: AppSpacing.lg),
              InsightCard(
                title: 'AI Coach',
                body: progress.value == null
                    ? 'Complete a workout this week to unlock a coaching insight.'
                    : 'You have completed ${progress.value!.workoutsThisWeek} workouts this week.',
              ),
              CupertinoButton(
                onPressed: () => context.go('/coach'),
                child: const Text('Talk to Coach'),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        );
      },
    );
  }
}
