import 'package:flutter/cupertino.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_radius.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';

class AIMessageBubble extends StatelessWidget {
  const AIMessageBubble({super.key, required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    if (!isUser) {
      return Semantics(
        label: 'Coach: $text',
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              style: AppTypography.body(AppColors.ink(brightness)),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        label: 'You: $text',
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          decoration: BoxDecoration(
            color: AppColors.accent(brightness),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.card),
              topRight: Radius.circular(AppRadius.card),
              bottomLeft: Radius.circular(AppRadius.card),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: Text(text, style: AppTypography.body(CupertinoColors.white)),
        ),
      ),
    );
  }
}

class AIActionCard extends StatelessWidget {
  const AIActionCard({
    super.key,
    required this.summary,
    required this.onApply,
    required this.onDismiss,
    this.applying = false,
  });

  final String summary;
  final VoidCallback onApply;
  final VoidCallback onDismiss;
  final bool applying;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface(brightness),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Recommended change',
                style: AppTypography.meta(AppColors.muted(brightness)),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                summary,
                style: AppTypography.body(AppColors.ink(brightness)),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.minTap,
                      ),
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        color: AppColors.accent(brightness),
                        disabledColor: AppColors.accent(
                          brightness,
                        ).withValues(alpha: 0.4),
                        onPressed: applying ? null : onApply,
                        child: applying
                            ? const CupertinoActivityIndicator(
                                color: CupertinoColors.white,
                              )
                            : Semantics(
                                button: true,
                                label: 'Apply recommended change',
                                child: Text(
                                  'Apply',
                                  style: AppTypography.headline(
                                    CupertinoColors.white,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.minTap,
                      ),
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        color: AppColors.background(brightness),
                        onPressed: applying ? null : onDismiss,
                        child: Semantics(
                          button: true,
                          label: 'Not now',
                          child: Text(
                            'Not now',
                            style: AppTypography.headline(
                              AppColors.ink(brightness),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AIAppliedLabel extends StatelessWidget {
  const AIAppliedLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        label: 'Saved to your plan',
        child: Row(
          children: <Widget>[
            const Icon(
              CupertinoIcons.check_mark_circled,
              size: 18,
              color: AppColors.success,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Saved to your plan',
              style: AppTypography.meta(AppColors.muted(brightness)),
            ),
          ],
        ),
      ),
    );
  }
}
