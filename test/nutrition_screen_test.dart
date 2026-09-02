import 'package:fitmate/features/nutrition/presentation/nutrition_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('nutrition shows targets and a logged food', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, child: const NutritionScreen());
    expect(find.text('Calories'), findsOneWidget);
    expect(find.text('Protein'), findsOneWidget);
    expect(find.text('Chicken'), findsOneWidget);
    expect(find.text('Log food'), findsOneWidget);
  });
}
