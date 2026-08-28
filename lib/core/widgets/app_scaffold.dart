import 'package:flutter/cupertino.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_spacing.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.navigationBar,
    this.backgroundColor,
  });

  final Widget child;
  final ObstructingPreferredSizeWidget? navigationBar;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return CupertinoPageScaffold(
      backgroundColor: backgroundColor ?? AppColors.background(brightness),
      navigationBar: navigationBar,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: child,
        ),
      ),
    );
  }
}
