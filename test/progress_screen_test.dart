import 'package:fitmate/features/progress/presentation/progress_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('progress shows current and target weight', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, child: const ProgressScreen());
    expect(find.text('Now'), findsOneWidget);
    expect(find.text('74.0 kg'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('68.0 kg'), findsOneWidget);
    expect(find.text('Log'), findsOneWidget);
  });
}
