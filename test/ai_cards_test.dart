import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/widgets/ai_cards.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pending card shows lines and actions', (WidgetTester tester) async {
    bool applied = false;
    bool dismissed = false;
    await tester.pumpWidget(
      CupertinoApp(
        home: ColoredBox(
          color: AppColors.lightBackground,
          child: AIActionCard(
            lines: const <String>['Add Push-up · 3 × 10 on Monday'],
            onApply: () => applied = true,
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );

    expect(find.text('Ready to apply'), findsOneWidget);
    expect(find.text('Add Push-up · 3 × 10 on Monday'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);

    await tester.tap(find.text('Apply'));
    await tester.pump();
    expect(applied, isTrue);

    await tester.tap(find.text('Not now'));
    await tester.pump();
    expect(dismissed, isTrue);
  });

  testWidgets('applied card shows Saved and hides buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: ColoredBox(
          color: AppColors.lightBackground,
          child: AIActionCard(
            lines: const <String>['Add Push-up · 3 × 10 on Monday'],
            applied: true,
            onApply: () {},
            onDismiss: () {},
          ),
        ),
      ),
    );

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Add Push-up · 3 × 10 on Monday'), findsOneWidget);
    expect(find.text('Apply'), findsNothing);
    expect(find.text('Not now'), findsNothing);
  });
}
