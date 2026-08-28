import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitmate/core/haptics/app_haptics.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/widgets/app_scaffold.dart';
import 'package:fitmate/core/widgets/app_sheet.dart';
import 'package:fitmate/core/widgets/buttons.dart';
import 'package:fitmate/core/widgets/set_row.dart';
import 'package:fitmate/core/widgets/states.dart';
import 'package:fitmate/features/workout/domain/workout_models.dart';
import 'package:fitmate/features/workout/presentation/workout_providers.dart';
import 'package:fitmate/services/analytics/analytics_service.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key, required this.dayId});

  final String dayId;

  @override
  ConsumerState<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  String? _sessionId;
  int _exerciseIndex = 0;
  final Map<String, List<SetLog>> _logs = <String, List<SetLog>>{};
  DateTime? _startedAt;
  int? _restSeconds;
  List<SetLog> _previous = <SetLog>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_start);
  }

  Future<void> _start() async {
    final WorkoutPlan? plan = await ref.read(activePlanProvider.future);
    final WorkoutDay? day = plan?.days.cast<WorkoutDay?>().firstWhere(
      (WorkoutDay? item) => item?.id == widget.dayId,
      orElse: () => null,
    );
    if (plan == null || day == null) {
      return;
    }
    final String sessionId = await ref.read(workoutRepositoryProvider).startSession(planId: plan.id, dayId: day.id);
    for (final WorkoutExercise exercise in day.exercises) {
      _logs[exercise.id] = List<SetLog>.generate(exercise.targetSets, (int index) {
        return SetLog.create(
          workoutExerciseId: exercise.id,
          setNumber: index + 1,
          weightKg: exercise.targetWeightKg,
          reps: exercise.targetRepsMax ?? exercise.targetRepsMin,
        );
      });
    }
    ref.read(analyticsServiceProvider).track('workout_started');
    final List<SetLog> previous = day.exercises.isEmpty
        ? <SetLog>[]
        : await ref.read(workoutRepositoryProvider).previousSetLogs(day.exercises.first.id);
    setState(() {
      _sessionId = sessionId;
      _startedAt = DateTime.now();
      _previous = previous;
    });
  }

  WorkoutDay? _day(WorkoutPlan? plan) {
    if (plan == null) {
      return null;
    }
    for (final WorkoutDay day in plan.days) {
      if (day.id == widget.dayId) {
        return day;
      }
    }
    return null;
  }

  Future<void> _completeSet(WorkoutExercise exercise, SetLog log) async {
    if (_sessionId == null) {
      return;
    }
    log.completed = true;
    log.skipped = false;
    await ref.read(workoutRepositoryProvider).upsertSetLog(_sessionId!, log);
    await AppHaptics.setCompleted();
    ref.read(analyticsServiceProvider).track('set_completed');
    setState(() => _restSeconds = exercise.restSeconds);
  }

  Future<void> _completeWorkout() async {
    if (_sessionId == null || _startedAt == null) {
      return;
    }
    final int seconds = DateTime.now().difference(_startedAt!).inSeconds;
    await ref.read(workoutRepositoryProvider).completeSession(_sessionId!, seconds);
    await AppHaptics.workoutCompleted();
    ref.read(analyticsServiceProvider).track('workout_completed');
    if (!mounted) {
      return;
    }
    context.go('/workout-complete');
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<WorkoutPlan?> plan = ref.watch(activePlanProvider);
    final WorkoutDay? day = _day(plan.value);
    if (day == null || _sessionId == null) {
      return const AppScaffold(child: LoadingState(message: 'Starting workout'));
    }
    final WorkoutExercise exercise = day.exercises[_exerciseIndex];
    final List<SetLog> sets = _logs[exercise.id] ?? <SetLog>[];
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _confirmDiscard(context);
        }
      },
      child: AppScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(day.name),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _confirmDiscard(context),
            child: const Text('Close'),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(exercise.exercise.name, style: AppTypography.title(AppColors.ink(brightness))),
            Text(
              'Target ${exercise.targetSets} × ${exercise.targetRepsMin ?? 8}–${exercise.targetRepsMax ?? 12}',
              style: AppTypography.meta(AppColors.muted(brightness)),
            ),
            if (_restSeconds != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text('Rest $_restSeconds s', style: AppTypography.headline(AppColors.accent(brightness))),
              ),
            if (_previous.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Last time: ${_previous.map((SetLog log) => '${log.weightKg?.round() ?? '—'}×${log.reps ?? '—'}').join('  ')}',
                style: AppTypography.meta(AppColors.muted(brightness)),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: ListView(
                children: sets.map((SetLog log) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: SetRow(
                      setNumber: log.setNumber,
                      summary: '${log.weightKg?.toStringAsFixed(0) ?? '—'} kg × ${log.reps ?? '—'}',
                      completed: log.completed,
                      onComplete: () => _completeSet(exercise, log),
                    ),
                  );
                }).toList(),
              ),
            ),
            Row(
              children: <Widget>[
                CupertinoButton(
                  onPressed: () => _showMore(exercise),
                  child: const Text('More'),
                ),
                if (_exerciseIndex > 0)
                  CupertinoButton(
                    onPressed: () => _changeExercise(_exerciseIndex - 1),
                    child: const Text('Previous'),
                  ),
                const Spacer(),
                if (_exerciseIndex < day.exercises.length - 1)
                  CupertinoButton(
                    onPressed: () => _changeExercise(_exerciseIndex + 1),
                    child: const Text('Next exercise'),
                  ),
              ],
            ),
            PrimaryButton(label: 'Complete Workout', large: true, onPressed: _completeWorkout),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Future<void> _changeExercise(int index) async {
    final WorkoutPlan? plan = await ref.read(activePlanProvider.future);
    final WorkoutDay? day = _day(plan);
    if (day == null) {
      return;
    }
    final List<SetLog> previous = await ref.read(workoutRepositoryProvider).previousSetLogs(day.exercises[index].id);
    setState(() {
      _exerciseIndex = index;
      _previous = previous;
    });
  }

  Future<void> _showMore(WorkoutExercise exercise) {
    return AppActionSheet.show<void>(
      context: context,
      title: exercise.exercise.name,
      actions: <CupertinoActionSheetAction>[
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            _skipCurrent(exercise);
          },
          child: const Text('Skip set'),
        ),
      ],
    );
  }

  Future<void> _skipCurrent(WorkoutExercise exercise) async {
    final List<SetLog> sets = _logs[exercise.id] ?? <SetLog>[];
    final SetLog open = sets.firstWhere((SetLog log) => !log.completed, orElse: () => sets.last);
    open.skipped = true;
    open.completed = false;
    if (_sessionId != null) {
      await ref.read(workoutRepositoryProvider).upsertSetLog(_sessionId!, open);
    }
    setState(() {});
  }

  Future<void> _confirmDiscard(BuildContext context) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('End workout?'),
          content: const Text('Your completed sets are saved. Unfinished work will stay incomplete.'),
          actions: <Widget>[
            CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Keep going')),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                context.go('/workout');
              },
              child: const Text('End'),
            ),
          ],
        );
      },
    );
  }
}

class WorkoutCompleteScreen extends StatelessWidget {
  const WorkoutCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return AppScaffold(
      child: Column(
        children: <Widget>[
          const Spacer(),
          Text('Workout complete', style: AppTypography.display(AppColors.ink(brightness))),
          const SizedBox(height: AppSpacing.sm),
          Text('Nice work. Log food next or rest.', style: AppTypography.body(AppColors.muted(brightness))),
          const Spacer(),
          PrimaryButton(label: 'Done', onPressed: () => context.go('/home')),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
