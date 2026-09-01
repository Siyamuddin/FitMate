import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/haptics/app_haptics.dart';
import 'package:fitmate/core/local/snapshot_keys.dart';
import 'package:fitmate/core/sync/sync_engine.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/utils/fitness_calc.dart';
import 'package:fitmate/core/widgets/app_scaffold.dart';
import 'package:fitmate/core/widgets/cards.dart';
import 'package:fitmate/core/widgets/chart_card.dart';
import 'package:fitmate/core/widgets/picker_sheet.dart';
import 'package:fitmate/core/widgets/states.dart';
import 'package:fitmate/features/nutrition/presentation/nutrition_screen.dart';
import 'package:fitmate/features/onboarding/presentation/onboarding_controller.dart';
import 'package:fitmate/features/progress/domain/progress_snapshot.dart';
import 'package:fitmate/services/analytics/analytics_service.dart';

export 'package:fitmate/features/progress/domain/progress_snapshot.dart';

final progressSnapshotProvider = FutureProvider<ProgressSnapshot>((Ref ref) async {
  ref.watch(localEpochProvider);
  await ref.read(localStoreProvider).ensureReady();
  final Map<String, dynamic>? json = await ref.read(localStoreProvider).getJson(SnapshotKeys.progress);
  if (json != null) {
    return ProgressSnapshot.fromJson(json);
  }
  return const ProgressSnapshot(weights: <double>[]);
});

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProgressSnapshot> snapshot = ref.watch(progressSnapshotProvider);
    return AppScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Progress'),
        trailing: Semantics(
          button: true,
          label: 'Log weight',
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => logWeightFromPicker(context, ref, snapshot.value?.currentWeight),
            child: const Text('Log'),
          ),
        ),
      ),
      child: snapshot.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const LoadingState(),
        error: (Object error, _) => ErrorState(message: error.toString(), onRetry: () => ref.refresh(progressSnapshotProvider)),
        data: (ProgressSnapshot data) {
          final double remaining = (data.currentWeight ?? 0) - (data.targetWeight ?? data.currentWeight ?? 0);
          return ListView(
            children: <Widget>[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(child: MetricCard(label: 'Now', value: data.currentWeight == null ? '—' : '${data.currentWeight!.toStringAsFixed(1)} kg')),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: MetricCard(label: 'Target', value: data.targetWeight == null ? '—' : '${data.targetWeight!.toStringAsFixed(1)} kg')),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              MetricCard(
                label: 'Remaining',
                value: data.currentWeight == null ? '—' : '${remaining.abs().toStringAsFixed(1)} kg',
                detail: remaining > 0 ? 'to lose' : 'to gain or maintain',
              ),
              const SizedBox(height: AppSpacing.lg),
              ChartCard(
                title: 'Weight',
                values: data.weights,
                emptyTitle: 'Log weight',
                emptyMessage: 'A chart appears after two weigh-ins. Use Log in the top right.',
              ),
              const SizedBox(height: AppSpacing.lg),
              ProgressCard(
                title: 'Workouts this week',
                current: data.workoutsThisWeek.toDouble(),
                target: data.workoutsPlanned.toDouble(),
                unit: 'sessions',
              ),
              const SizedBox(height: AppSpacing.sm),
              MetricCard(
                label: 'Weekly change',
                value: '${FitnessCalculator.weeklyWeightChangeKg(data.weights).toStringAsFixed(1)} kg',
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }
}

Future<void> logWeightFromPicker(BuildContext context, WidgetRef ref, double? currentWeight) async {
  final int? kg = await showIntPicker(
    context: context,
    title: 'Weight',
    min: 40,
    max: 180,
    current: (currentWeight ?? 74).round(),
    suffix: ' kg',
  );
  if (kg == null) {
    return;
  }
  try {
    await ref.read(profileRepositoryProvider).logWeight(kg.toDouble());
    ref.read(analyticsServiceProvider).track('weight_logged');
    ref.invalidate(currentProfileProvider);
    ref.invalidate(personalDetailsProvider);
    ref.invalidate(progressSnapshotProvider);
    ref.invalidate(todayNutritionProvider);
    AppHaptics.confirmation();
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
            CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        );
      },
    );
  }
}
