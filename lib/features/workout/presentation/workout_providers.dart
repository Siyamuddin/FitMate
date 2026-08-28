import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/features/workout/data/workout_repository.dart';
import 'package:fitmate/features/workout/domain/workout_models.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((Ref ref) {
  return WorkoutRepository();
});

final activePlanProvider = FutureProvider<WorkoutPlan?>((Ref ref) {
  return ref.watch(workoutRepositoryProvider).fetchActivePlan();
});

final workoutHistoryProvider = FutureProvider<List<WorkoutSessionSummary>>((Ref ref) {
  return ref.watch(workoutRepositoryProvider).history();
});
