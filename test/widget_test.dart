import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/widgets/buttons.dart';
import 'package:fitmate/core/widgets/set_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('primary button exposes a semantic label', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: ColoredBox(
          color: AppColors.lightBackground,
          child: PrimaryButton(label: 'Start Workout', onPressed: null),
        ),
      ),
    );
    expect(find.text('Start Workout'), findsOneWidget);
    expect(tester.getSize(find.byType(PrimaryButton)).height, greaterThanOrEqualTo(44));
  });

  testWidgets('set complete target is at least 56pt', (WidgetTester tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: ColoredBox(
          color: AppColors.lightBackground,
          child: SetRow(
            setNumber: 1,
            summary: '60 kg × 10',
            completed: false,
            onComplete: () {},
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(SetRow)).height, greaterThanOrEqualTo(56));
  });
}
