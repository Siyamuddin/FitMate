import 'package:flutter/widgets.dart';

class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 220);
  static const Curve curve = Curves.easeOut;

  static Duration durationOf(BuildContext context) {
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      return Duration.zero;
    }
    return standard;
  }
}
