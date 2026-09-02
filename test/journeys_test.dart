import 'package:fitmate/core/networking/edge_functions.dart';
import 'package:fitmate/core/routing/app_router.dart';
import 'package:fitmate/features/coach/presentation/coach_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(CupertinoTabBar),
      matching: find.text(label),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('signed-out /home redirects to welcome', (
    WidgetTester tester,
  ) async {
    final container = await pumpFitMateApp(
      tester,
      AppHarness.signedOut(),
      addTearDown: addTearDown,
    );
    container.read(routerProvider).go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('signed-in without onboarding lands on onboarding', (
    WidgetTester tester,
  ) async {
    await pumpFitMateApp(
      tester,
      AppHarness.needsOnboarding(),
      addTearDown: addTearDown,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('What is your primary goal?'), findsOneWidget);
  });

  testWidgets('onboarded member can switch primary tabs', (
    WidgetTester tester,
  ) async {
    await pumpFitMateApp(
      tester,
      AppHarness.onboarded(),
      addTearDown: addTearDown,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Siyam'), findsWidgets);

    await _tapTab(tester, 'Workout');
    expect(find.text('Foundation'), findsOneWidget);

    await _tapTab(tester, 'Nutrition');
    expect(find.text('Calories'), findsOneWidget);

    await _tapTab(tester, 'Coach');
    expect(find.text('What do you want to work on?'), findsOneWidget);

    await _tapTab(tester, 'Progress');
    expect(find.text('74.0 kg'), findsOneWidget);
  });

  testWidgets('coach propose then Apply shows Saved', (
    WidgetTester tester,
  ) async {
    Future<Map<String, dynamic>> fakeCoach(
      String name, {
      Map<String, dynamic>? body,
    }) async {
      return <String, dynamic>{
        'intent': 'propose',
        'message': 'I can add push-ups on Monday.',
        'requires_confirmation': true,
        'preview_lines': <String>['Add Push-up · 3 × 10 on Monday'],
        'actions': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'add_exercise',
            'changes': <String, dynamic>{
              'weekday': 1,
              'exercise_name': 'Push-up',
              'sets': 3,
              'reps': 10,
            },
          },
        ],
      };
    }

    await pumpScreen(
      tester,
      harness: AppHarness.onboarded(edgeFunctions: fakeCoach),
      child: const CoachScreen(),
    );
    expect(find.text('What do you want to work on?'), findsOneWidget);

    await tester.tap(find.text('Yesterday felt too hard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('I can add push-ups on Monday.'), findsOneWidget);

    expect(find.text('I can add push-ups on Monday.'), findsOneWidget);
    expect(find.text('Ready to apply'), findsOneWidget);
    expect(find.text('Add Push-up · 3 × 10 on Monday'), findsOneWidget);

    await tester.tap(find.text('Apply'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Apply'), findsNothing);
  });
}
