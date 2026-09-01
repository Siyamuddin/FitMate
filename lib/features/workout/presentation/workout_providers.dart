import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/sync/sync_engine.dart';
import 'package:fitmate/features/workout/data/workout_repository.dart';
import 'package:fitmate/features/workout/domain/workout_models.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((Ref ref) {
  return WorkoutRepository(
    store: ref.read(localStoreProvider),
    onChanged: () => notifyLocalChange(ref),
  );
});

final activePlanProvider = FutureProvider<WorkoutPlan?>((Ref ref) async {
  ref.watch(localEpochProvider);
  await ref.read(localStoreProvider).ensureReady();
  return ref.read(workoutRepositoryProvider).cachedPlan();
});

final workoutHistoryProvider = FutureProvider<List<WorkoutSessionSummary>>((Ref ref) async {
  ref.watch(localEpochProvider);
  await ref.read(localStoreProvider).ensureReady();
  return ref.read(workoutRepositoryProvider).cachedHistory();
});

final exerciseCatalogProvider = FutureProvider<List<Exercise>>((Ref ref) async {
  ref.watch(localEpochProvider);
  await ref.read(localStoreProvider).ensureReady();
  return ref.read(workoutRepositoryProvider).cachedCatalog();
});
