import 'package:flutter/cupertino.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_radius.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';

class AIMessageBubble extends StatelessWidget {
  const AIMessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.child,
  });

  final String text;
  final bool isUser;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Semantics(
        label: isUser ? 'You: $text' : 'Coach: $text',
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
          decoration: BoxDecoration(
            color: isUser ? AppColors.accent(brightness) : AppColors.surface(brightness),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                text,
                style: AppTypography.body(isUser ? CupertinoColors.white : AppColors.ink(brightness)),
              ),
              ?child,
            ],
          ),
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
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Recommended change', style: AppTypography.meta(AppColors.muted(brightness))),
          const SizedBox(height: AppSpacing.xxs),
          Text(summary, style: AppTypography.body(AppColors.ink(brightness))),
          Row(
            children: <Widget>[
              CupertinoButton(
                onPressed: applying ? null : onApply,
                child: applying
                    ? const CupertinoActivityIndicator()
                    : Semantics(button: true, label: 'Apply recommended change', child: const Text('Apply')),
              ),
              CupertinoButton(
                onPressed: applying ? null : onDismiss,
                child: Semantics(button: true, label: 'Not now', child: const Text('Not now')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
