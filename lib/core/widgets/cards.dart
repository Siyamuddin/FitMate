import 'package:flutter/cupertino.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_elevation.dart';
import 'package:fitmate/core/theme/app_radius.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final Widget content = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: AppElevation.hairline(brightness),
      ),
      child: child,
    );
    if (onTap == null) {
      return Semantics(container: true, label: semanticLabel, child: content);
    }
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return AppCard(
      semanticLabel: '$label $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppTypography.meta(AppColors.muted(brightness))),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTypography.title(AppColors.ink(brightness))),
          if (detail != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            Text(detail!, style: AppTypography.meta(AppColors.muted(brightness))),
          ],
        ],
      ),
    );
  }
}

class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.title,
    required this.current,
    required this.target,
    required this.unit,
  });

  final String title;
  final double current;
  final double target;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final double progress = target == 0 ? 0 : (current / target).clamp(0, 1);
    return AppCard(
      semanticLabel: '$title ${current.round()} of ${target.round()} $unit',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppTypography.headline(AppColors.ink(brightness))),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${current.round()} / ${target.round()} $unit',
            style: AppTypography.meta(AppColors.muted(brightness)),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: SizedBox(
              height: 8,
              child: ColoredBox(
                color: AppColors.hairline(brightness),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: ColoredBox(color: AppColors.accent(brightness)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
