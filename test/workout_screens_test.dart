import 'package:fitmate/features/workout/presentation/workout_screens.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('workout list shows plan days', (WidgetTester tester) async {
    await pumpScreen(tester, child: const WorkoutScreen());
    expect(find.text('Foundation'), findsOneWidget);
    expect(find.textContaining('Push'), findsWidgets);
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('workout detail can start the day', (WidgetTester tester) async {
    await pumpScreen(
      tester,
      child: const WorkoutDetailScreen(dayId: 'day-mon'),
    );
    expect(find.text('Push'), findsWidgets);
    expect(find.text('Start Workout'), findsOneWidget);
    expect(find.text('Push-up'), findsOneWidget);
  });
}
