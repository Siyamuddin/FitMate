import 'package:flutter/cupertino.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_radius.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/utils/formatters.dart';
import 'package:fitmate/core/widgets/app_text_field.dart';

Future<int?> showIntPicker({
  required BuildContext context,
  required String title,
  required int min,
  required int max,
  required int current,
  String suffix = '',
}) {
  final int clamped = current.clamp(min, max).toInt();
  int selected = clamped;
  return showCupertinoModalPopup<int>(
    context: context,
    builder: (BuildContext context) {
      final Brightness brightness = MediaQuery.platformBrightnessOf(context);
      final double bottomInset = MediaQuery.paddingOf(context).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          height: 292,
          decoration: BoxDecoration(
            color: AppColors.surface(brightness),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 8),
              SheetToolbar(
                title: title,
                onCancel: () => Navigator.pop(context),
                onSave: () => Navigator.pop(context, selected),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: FixedExtentScrollController(initialItem: clamped - min),
                  onSelectedItemChanged: (int index) => selected = min + index,
                  children: <Widget>[
                    for (int value = min; value <= max; value++) Center(child: Text('$value$suffix')),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<int?> showWeekdayPicker({
  required BuildContext context,
  required List<int> weekdays,
  required int current,
}) {
  if (weekdays.isEmpty) {
    return Future<int?>.value();
  }
  final List<int> options = List<int>.from(weekdays);
  int selected = options.contains(current) ? current : options.first;
  return showCupertinoModalPopup<int>(
    context: context,
    builder: (BuildContext context) {
      final Brightness brightness = MediaQuery.platformBrightnessOf(context);
      final double bottomInset = MediaQuery.paddingOf(context).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          height: 292,
          decoration: BoxDecoration(
            color: AppColors.surface(brightness),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 8),
              SheetToolbar(
                title: 'Day',
                onCancel: () => Navigator.pop(context),
                onSave: () => Navigator.pop(context, selected),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: FixedExtentScrollController(initialItem: options.indexOf(selected).clamp(0, options.length - 1)),
                  onSelectedItemChanged: (int index) => selected = options[index],
                  children: <Widget>[
                    for (final int weekday in options) Center(child: Text(Formatters.weekdayName(weekday))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<String?> showTextSheet({
  required BuildContext context,
  required String title,
  required String placeholder,
  String initial = '',
}) {
  return showCupertinoModalPopup<String>(
    context: context,
    builder: (BuildContext context) => _TextSheet(
      title: title,
      placeholder: placeholder,
      initial: initial,
    ),
  );
}

class _TextSheet extends StatefulWidget {
  const _TextSheet({
    required this.title,
    required this.placeholder,
    required this.initial,
  });

  final String title;
  final String placeholder;
  final String initial;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSave() {
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedPadding(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background(brightness),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, AppSpacing.md),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SheetToolbar(
                title: widget.title,
                onCancel: () => Navigator.pop(context),
                onSave: _handleSave,
              ),
              AppTextField(
                controller: _controller,
                placeholder: widget.placeholder,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleSave(),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class SheetToolbar extends StatelessWidget {
  const SheetToolbar({
    super.key,
    this.title,
    required this.onCancel,
    this.onSave,
    this.saveLabel = 'Save',
  });

  final String? title;
  final VoidCallback onCancel;
  final VoidCallback? onSave;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
          Expanded(
            child: title == null
                ? const SizedBox.shrink()
                : Text(
                    title!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headline(AppColors.ink(brightness)),
                  ),
          ),
          if (onSave == null)
            const SizedBox(width: 76)
          else
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              onPressed: onSave,
              child: Text(saveLabel),
            ),
        ],
      ),
    );
  }
}
