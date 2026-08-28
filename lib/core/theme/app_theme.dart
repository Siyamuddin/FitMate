import 'package:flutter/cupertino.dart';
import 'package:fitmate/core/theme/app_colors.dart';

class AppTheme {
  const AppTheme._();

  static CupertinoThemeData of(Brightness brightness) {
    final Color ink = AppColors.ink(brightness);
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: AppColors.accent(brightness),
      primaryContrastingColor: AppColors.surface(brightness),
      barBackgroundColor: AppColors.surface(brightness).withValues(alpha: 0.92),
      scaffoldBackgroundColor: AppColors.background(brightness),
      textTheme: CupertinoTextThemeData(
        primaryColor: ink,
        textStyle: TextStyle(
          fontSize: 17,
          color: ink,
        ),
        navTitleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        navLargeTitleTextStyle: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
          color: ink,
        ),
        actionTextStyle: TextStyle(
          fontSize: 17,
          color: AppColors.accent(brightness),
        ),
      ),
    );
  }
}
