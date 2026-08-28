import 'package:flutter/cupertino.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_radius.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expanded = true,
    this.large = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expanded;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final Widget button = ConstrainedBox(
      constraints: BoxConstraints(minHeight: large ? AppSpacing.largeTap : AppSpacing.minTap),
      child: CupertinoButton(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: large ? 16 : 12,
        ),
        borderRadius: BorderRadius.circular(AppRadius.button),
        color: AppColors.accent(brightness),
        disabledColor: AppColors.accent(brightness).withValues(alpha: 0.4),
        onPressed: onPressed,
        child: Text(
          label,
          style: AppTypography.headline(CupertinoColors.white),
        ),
      ),
    );
    if (!expanded) {
      return Semantics(button: true, label: label, child: button);
    }
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(width: double.infinity, child: button),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 12),
          borderRadius: BorderRadius.circular(AppRadius.button),
          color: AppColors.surface(brightness),
          onPressed: onPressed,
          child: Text(
            label,
            style: AppTypography.headline(AppColors.accent(brightness)),
          ),
        ),
      ),
    );
  }
}
