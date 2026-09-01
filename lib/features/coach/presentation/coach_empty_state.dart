import 'package:flutter/cupertino.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_radius.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';

class CoachEmptyState extends StatelessWidget {
  const CoachEmptyState({
    super.key,
    required this.online,
    required this.onPrompt,
  });

  final bool online;
  final ValueChanged<String> onPrompt;

  static const List<String> prompts = <String>[
    'Yesterday felt too hard',
    'What should I eat tonight?',
    'Why is my weight stalling?',
    'Change my training days',
  ];

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'What do you want to work on?',
              style: AppTypography.title(AppColors.ink(brightness)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your coach can adjust training, meals, and goals.',
              style: AppTypography.body(AppColors.muted(brightness)),
              textAlign: TextAlign.center,
            ),
            if (!online) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Connect to talk to your coach',
                  style: AppTypography.meta(AppColors.muted(brightness)),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: prompts
                  .map(
                    (String prompt) => _PromptChip(
                      label: prompt,
                      enabled: online,
                      onTap: () => onPrompt(prompt),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTap),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          minimumSize: const Size(0, AppSpacing.minTap),
          borderRadius: BorderRadius.circular(AppRadius.chip),
          color: AppColors.surface(brightness),
          disabledColor: AppColors.surface(brightness).withValues(alpha: 0.6),
          onPressed: enabled ? onTap : null,
          child: Text(
            label,
            style: AppTypography.callout(
              enabled ? AppColors.ink(brightness) : AppColors.muted(brightness),
            ),
          ),
        ),
      ),
    );
  }
}
