import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitmate/core/haptics/app_haptics.dart';
import 'package:fitmate/core/sync/sync_engine.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_radius.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/utils/formatters.dart';
import 'package:fitmate/core/widgets/app_scaffold.dart';
import 'package:fitmate/core/widgets/app_sheet.dart';
import 'package:fitmate/core/widgets/buttons.dart';
import 'package:fitmate/core/widgets/grouped_rows.dart';
import 'package:fitmate/core/widgets/picker_sheet.dart';
import 'package:fitmate/core/widgets/states.dart';
import 'package:fitmate/core/widgets/workout_card.dart';
import 'package:fitmate/features/workout/domain/workout_models.dart';
import 'package:fitmate/features/workout/presentation/plan_edit_sheets.dart';
import 'package:fitmate/features/workout/presentation/workout_providers.dart';

class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WorkoutPlan?> plan = ref.watch(activePlanProvider);
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return AppScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Workout'),
        trailing: plan.value == null
            ? null
            : Semantics(
                button: true,
                label: 'Add day',
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _addDay(context, ref, plan.value!),
                  child: const Icon(CupertinoIcons.add),
                ),
              ),
      ),
      child: plan.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const LoadingState(),
        error: (Object error, _) => ErrorState(message: error.toString(), onRetry: () => ref.read(syncEngineProvider).sync()),
        data: (WorkoutPlan? value) {
          if (value == null) {
            return EmptyState(
              title: 'No plan yet',
              message: 'Ask the coach to generate a plan. You can add and remove days after that.',
              actionLabel: 'Talk to Coach',
              onAction: () => context.go('/coach'),
            );
          }
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              CupertinoSliverRefreshControl(
                onRefresh: () => ref.read(syncEngineProvider).sync(),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
                sliver: SliverToBoxAdapter(
                  child: Text(value.name, style: AppTypography.title(AppColors.ink(brightness))),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    final WorkoutDay day = value.days[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Dismissible(
                        key: ValueKey<String>(day.id),
                        direction: DismissDirection.endToStart,
                        background: const _SwipeDeleteBackground(),
                        confirmDismiss: (_) => _confirmRemoveDay(context, ref, value, day),
                        onDismissed: (_) => ref.invalidate(activePlanProvider),
                        child: GroupedSection(
                          children: <Widget>[
                            GroupedNavRow(
                              title: '${Formatters.weekdayName(day.weekday)} · ${day.name}',
                              subtitle: '${day.exercises.length} exercises · ${day.estimatedDurationMinutes ?? 45} min',
                              onTap: () => context.push('/workout/${day.id}'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: value.days.length,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xl),
                  child: SecondaryButton(label: 'History', onPressed: () => context.push('/workout-history')),
                ),
              ),
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
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
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
          navigationBar: CupertinoNavigationBar(
            middle: Text(day.name),
            trailing: Semantics(
              button: true,
              label: 'Add exercise',
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _addExercise(context, ref, day),
                child: const Icon(CupertinoIcons.add),
              ),
            ),
          ),
          child: ListView(
            children: <Widget>[
              const SizedBox(height: AppSpacing.md),
              const GroupedSectionLabel(text: 'Day'),
              GroupedSection(
                children: <Widget>[
                  GroupedValueRow(
                    label: 'Name',
                    value: day.name,
                    onTap: () => _renameDay(context, ref, day),
                  ),
                  GroupedValueRow(
                    label: 'Day',
                    value: Formatters.weekdayName(day.weekday),
                    onTap: () => _changeWeekday(context, ref, value, day),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const GroupedSectionLabel(text: 'Exercises'),
              if (day.exercises.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Text(
                    'Tap + to add an exercise.',
                    style: AppTypography.body(AppColors.muted(MediaQuery.platformBrightnessOf(context))),
                  ),
                )
              else
                Column(
                  children: day.exercises.map((WorkoutExercise exercise) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Dismissible(
                        key: ValueKey<String>(exercise.id),
                        direction: DismissDirection.endToStart,
                        background: const _SwipeDeleteBackground(),
                        confirmDismiss: (_) => _confirmRemoveExercise(context, ref, day, exercise),
                        onDismissed: (_) => ref.invalidate(activePlanProvider),
                        child: GroupedSection(
                          children: <Widget>[
                            GroupedNavRow(
                              title: exercise.exercise.name,
                              subtitle: '${exercise.targetSets} × ${exercise.targetRepsMin ?? 8}–${exercise.targetRepsMax ?? 12}',
                              onTap: () => context.push('/exercise/${exercise.id}'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: AppSpacing.lg),
              if (day.exercises.isNotEmpty)
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
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
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
          Text(
            exercise?.exercise.instructions ?? 'Move with control and a full range of motion.',
            style: AppTypography.body(AppColors.ink(brightness)),
          ),
          if (exercise != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            const GroupedSectionLabel(text: 'Target'),
            GroupedSection(
              children: <Widget>[
                GroupedValueRow(
                  label: 'Sets',
                  value: '${exercise.targetSets}',
                  onTap: () => _editSets(context, ref, exercise),
                ),
                GroupedValueRow(
                  label: 'Reps',
                  value: '${exercise.targetRepsMin ?? 8}',
                  onTap: () => _editReps(context, ref, exercise),
                ),
                GroupedValueRow(
                  label: 'Rest',
                  value: '${exercise.restSeconds}s',
                  onTap: () => _editRest(context, ref, exercise),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            CupertinoButton(
              onPressed: () => _removeExerciseFromDetail(context, ref, exercise),
              child: Text('Remove Exercise', style: AppTypography.headline(AppColors.danger)),
            ),
          ],
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
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
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

class _SwipeDeleteBackground extends StatelessWidget {
  const _SwipeDeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: const Icon(CupertinoIcons.delete, color: CupertinoColors.white),
    );
  }
}

Future<void> _runPlanChange({
  required BuildContext context,
  required WidgetRef ref,
  required Future<void> Function() action,
}) async {
  try {
    await action();
    await AppHaptics.confirmation();
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    await showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Could not save'),
          content: Text('$error'),
          actions: <Widget>[
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

Future<void> _addDay(BuildContext context, WidgetRef ref, WorkoutPlan plan) async {
  final List<int> used = plan.days.map((WorkoutDay day) => day.weekday).toList();
  if (used.toSet().length >= 7) {
    await showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Week is full'),
          content: const Text('Every day already has a workout. Remove one first.'),
          actions: <Widget>[
            CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        );
      },
    );
    return;
  }
  final AddDayResult? result = await showAddDaySheet(context: context, usedWeekdays: used);
  if (result == null || !context.mounted) {
    return;
  }
  String? dayId;
  await _runPlanChange(
    context: context,
    ref: ref,
    action: () async {
      dayId = await ref.read(workoutRepositoryProvider).addDay(
        planId: plan.id,
        name: result.name,
        weekday: result.weekday,
      );
    },
  );
  if (dayId != null && context.mounted) {
    context.push('/workout/$dayId');
  }
}

Future<bool> _confirmRemoveDay(BuildContext context, WidgetRef ref, WorkoutPlan plan, WorkoutDay day) async {
  final bool confirmed = await showDestructiveConfirm(
    context: context,
    title: 'Remove ${Formatters.weekdayName(day.weekday)}?',
    message: '${day.name} will be removed from your plan.',
    action: 'Remove',
  );
  if (!confirmed) {
    return false;
  }
  try {
    await ref.read(workoutRepositoryProvider).deleteDay(
      dayId: day.id,
      planId: plan.id,
      remainingDays: plan.days.length,
    );
    await AppHaptics.confirmation();
    return true;
  } catch (error) {
    if (context.mounted) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text('Could not remove'),
            content: Text('$error'),
            actions: <Widget>[
              CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          );
        },
      );
    }
    return false;
  }
}

Future<void> _renameDay(BuildContext context, WidgetRef ref, WorkoutDay day) async {
  final String? next = await showTextSheet(
    context: context,
    title: 'Name',
    placeholder: 'Workout name',
    initial: day.name,
  );
  final String trimmed = next?.trim() ?? '';
  if (trimmed.isEmpty || trimmed == day.name || !context.mounted) {
    return;
  }
  await _runPlanChange(
    context: context,
    ref: ref,
    action: () => ref.read(workoutRepositoryProvider).updateDay(dayId: day.id, name: trimmed),
  );
}

Future<void> _changeWeekday(BuildContext context, WidgetRef ref, WorkoutPlan plan, WorkoutDay day) async {
  final List<int> used = plan.days.map((WorkoutDay item) => item.weekday).where((int weekday) => weekday != day.weekday).toList();
  const List<int> weekOrder = <int>[1, 2, 3, 4, 5, 6, 0];
  final List<int> available = weekOrder.where((int weekday) => !used.contains(weekday)).toList();
  final int? picked = await showWeekdayPicker(
    context: context,
    weekdays: available,
    current: day.weekday,
  );
  if (picked == null || picked == day.weekday || !context.mounted) {
    return;
  }
  await _runPlanChange(
    context: context,
    ref: ref,
    action: () => ref.read(workoutRepositoryProvider).updateDay(dayId: day.id, weekday: picked),
  );
}

Future<void> _addExercise(BuildContext context, WidgetRef ref, WorkoutDay day) async {
  final Set<String> already = day.exercises.map((WorkoutExercise item) => item.exercise.id).toSet();
  final Exercise? exercise = await showExercisePickerSheet(
    context: context,
    ref: ref,
    alreadyAddedIds: already,
  );
  if (exercise == null || !context.mounted) {
    return;
  }
  if (day.exercises.any((WorkoutExercise item) => item.exercise.id == exercise.id)) {
    return;
  }
  await _runPlanChange(
    context: context,
    ref: ref,
    action: () => ref.read(workoutRepositoryProvider).addExercise(dayId: day.id, exerciseId: exercise.id),
  );
}

Future<bool> _confirmRemoveExercise(
  BuildContext context,
  WidgetRef ref,
  WorkoutDay day,
  WorkoutExercise exercise,
) async {
  final bool confirmed = await showDestructiveConfirm(
    context: context,
    title: 'Remove ${exercise.exercise.name}?',
    message: 'It will be removed from ${day.name}.',
    action: 'Remove',
  );
  if (!confirmed) {
    return false;
  }
  try {
    await ref.read(workoutRepositoryProvider).deleteExercise(exercise.id);
    await AppHaptics.confirmation();
    return true;
  } catch (error) {
    if (context.mounted) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text('Could not remove'),
            content: Text('$error'),
            actions: <Widget>[
              CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          );
        },
      );
    }
    return false;
  }
}

Future<void> _removeExerciseFromDetail(BuildContext context, WidgetRef ref, WorkoutExercise exercise) async {
  final bool confirmed = await showDestructiveConfirm(
    context: context,
    title: 'Remove ${exercise.exercise.name}?',
    action: 'Remove',
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  await _runPlanChange(
    context: context,
    ref: ref,
    action: () => ref.read(workoutRepositoryProvider).deleteExercise(exercise.id),
  );
  if (context.mounted) {
    context.pop();
  }
}

Future<void> _editSets(BuildContext context, WidgetRef ref, WorkoutExercise exercise) async {
  final int? sets = await showIntPicker(
    context: context,
    title: 'Sets',
    min: 1,
    max: 8,
    current: exercise.targetSets,
  );
  if (sets == null || sets == exercise.targetSets || !context.mounted) {
    return;
  }
  await _runPlanChange(
    context: context,
    ref: ref,
    action: () => ref.read(workoutRepositoryProvider).updateExercise(workoutExerciseId: exercise.id, sets: sets),
  );
}

Future<void> _editReps(BuildContext context, WidgetRef ref, WorkoutExercise exercise) async {
  final int? reps = await showIntPicker(
    context: context,
    title: 'Reps',
    min: 1,
    max: 30,
    current: exercise.targetRepsMin ?? 10,
  );
  if (reps == null || reps == exercise.targetRepsMin || !context.mounted) {
    return;
  }
  await _runPlanChange(
    context: context,
    ref: ref,
    action: () => ref.read(workoutRepositoryProvider).updateExercise(workoutExerciseId: exercise.id, reps: reps),
  );
}

Future<void> _editRest(BuildContext context, WidgetRef ref, WorkoutExercise exercise) async {
  final int? rest = await showIntPicker(
    context: context,
    title: 'Rest',
    min: 0,
    max: 300,
    current: exercise.restSeconds.clamp(0, 300).toInt(),
    suffix: 's',
  );
  if (rest == null || rest == exercise.restSeconds || !context.mounted) {
    return;
  }
  await _runPlanChange(
    context: context,
    ref: ref,
    action: () => ref.read(workoutRepositoryProvider).updateExercise(workoutExerciseId: exercise.id, restSeconds: rest),
  );
}
