import 'package:flutter/cupertino.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_radius.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';

class GroupedSection extends StatelessWidget {
  const GroupedSection({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: ColoredBox(
        color: AppColors.surface(brightness),
        child: Column(
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0)
                Container(
                  height: 0.5,
                  margin: const EdgeInsets.only(left: AppSpacing.md),
                  color: AppColors.hairline(brightness),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class GroupedValueRow extends StatelessWidget {
  const GroupedValueRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return Semantics(
      button: true,
      label: '$label, $value',
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
          onPressed: onTap,
          child: Row(
            children: <Widget>[
              Text(label, style: AppTypography.body(AppColors.ink(brightness))),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: AppTypography.body(AppColors.muted(brightness)),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.muted(brightness)),
            ],
          ),
        ),
      ),
    );
  }
}

class GroupedNavRow extends StatelessWidget {
  const GroupedNavRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.showChevron = true,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            leading!,
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTypography.headline(AppColors.ink(brightness))),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(subtitle!, style: AppTypography.meta(AppColors.muted(brightness))),
                ],
              ],
            ),
          ),
          if (onTap != null && showChevron) Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.muted(brightness)),
        ],
      ),
    );
    if (onTap == null) {
      return Semantics(container: true, label: '$title, ${subtitle ?? ''}', child: row);
    }
    return Semantics(
      button: true,
      label: '$title, ${subtitle ?? ''}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: row,
      ),
    );
  }
}

class GroupedSectionLabel extends StatelessWidget {
  const GroupedSectionLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
      child: Text(text, style: AppTypography.meta(AppColors.muted(brightness))),
    );
  }
}
