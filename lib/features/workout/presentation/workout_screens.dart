import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/utils/formatters.dart';
import 'package:fitmate/core/widgets/app_scaffold.dart';
import 'package:fitmate/core/widgets/buttons.dart';
import 'package:fitmate/core/widgets/states.dart';
import 'package:fitmate/core/widgets/workout_card.dart';
import 'package:fitmate/features/workout/domain/workout_models.dart';
import 'package:fitmate/features/workout/presentation/workout_providers.dart';

class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WorkoutPlan?> plan = ref.watch(activePlanProvider);
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return AppScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Workout')),
      child: plan.when(
        loading: () => const LoadingState(),
        error: (Object error, _) => ErrorState(message: error.toString(), onRetry: () => ref.refresh(activePlanProvider)),
        data: (WorkoutPlan? value) {
          if (value == null) {
            return EmptyState(
              title: 'No plan yet',
              message: 'Ask the coach to generate a workout plan.',
              actionLabel: 'Talk to Coach',
              onAction: () => context.go('/coach'),
            );
          }
          return ListView(
            children: <Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(value.name, style: AppTypography.title(AppColors.ink(brightness))),
              const SizedBox(height: AppSpacing.md),
              ...value.days.map((WorkoutDay day) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: WorkoutCard(
                    title: '${Formatters.weekdayName(day.weekday)} · ${day.name}',
                    subtitle: '${day.exercises.length} exercises · ${day.estimatedDurationMinutes ?? 45} min',
                    onTap: () => context.push('/workout/${day.id}'),
                  ),
                );
              }),
              SecondaryButton(label: 'History', onPressed: () => context.push('/workout-history')),
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }
}

class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.dayId});

  final String dayId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WorkoutPlan?> plan = ref.watch(activePlanProvider);
    return plan.when(
      loading: () => const AppScaffold(child: LoadingState()),
      error: (Object error, _) => AppScaffold(child: ErrorState(message: error.toString())),
      data: (WorkoutPlan? value) {
        final WorkoutDay? day = value?.days.cast<WorkoutDay?>().firstWhere(
          (WorkoutDay? item) => item?.id == dayId,
          orElse: () => null,
        );
        if (value == null || day == null) {
          return const AppScaffold(child: EmptyState(title: 'Workout missing', message: 'This day is no longer on your plan.'));
        }
        return AppScaffold(
          navigationBar: CupertinoNavigationBar(middle: Text(day.name)),
          child: ListView(
            children: <Widget>[
              const SizedBox(height: AppSpacing.md),
              ...day.exercises.map((WorkoutExercise exercise) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ExerciseCard(
                    name: exercise.exercise.name,
                    detail: '${exercise.targetSets} × ${exercise.targetRepsMin ?? 8}–${exercise.targetRepsMax ?? 12}',
                    onTap: () => context.push('/exercise/${exercise.id}'),
                  ),
                );
              }),
              PrimaryButton(
                label: 'Start Workout',
                large: true,
                onPressed: () => context.push('/active-workout/${day.id}'),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        );
      },
    );
  }
}

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WorkoutPlan?> plan = ref.watch(activePlanProvider);
    final WorkoutExercise? exercise = plan.maybeWhen(
      data: (WorkoutPlan? value) {
        if (value == null) {
          return null;
        }
        for (final WorkoutDay day in value.days) {
          for (final WorkoutExercise item in day.exercises) {
            if (item.id == exerciseId) {
              return item;
            }
          }
        }
        return null;
      },
      orElse: () => null,
    );
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return AppScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(exercise?.exercise.name ?? 'Exercise')),
      child: ListView(
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(exercise?.exercise.instructions ?? 'Move with control and a full range of motion.', style: AppTypography.body(AppColors.ink(brightness))),
        ],
      ),
    );
  }
}

class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<WorkoutSessionSummary>> history = ref.watch(workoutHistoryProvider);
    return AppScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('History')),
      child: history.when(
        loading: () => const LoadingState(),
        error: (Object error, _) => ErrorState(message: error.toString()),
        data: (List<WorkoutSessionSummary> rows) {
          if (rows.isEmpty) {
            return const EmptyState(title: 'No workouts yet', message: 'Complete a session to see it here.');
          }
          return ListView(
            children: rows.map((WorkoutSessionSummary item) {
              final int minutes = ((item.durationSeconds ?? 0) / 60).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: WorkoutCard(
                  title: item.dayName ?? 'Workout',
                  subtitle: '${item.startedAt.toLocal().toString().split(' ').first} · $minutes min',
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
