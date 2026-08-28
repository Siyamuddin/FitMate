import 'package:flutter/cupertino.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/widgets/cards.dart';

class WorkoutCard extends StatelessWidget {
  const WorkoutCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return AppCard(
      semanticLabel: '$title, $subtitle',
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppTypography.headline(AppColors.ink(brightness))),
          const SizedBox(height: AppSpacing.xxs),
          Text(subtitle, style: AppTypography.meta(AppColors.muted(brightness))),
        ],
      ),
    );
  }
}

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.name,
    required this.detail,
    this.onTap,
  });

  final String name;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return AppCard(
      semanticLabel: '$name, $detail',
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(name, style: AppTypography.headline(AppColors.ink(brightness))),
          const SizedBox(height: AppSpacing.xxs),
          Text(detail, style: AppTypography.meta(AppColors.muted(brightness))),
        ],
      ),
    );
  }
}
