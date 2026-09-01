import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_radius.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/utils/formatters.dart';
import 'package:fitmate/core/widgets/app_text_field.dart';
import 'package:fitmate/core/widgets/grouped_rows.dart';
import 'package:fitmate/core/widgets/picker_sheet.dart';
import 'package:fitmate/core/widgets/states.dart';
import 'package:fitmate/features/workout/domain/workout_models.dart';
import 'package:fitmate/features/workout/presentation/workout_providers.dart';

class AddDayResult {
  const AddDayResult({required this.name, required this.weekday});

  final String name;
  final int weekday;
}

Future<AddDayResult?> showAddDaySheet({
  required BuildContext context,
  required List<int> usedWeekdays,
}) {
  const List<int> weekOrder = <int>[1, 2, 3, 4, 5, 6, 0];
  final List<int> available = weekOrder.where((int day) => !usedWeekdays.contains(day)).toList();
  if (available.isEmpty) {
    return Future<AddDayResult?>.value();
  }
  return showCupertinoModalPopup<AddDayResult>(
    context: context,
    builder: (BuildContext context) => _AddDaySheet(availableWeekdays: available),
  );
}

class _AddDaySheet extends StatefulWidget {
  const _AddDaySheet({required this.availableWeekdays});

  final List<int> availableWeekdays;

  @override
  State<_AddDaySheet> createState() => _AddDaySheetState();
}

class _AddDaySheetState extends State<_AddDaySheet> {
  late final TextEditingController _name = TextEditingController();
  late int _weekday = widget.availableWeekdays.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _handleSave() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.pop(context, AddDayResult(name: name, weekday: _weekday));
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
                title: 'Add Day',
                onCancel: () => Navigator.pop(context),
                onSave: _handleSave,
              ),
              AppTextField(
                controller: _name,
                placeholder: 'Workout name',
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleSave(),
              ),
              const SizedBox(height: AppSpacing.md),
              GroupedSection(
                children: <Widget>[
                  GroupedValueRow(
                    label: 'Day',
                    value: Formatters.weekdayName(_weekday),
                    onTap: () async {
                      final int? picked = await showWeekdayPicker(
                        context: context,
                        weekdays: widget.availableWeekdays,
                        current: _weekday,
                      );
                      if (picked != null) {
                        setState(() => _weekday = picked);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

Future<Exercise?> showExercisePickerSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Set<String> alreadyAddedIds,
}) {
  return showCupertinoModalPopup<Exercise>(
    context: context,
    builder: (BuildContext context) => _ExercisePickerSheet(alreadyAddedIds: alreadyAddedIds),
  );
}

class _ExercisePickerSheet extends ConsumerStatefulWidget {
  const _ExercisePickerSheet({required this.alreadyAddedIds});

  final Set<String> alreadyAddedIds;

  @override
  ConsumerState<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<_ExercisePickerSheet> {
  final TextEditingController _query = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _createNamedExercise(String rawName) async {
    if (_creating) {
      return;
    }
    setState(() => _creating = true);
    try {
      final Exercise exercise = await ref.read(workoutRepositoryProvider).findOrCreateCustomExercise(rawName);
      ref.invalidate(exerciseCatalogProvider);
      if (!mounted) {
        return;
      }
      Navigator.pop(context, exercise);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _creating = false);
      await showCupertinoDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text('Could not add'),
            content: Text('$error'),
            actions: <Widget>[
              CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final AsyncValue<List<Exercise>> catalog = ref.watch(exerciseCatalogProvider);
    final double height = MediaQuery.sizeOf(context).height * 0.85;
    final String query = _query.text.trim();
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.background(brightness),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, AppSpacing.md),
          child: Column(
            children: <Widget>[
              SheetToolbar(
                title: 'Add Exercise',
                onCancel: () => Navigator.pop(context),
              ),
              AppTextField(
                controller: _query,
                placeholder: 'Search or add',
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                onSubmitted: (String value) {
                  if (value.trim().isNotEmpty) {
                    _createNamedExercise(value);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: catalog.when(
                  loading: () => const LoadingState(),
                  error: (Object error, _) => ErrorState(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(exerciseCatalogProvider),
                  ),
                  data: (List<Exercise> exercises) {
                    final String needle = query.toLowerCase();
                    final List<Exercise> matches = exercises.where((Exercise exercise) {
                      if (widget.alreadyAddedIds.contains(exercise.id)) {
                        return false;
                      }
                      if (needle.isEmpty) {
                        return true;
                      }
                      return exercise.name.toLowerCase().contains(needle) ||
                          exercise.primaryMuscle.toLowerCase().contains(needle);
                    }).toList();
                    final bool exactMatch = exercises.any(
                      (Exercise exercise) => exercise.name.toLowerCase() == needle,
                    );
                    final bool showCreate = query.isNotEmpty && !exactMatch;
                    if (matches.isEmpty && !showCreate) {
                      return const EmptyState(title: 'No exercises', message: 'Type a name to add your own.');
                    }
                    return ListView(
                      children: <Widget>[
                        if (showCreate) ...<Widget>[
                          GroupedSection(
                            children: <Widget>[
                              GroupedNavRow(
                                title: _creating ? 'Adding…' : 'Add “$query”',
                                subtitle: 'Save this name to your exercises',
                                showChevron: false,
                                leading: Icon(CupertinoIcons.plus_circle_fill, color: AppColors.accent(brightness)),
                                onTap: _creating ? null : () => _createNamedExercise(query),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (matches.isNotEmpty)
                          GroupedSection(
                            children: matches
                                .map(
                                  (Exercise exercise) => GroupedNavRow(
                                    title: exercise.name,
                                    subtitle: exercise.primaryMuscle.isEmpty || exercise.primaryMuscle == 'other'
                                        ? null
                                        : exercise.primaryMuscle,
                                    onTap: () => Navigator.pop(context, exercise),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
