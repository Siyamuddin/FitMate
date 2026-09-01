import 'package:flutter/cupertino.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_radius.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';

class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    required this.child,
    this.heightFactor = 0.85,
  });

  final String title;
  final Widget child;
  final double heightFactor;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    double heightFactor = 0.85,
  }) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (BuildContext context) {
        return AppSheet(title: title, heightFactor: heightFactor, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return Container(
      height: MediaQuery.sizeOf(context).height * heightFactor,
      padding: const EdgeInsets.all(AppSpacing.page),
      decoration: BoxDecoration(
        color: AppColors.background(brightness),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Text(title, style: AppTypography.title(AppColors.ink(brightness))),
            const SizedBox(height: AppSpacing.md),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class AppActionSheet {
  const AppActionSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? message,
    required List<CupertinoActionSheetAction> actions,
  }) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text(title),
          message: message == null ? null : Text(message),
          actions: actions,
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }
}

Future<bool> showDestructiveConfirm({
  required BuildContext context,
  required String title,
  String? message,
  required String action,
}) async {
  final bool? confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return CupertinoAlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
