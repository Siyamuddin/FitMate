import 'package:flutter/services.dart';

class AppHaptics {
  const AppHaptics._();

  static Future<void> setCompleted() {
    return HapticFeedback.mediumImpact();
  }

  static Future<void> workoutCompleted() {
    return HapticFeedback.heavyImpact();
  }

  static Future<void> confirmation() {
    return HapticFeedback.lightImpact();
  }

  static Future<void> toggle() {
    return HapticFeedback.selectionClick();
  }
}
