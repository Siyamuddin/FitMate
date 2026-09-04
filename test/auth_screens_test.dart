import 'package:fitmate/core/widgets/buttons.dart';
import 'package:fitmate/features/auth/presentation/sign_in_screen.dart';
import 'package:fitmate/features/auth/presentation/welcome_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('welcome shows create account and sign in', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, child: const WelcomeScreen());
    expect(find.text('FitMate'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('sign in with empty fields shows an error', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, child: const SignInScreen());
    await tester.tap(find.widgetWithText(PrimaryButton, 'Sign in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Enter your email and password.'), findsOneWidget);
  });

  testWidgets('sign in with credentials succeeds', (WidgetTester tester) async {
    await pumpScreen(tester, child: const SignInScreen());
    await tester.enterText(find.byType(CupertinoTextField).first, 'siyam@test.com');
    await tester.enterText(find.byType(CupertinoTextField).last, 'secret123');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Sign in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Enter your email and password.'), findsNothing);
  });
}
