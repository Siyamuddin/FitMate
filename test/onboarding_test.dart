import 'package:fitmate/core/constants/enums.dart';
import 'package:fitmate/features/onboarding/presentation/onboarding_controller.dart';
import 'package:fitmate/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('onboarding starts on the goal step', (WidgetTester tester) async {
    await pumpScreen(tester, child: const OnboardingScreen());
    expect(find.text('Step 1 of 8'), findsOneWidget);
    expect(find.text('What is your primary goal?'), findsOneWidget);
    expect(find.text('Lose fat'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  test('OnboardingController updates the draft', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final OnboardingController controller = container.read(
      onboardingControllerProvider.notifier,
    );
    controller.setGoal(GoalType.buildMuscle);
    controller.setBody(age: 30, weightKg: 80);
    controller.setActivity(ActivityLevel.veryActive);
    controller.setEnvironment(TrainingEnvironment.gym);
    controller.setSchedule(days: 5);
    controller.setDiet(DietType.highProtein);

    final draft = container.read(onboardingControllerProvider);
    expect(draft.goalType, GoalType.buildMuscle);
    expect(draft.age, 30);
    expect(draft.weightKg, 80);
    expect(draft.activityLevel, ActivityLevel.veryActive);
    expect(draft.environment, TrainingEnvironment.gym);
    expect(draft.daysPerWeek, 5);
    expect(draft.dietType, DietType.highProtein);
  });
}
