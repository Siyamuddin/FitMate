import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitmate/core/routing/main_shell.dart';
import 'package:fitmate/features/auth/domain/auth_repository.dart';
import 'package:fitmate/features/auth/presentation/auth_controller.dart';
import 'package:fitmate/features/auth/presentation/forgot_password_screen.dart';
import 'package:fitmate/features/auth/presentation/sign_in_screen.dart';
import 'package:fitmate/features/auth/presentation/sign_up_screen.dart';
import 'package:fitmate/features/auth/presentation/welcome_screen.dart';
import 'package:fitmate/features/coach/presentation/coach_screen.dart';
import 'package:fitmate/features/home/presentation/home_screen.dart';
import 'package:fitmate/features/nutrition/presentation/nutrition_screen.dart';
import 'package:fitmate/features/onboarding/presentation/onboarding_controller.dart';
import 'package:fitmate/features/onboarding/presentation/onboarding_screen.dart';
import 'package:fitmate/features/health/presentation/health_connections_screen.dart';
import 'package:fitmate/features/profile/presentation/personal_info_screen.dart';
import 'package:fitmate/features/profile/presentation/profile_screens.dart';
import 'package:fitmate/features/progress/presentation/progress_screen.dart';
import 'package:fitmate/features/workout/presentation/active_workout_screen.dart';
import 'package:fitmate/features/workout/presentation/workout_screens.dart';

class GoRouterRefresh extends ChangeNotifier {
  GoRouterRefresh(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final dynamic _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((Ref ref) {
  final AuthRepository auth = ref.watch(authRepositoryProvider);
  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: GoRouterRefresh(auth.authStateChanges()),
    redirect: (BuildContext context, GoRouterState state) async {
      final AppUser? user = auth.currentUser;
      final String location = state.matchedLocation;
      final bool authRoute = location == '/welcome' ||
          location == '/sign-in' ||
          location == '/sign-up' ||
          location == '/forgot-password';

      if (user == null) {
        return authRoute ? null : '/welcome';
      }

      final profile = await ref.read(currentProfileProvider.future);
      final bool onboarded = profile?.hasCompletedOnboarding ?? false;
      final bool onboardingRoute = location.startsWith('/onboarding') ||
          location == '/generating-plan' ||
          location == '/plan-ready';

      if (!onboarded && !onboardingRoute) {
        return '/onboarding';
      }
      if (onboarded && (authRoute || location == '/onboarding')) {
        return '/home';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/welcome', pageBuilder: (BuildContext context, GoRouterState state) => const CupertinoPage<void>(child: WelcomeScreen())),
      GoRoute(path: '/sign-in', pageBuilder: (BuildContext context, GoRouterState state) => const CupertinoPage<void>(child: SignInScreen())),
      GoRoute(path: '/sign-up', pageBuilder: (BuildContext context, GoRouterState state) => const CupertinoPage<void>(child: SignUpScreen())),
      GoRoute(path: '/forgot-password', pageBuilder: (BuildContext context, GoRouterState state) => const CupertinoPage<void>(child: ForgotPasswordScreen())),
      GoRoute(path: '/onboarding', pageBuilder: (BuildContext context, GoRouterState state) => const CupertinoPage<void>(child: OnboardingScreen())),
      GoRoute(path: '/generating-plan', pageBuilder: (BuildContext context, GoRouterState state) => const CupertinoPage<void>(child: GeneratingPlanScreen())),
      GoRoute(path: '/plan-ready', pageBuilder: (BuildContext context, GoRouterState state) => const CupertinoPage<void>(child: PlanReadyScreen())),
      GoRoute(path: '/workout/:dayId', pageBuilder: (BuildContext context, GoRouterState state) {
        return CupertinoPage<void>(child: WorkoutDetailScreen(dayId: state.pathParameters['dayId']!));
      }),
      GoRoute(path: '/exercise/:exerciseId', pageBuilder: (BuildContext context, GoRouterState state) {
        return CupertinoPage<void>(child: ExerciseDetailScreen(exerciseId: state.pathParameters['exerciseId']!));
      }),
      GoRoute(path: '/active-workout/:dayId', pageBuilder: (BuildContext context, GoRouterState state) {
        return CupertinoPage<void>(child: ActiveWorkoutScreen(dayId: state.pathParameters['dayId']!));
      }),
      GoRoute(path: '/workout-complete', pageBuilder: (BuildContext context, GoRouterState state) => const CupertinoPage<void>(child: WorkoutCompleteScreen())),
      GoRoute(path: '/workout-history', pageBuilder: (BuildContext context, GoRouterState state) => const CupertinoPage<void>(child: WorkoutHistoryScreen())),
      GoRoute(path: '/profile', pageBuilder: (BuildContext context, GoRouterState state) => const CupertinoPage<void>(child: ProfileScreen())),
      GoRoute(path: '/personal-info', pageBuilder: (BuildContext context, GoRouterState state) => const CupertinoPage<void>(child: PersonalInfoScreen())),
      GoRoute(path: '/settings', pageBuilder: (BuildContext context, GoRouterState state) => const CupertinoPage<void>(child: SettingsScreen())),
      GoRoute(path: '/health', pageBuilder: (BuildContext context, GoRouterState state) => const CupertinoPage<void>(child: HealthConnectionsScreen())),
      GoRoute(path: '/preferences', pageBuilder: (BuildContext context, GoRouterState state) => const CupertinoPage<void>(child: PreferencesScreen())),
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(path: '/home', pageBuilder: (BuildContext context, GoRouterState state) => const NoTransitionPage<void>(child: HomeScreen())),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(path: '/workout', pageBuilder: (BuildContext context, GoRouterState state) => const NoTransitionPage<void>(child: WorkoutScreen())),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(path: '/nutrition', pageBuilder: (BuildContext context, GoRouterState state) => const NoTransitionPage<void>(child: NutritionScreen())),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(path: '/coach', pageBuilder: (BuildContext context, GoRouterState state) => const NoTransitionPage<void>(child: CoachScreen())),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(path: '/progress', pageBuilder: (BuildContext context, GoRouterState state) => const NoTransitionPage<void>(child: ProgressScreen())),
          ]),
        ],
      ),
    ],
  );
});
