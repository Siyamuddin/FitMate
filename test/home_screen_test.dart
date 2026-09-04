import 'package:fitmate/features/home/presentation/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('home shows greeting, workout, and nutrition', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, child: const HomeScreen());
    expect(find.textContaining('Siyam'), findsOneWidget);
    expect(find.text("Today's workout"), findsOneWidget);
    expect(find.text('Start Workout'), findsOneWidget);
    expect(find.text('Nutrition'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Log Food'), 300);
    expect(find.text('Log Food'), findsOneWidget);
    expect(find.text('4321'), findsOneWidget);
  });
}
