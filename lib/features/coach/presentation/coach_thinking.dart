import 'package:flutter/cupertino.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';

class CoachThinkingRow extends StatefulWidget {
  const CoachThinkingRow({super.key});

  @override
  State<CoachThinkingRow> createState() => _CoachThinkingRowState();
}

class _CoachThinkingRowState extends State<CoachThinkingRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      liveRegion: true,
      label: 'Coach is thinking',
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Align(
          alignment: Alignment.centerLeft,
          child: reduceMotion
              ? Text(
                  'Thinking…',
                  style: AppTypography.meta(AppColors.muted(brightness)),
                )
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (BuildContext context, Widget? child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (int i = 0; i < 3; i++) ...<Widget>[
                          if (i > 0) const SizedBox(width: AppSpacing.xxs),
                          _Dot(
                            color: AppColors.muted(brightness),
                            active: _dotActive(i),
                          ),
                        ],
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  bool _dotActive(int index) {
    final double t = _controller.value;
    final double start = index / 3;
    final double end = start + 0.45;
    if (t >= start && t < end) {
      return true;
    }
    return false;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: active ? 1 : 0.28,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
