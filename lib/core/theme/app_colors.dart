import 'package:flutter/cupertino.dart';

class AppColors {
  const AppColors._();

  static const Color lightBackground = Color(0xFFF6F5F2);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightInk = Color(0xFF1C1C1A);
  static const Color lightMuted = Color(0xFF6F6D68);
  static const Color lightAccent = Color(0xFF0F6E6B);
  static const Color lightHairline = Color(0x1A1C1C1A);

  static const Color darkBackground = Color(0xFF121211);
  static const Color darkSurface = Color(0xFF1C1C1A);
  static const Color darkInk = Color(0xFFF3F1EC);
  static const Color darkMuted = Color(0xFFA8A59E);
  static const Color darkAccent = Color(0xFF3AA8A4);
  static const Color darkHairline = Color(0x33F3F1EC);

  static const Color success = Color(0xFF2F7D4A);
  static const Color warning = Color(0xFFB26A00);
  static const Color danger = Color(0xFFC0392B);

  static Color background(Brightness brightness) {
    return brightness == Brightness.dark ? darkBackground : lightBackground;
  }

  static Color surface(Brightness brightness) {
    return brightness == Brightness.dark ? darkSurface : lightSurface;
  }

  static Color ink(Brightness brightness) {
    return brightness == Brightness.dark ? darkInk : lightInk;
  }

  static Color muted(Brightness brightness) {
    return brightness == Brightness.dark ? darkMuted : lightMuted;
  }

  static Color accent(Brightness brightness) {
    return brightness == Brightness.dark ? darkAccent : lightAccent;
  }

  static Color hairline(Brightness brightness) {
    return brightness == Brightness.dark ? darkHairline : lightHairline;
  }
}
