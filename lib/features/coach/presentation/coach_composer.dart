import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_radius.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';

class CoachComposer extends StatefulWidget {
  const CoachComposer({
    super.key,
    required this.controller,
    required this.online,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool online;
  final bool enabled;
  final VoidCallback onSend;

  @override
  State<CoachComposer> createState() => _CoachComposerState();
}

class _CoachComposerState extends State<CoachComposer> {
  static const double _tabBarHeight = 50;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(CoachComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  double _bottomInset(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double keyboard = media.viewInsets.bottom;
    if (keyboard <= 0) {
      return AppSpacing.sm;
    }
    final double occupiedBelow = _tabBarHeight + media.viewPadding.bottom;
    return math.max(AppSpacing.sm, keyboard - occupiedBelow);
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final bool canSend =
        widget.enabled &&
        widget.online &&
        widget.controller.text.trim().isNotEmpty;
    final String placeholder = widget.online
        ? 'Message'
        : 'Connect to talk to your coach';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        _bottomInset(context),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface(brightness),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.hairline(brightness)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Semantics(
                textField: true,
                label: placeholder,
                child: CupertinoTextField(
                  controller: widget.controller,
                  placeholder: placeholder,
                  enabled: widget.enabled && widget.online,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: canSend ? (_) => widget.onSend() : null,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    12,
                    AppSpacing.xs,
                    12,
                  ),
                  decoration: const BoxDecoration(),
                  style: AppTypography.body(AppColors.ink(brightness)),
                  placeholderStyle: AppTypography.body(
                    AppColors.muted(brightness),
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              enabled: canSend,
              label: 'Send',
              child: SizedBox(
                width: AppSpacing.minTap,
                height: AppSpacing.minTap,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: canSend ? widget.onSend : null,
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: canSend
                          ? AppColors.accent(brightness)
                          : AppColors.accent(
                              brightness,
                            ).withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.arrow_up,
                      size: 18,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
          ],
        ),
      ),
    );
  }
}
