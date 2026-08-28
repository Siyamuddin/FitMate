import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/networking/supabase_provider.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/utils/fitness_calc.dart';
import 'package:fitmate/core/widgets/app_scaffold.dart';
import 'package:fitmate/core/widgets/cards.dart';
import 'package:fitmate/core/widgets/chart_card.dart';
import 'package:fitmate/core/widgets/states.dart';

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.weights,
    this.currentWeight,
    this.targetWeight,
    this.workoutsThisWeek = 0,
    this.workoutsPlanned = 0,
  });

  final List<double> weights;
  final double? currentWeight;
  final double? targetWeight;
  final int workoutsThisWeek;
  final int workoutsPlanned;
}

final progressSnapshotProvider = FutureProvider<ProgressSnapshot>((Ref ref) async {
  final List<dynamic> metrics = await SupabaseProvider.client
      .from('body_metrics')
      .select('weight_kg, recorded_at')
      .order('recorded_at')
      .limit(30);
  final List<double> weights = metrics
      .map((dynamic row) => ((row as Map)['weight_kg'] as num).toDouble())
      .toList();
  final dynamic goal = await SupabaseProvider.client
      .from('fitness_goals')
      .select('target_weight_kg')
      .eq('is_active', true)
      .maybeSingle();
  final DateTime weekAgo = DateTime.now().toUtc().subtract(const Duration(days: 7));
  final List<dynamic> sessions = await SupabaseProvider.client
      .from('workout_sessions')
      .select('id')
      .eq('status', 'completed')
      .gte('started_at', weekAgo.toIso8601String());
  return ProgressSnapshot(
    weights: weights,
    currentWeight: weights.isEmpty ? null : weights.last,
    targetWeight: goal == null ? null : ((goal as Map)['target_weight_kg'] as num?)?.toDouble(),
    workoutsThisWeek: sessions.length,
    workoutsPlanned: 4,
  );
});

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProgressSnapshot> snapshot = ref.watch(progressSnapshotProvider);
    return AppScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Progress')),
      child: snapshot.when(
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
                emptyMessage: 'A chart appears after two weigh-ins.',
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
