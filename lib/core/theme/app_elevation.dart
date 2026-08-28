import 'package:flutter/cupertino.dart';
import 'package:fitmate/core/theme/app_colors.dart';

class AppElevation {
  const AppElevation._();

  static BoxBorder hairline(Brightness brightness) {
    return Border.all(color: AppColors.hairline(brightness));
  }

  static List<BoxShadow> none = const <BoxShadow>[];
}
