import 'package:fitmate/features/health/presentation/health_connections_screen.dart';
import 'package:fitmate/features/profile/presentation/profile_screens.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('profile lists account destinations', (WidgetTester tester) async {
    await pumpScreen(tester, child: const ProfileScreen());
    expect(find.text('Siyam'), findsOneWidget);
    expect(find.text('Personal Info'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('settings shows reminder toggles', (WidgetTester tester) async {
    await pumpScreen(tester, child: const SettingsScreen());
    expect(find.text('Workout reminders'), findsOneWidget);
    expect(find.text('Meal reminders'), findsOneWidget);
  });

  testWidgets('health screen loads disconnected', (WidgetTester tester) async {
    await pumpScreen(tester, child: const HealthConnectionsScreen());
    await tester.pump();
    expect(find.text('Apple Health'), findsOneWidget);
    expect(find.text('Not connected.'), findsOneWidget);
    expect(find.text('Connect Apple Health'), findsOneWidget);
  });
}
