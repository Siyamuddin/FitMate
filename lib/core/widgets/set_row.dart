import 'package:flutter/cupertino.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_radius.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';

class SetRow extends StatelessWidget {
  const SetRow({
    super.key,
    required this.setNumber,
    required this.summary,
    required this.completed,
    required this.onComplete,
  });

  final int setNumber;
  final String summary;
  final bool completed;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return Semantics(
      button: true,
      label: completed ? 'Set $setNumber completed' : 'Complete set $setNumber',
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpacing.largeTap),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface(brightness),
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 56,
              child: Text('Set $setNumber', style: AppTypography.headline(AppColors.ink(brightness))),
            ),
            Expanded(child: Text(summary, style: AppTypography.body(AppColors.ink(brightness)))),
            Text(completed ? 'Done' : 'Open', style: AppTypography.meta(AppColors.muted(brightness))),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: AppSpacing.largeTap,
              height: AppSpacing.largeTap,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                color: completed ? AppColors.success : AppColors.accent(brightness),
                borderRadius: BorderRadius.circular(AppRadius.chip),
                onPressed: onComplete,
                child: Icon(
                  completed ? CupertinoIcons.checkmark : CupertinoIcons.circle,
                  color: CupertinoColors.white,
                  semanticLabel: completed ? 'Completed' : 'Mark complete',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
