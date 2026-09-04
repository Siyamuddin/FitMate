import 'package:fitmate/app.dart';
import 'package:fitmate/core/constants/enums.dart';
import 'package:fitmate/core/networking/edge_functions.dart';
import 'package:fitmate/core/sync/sync_engine.dart';
import 'package:fitmate/features/auth/presentation/auth_controller.dart';
import 'package:fitmate/features/health/presentation/health_connections_screen.dart';
import 'package:fitmate/features/nutrition/data/nutrition_repository.dart';
import 'package:fitmate/features/nutrition/presentation/nutrition_screen.dart';
import 'package:fitmate/features/onboarding/presentation/onboarding_controller.dart';
import 'package:fitmate/features/progress/presentation/progress_screen.dart';
import 'package:fitmate/features/workout/domain/workout_models.dart';
import 'package:fitmate/features/workout/presentation/workout_providers.dart';
import 'package:fitmate/services/analytics/analytics_service.dart';
import 'package:fitmate/services/health/health_service.dart';
import 'package:fitmate/services/notifications/notification_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'fakes.dart';
import 'fixtures.dart';

bool _fallbacksRegistered = false;

void registerTestFallbacks() {
  if (_fallbacksRegistered) {
    return;
  }
  _fallbacksRegistered = true;
  registerFallbackValue(<String, dynamic>{});
  registerFallbackValue(chicken);
  registerFallbackValue(ActivityLevel.moderatelyActive);
  registerFallbackValue(TrainingExperience.beginner);
  registerFallbackValue(TrainingEnvironment.gym);
  registerFallbackValue(() async {});
}

class AppHarness {
  AppHarness({
    required this.auth,
    this.profile,
    this.details,
    this.plan,
    this.nutrition = testNutrition,
    this.logs = const <FoodLog>[],
    this.progress = testProgress,
    this.health = testHealth,
    EdgeFunctionInvoker? edgeFunctions,
    FakeHealthRepository? healthRepository,
  }) : store = FakeLocalStore(),
       workouts = MockWorkoutRepository(),
       profiles = MockProfileRepository(),
       nutritionRepo = MockNutritionRepository(),
       edgeFunctions = edgeFunctions ?? _silentEdge,
       healthRepository = healthRepository ?? FakeHealthRepository() {
    registerTestFallbacks();
    when(() => workouts.cachedPlan()).thenAnswer((_) async => plan);
    when(() => workouts.cachedCatalog()).thenAnswer((_) async => testCatalog);
    when(
      () => workouts.cachedHistory(),
    ).thenAnswer((_) async => <WorkoutSessionSummary>[]);
    when(
      () => workouts.addExercise(
        dayId: any(named: 'dayId'),
        exerciseId: any(named: 'exerciseId'),
        sets: any(named: 'sets'),
        reps: any(named: 'reps'),
        restSeconds: any(named: 'restSeconds'),
      ),
    ).thenAnswer((_) async => 'we-new');
    when(() => workouts.deleteExercise(any())).thenAnswer((_) async {});
    when(
      () => nutritionRepo.cachedFoods(),
    ).thenAnswer((_) async => <Food>[chicken]);
    when(
      () => nutritionRepo.logFood(
        food: any(named: 'food'),
        mealSlot: any(named: 'mealSlot'),
        quantity: any(named: 'quantity'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => nutritionRepo.updateTargets(
        calories: any(named: 'calories'),
        proteinG: any(named: 'proteinG'),
        carbohydratesG: any(named: 'carbohydratesG'),
        fatG: any(named: 'fatG'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => profiles.updateProfileFields(
        age: any(named: 'age'),
        heightCm: any(named: 'heightCm'),
        activityLevel: any(named: 'activityLevel'),
        trainingExperience: any(named: 'trainingExperience'),
        trainingEnvironment: any(named: 'trainingEnvironment'),
        recalculateNutrition: any(named: 'recalculateNutrition'),
      ),
    ).thenAnswer((_) async {});
  }

  factory AppHarness.signedOut() {
    return AppHarness(auth: FakeAuthRepository());
  }

  factory AppHarness.needsOnboarding() {
    return AppHarness(
      auth: FakeAuthRepository(user: testUser),
      profile: incompleteProfile,
    );
  }

  factory AppHarness.onboarded({EdgeFunctionInvoker? edgeFunctions}) {
    return AppHarness(
      auth: FakeAuthRepository(user: testUser),
      profile: onboardedProfile,
      details: testDetails,
      plan: testPlan,
      logs: const <FoodLog>[testFoodLog],
      edgeFunctions: edgeFunctions,
    );
  }

  final FakeAuthRepository auth;
  final FakeLocalStore store;
  final MockWorkoutRepository workouts;
  final MockProfileRepository profiles;
  final MockNutritionRepository nutritionRepo;
  final EdgeFunctionInvoker edgeFunctions;
  final FakeHealthRepository healthRepository;
  final dynamic profile;
  final dynamic details;
  final dynamic plan;
  final DailyNutrition nutrition;
  final List<FoodLog> logs;
  final dynamic progress;
  final HealthData health;

  static Future<Map<String, dynamic>> _silentEdge(
    String name, {
    Map<String, dynamic>? body,
  }) async {
    return <String, dynamic>{
      'intent': 'answer',
      'message': 'Keep showing up.',
      'actions': <dynamic>[],
    };
  }

  List<Override> get overrides {
    return <Override>[
      authRepositoryProvider.overrideWithValue(auth),
      localStoreProvider.overrideWithValue(store),
      syncEngineProvider.overrideWithValue(FakeSyncEngine(store: store)),
      currentProfileProvider.overrideWith((Ref ref) async => profile),
      personalDetailsProvider.overrideWith((Ref ref) async => details),
      activePlanProvider.overrideWith((Ref ref) async => plan),
      workoutHistoryProvider.overrideWith(
        (Ref ref) async => <WorkoutSessionSummary>[],
      ),
      exerciseCatalogProvider.overrideWith((Ref ref) async => testCatalog),
      todayNutritionProvider.overrideWith((Ref ref) async => nutrition),
      todayFoodLogsProvider.overrideWith((Ref ref) async => logs),
      progressSnapshotProvider.overrideWith((Ref ref) async => progress),
      todayHealthProvider.overrideWith((Ref ref) async => health),
      workoutRepositoryProvider.overrideWithValue(workouts),
      profileRepositoryProvider.overrideWithValue(profiles),
      nutritionRepositoryProvider.overrideWithValue(nutritionRepo),
      analyticsServiceProvider.overrideWithValue(const SilentAnalytics()),
      healthServiceProvider.overrideWithValue(StubHealthService()),
      healthRepositoryProvider.overrideWithValue(healthRepository),
      edgeFunctionsProvider.overrideWith((Ref ref) => edgeFunctions),
      notificationServiceProvider.overrideWithValue(QuietNotificationService()),
    ];
  }
}

void mockPlatformChannels(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async => null,
  );
}

Future<void> pumpScreen(
  WidgetTester tester, {
  required Widget child,
  AppHarness? harness,
}) async {
  mockPlatformChannels(tester);
  final AppHarness resolved = harness ?? AppHarness.onboarded();
  await tester.pumpWidget(
    ProviderScope(
      overrides: resolved.overrides,
      child: CupertinoApp(home: child),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<ProviderContainer> pumpFitMateApp(
  WidgetTester tester,
  AppHarness harness, {
  required void Function(VoidCallback) addTearDown,
}) async {
  mockPlatformChannels(tester);
  final ProviderContainer container = ProviderContainer(
    overrides: harness.overrides,
  );
  addTearDown(container.dispose);
  addTearDown(harness.auth.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const FitMateApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return container;
}
