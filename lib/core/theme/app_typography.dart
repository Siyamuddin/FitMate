import 'package:flutter/cupertino.dart';

class AppTypography {
  const AppTypography._();

  static TextStyle display(Color color) {
    return TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w600,
      height: 1.15,
      letterSpacing: -0.4,
      color: color,
    );
  }

  static TextStyle title(Color color) {
    return TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 1.25,
      letterSpacing: -0.2,
      color: color,
    );
  }

  static TextStyle headline(Color color) {
    return TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: color,
    );
  }

  static TextStyle body(Color color) {
    return TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w400,
      height: 1.35,
      color: color,
    );
  }

  static TextStyle callout(Color color) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.35,
      color: color,
    );
  }

  static TextStyle meta(Color color) {
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.3,
      color: color,
    );
  }
}
