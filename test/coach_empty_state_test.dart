import 'package:fitmate/features/coach/presentation/coach_empty_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows prompt chips and reports taps', (WidgetTester tester) async {
    String? tapped;
    await tester.pumpWidget(
      CupertinoApp(
        home: CoachEmptyState(
          online: true,
          onPrompt: (String prompt) => tapped = prompt,
        ),
      ),
    );

    expect(find.text('What do you want to work on?'), findsOneWidget);
    expect(find.text('Yesterday felt too hard'), findsOneWidget);
    expect(find.text('Connect to talk to your coach'), findsNothing);

    await tester.tap(find.text('Yesterday felt too hard'));
    await tester.pump();
    expect(tapped, 'Yesterday felt too hard');
  });

  testWidgets('offline copy disables chips', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      CupertinoApp(
        home: CoachEmptyState(
          online: false,
          onPrompt: (_) => tapped = true,
        ),
      ),
    );

    expect(find.text('Connect to talk to your coach'), findsOneWidget);
    await tester.tap(find.text('Yesterday felt too hard'));
    await tester.pump();
    expect(tapped, isFalse);
  });
}
