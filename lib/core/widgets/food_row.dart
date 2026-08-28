import 'package:flutter/cupertino.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/widgets/cards.dart';

class FoodRow extends StatelessWidget {
  const FoodRow({
    super.key,
    required this.name,
    required this.detail,
    this.onRemove,
  });

  final String name;
  final String detail;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return AppCard(
      semanticLabel: '$name, $detail',
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: AppTypography.headline(AppColors.ink(brightness))),
                Text(detail, style: AppTypography.meta(AppColors.muted(brightness))),
              ],
            ),
          ),
          if (onRemove != null)
            CupertinoButton(
              onPressed: onRemove,
              child: const Text('Remove'),
            ),
        ],
      ),
    );
  }
}

class NutritionCard extends StatelessWidget {
  const NutritionCard({
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
    return ProgressCard(title: title, current: current, target: target, unit: unit);
  }
}
