import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/constants/enums.dart';
import 'package:fitmate/core/haptics/app_haptics.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_radius.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/utils/formatters.dart';
import 'package:fitmate/core/widgets/app_scaffold.dart';
import 'package:fitmate/core/widgets/app_sheet.dart';
import 'package:fitmate/core/widgets/app_text_field.dart';
import 'package:fitmate/core/widgets/picker_sheet.dart';
import 'package:fitmate/core/widgets/states.dart';
import 'package:fitmate/features/nutrition/presentation/nutrition_screen.dart';
import 'package:fitmate/features/onboarding/domain/profile_models.dart';
import 'package:fitmate/features/onboarding/presentation/onboarding_controller.dart';
import 'package:fitmate/features/progress/presentation/progress_screen.dart';
import 'package:fitmate/services/analytics/analytics_service.dart';

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(currentProfileProvider);
      ref.invalidate(personalDetailsProvider);
      ref.invalidate(progressSnapshotProvider);
      ref.invalidate(todayNutritionProvider);
      ref.read(analyticsServiceProvider).track('profile_updated');
      AppHaptics.confirmation();
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showCupertinoDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text('Could not save'),
            content: Text('$error'),
            actions: <Widget>[
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PersonalDetails?> details = ref.watch(personalDetailsProvider);
    return AppScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Personal Info')),
      child: details.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const LoadingState(),
        error: (Object error, _) => ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(personalDetailsProvider),
        ),
        data: (PersonalDetails? data) {
          if (data == null) {
            return const EmptyState(
              title: 'No profile yet',
              message: 'Sign in again to load your details.',
            );
          }
          final Profile profile = data.profile;
          final Brightness brightness = MediaQuery.platformBrightnessOf(context);
          return ListView(
            children: <Widget>[
              const SizedBox(height: AppSpacing.lg),
              _SectionLabel(text: 'Personal', brightness: brightness),
              _InfoGroup(
                children: <Widget>[
                  _ValueRow(
                    label: 'Name',
                    value: profile.displayName ?? 'Not set',
                    onTap: () => _editName(profile.displayName),
                  ),
                  _ValueRow(
                    label: 'Age',
                    value: profile.age == null ? 'Not set' : '${profile.age}',
                    onTap: () => _pickInt(
                      title: 'Age',
                      min: 16,
                      max: 80,
                      current: profile.age ?? 25,
                      onSave: (int age) => _run(() {
                        return ref.read(profileRepositoryProvider).updateProfileFields(
                          age: age,
                          recalculateNutrition: true,
                        );
                      }),
                    ),
                  ),
                  _ValueRow(
                    label: 'Sex',
                    value: _sexLabel(profile.sex),
                    onTap: () => _pickSex(profile.sex),
                  ),
                  _ValueRow(
                    label: 'Height',
                    value: profile.heightCm == null ? 'Not set' : '${profile.heightCm!.round()} cm',
                    onTap: () => _pickInt(
                      title: 'Height',
                      min: 140,
                      max: 210,
                      current: profile.heightCm?.round() ?? 170,
                      suffix: ' cm',
                      onSave: (int cm) => _run(() {
                        return ref.read(profileRepositoryProvider).updateProfileFields(
                          heightCm: cm.toDouble(),
                          recalculateNutrition: true,
                        );
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionLabel(text: 'Body', brightness: brightness),
              _InfoGroup(
                children: <Widget>[
                  _ValueRow(
                    label: 'Weight',
                    value: data.currentWeightKg == null ? 'Not set' : Formatters.kg(data.currentWeightKg!),
                    onTap: () => _pickInt(
                      title: 'Weight',
                      min: 40,
                      max: 180,
                      current: data.currentWeightKg?.round() ?? 74,
                      suffix: ' kg',
                      onSave: (int kg) => _run(() async {
                        await ref.read(profileRepositoryProvider).logWeight(kg.toDouble());
                        ref.read(analyticsServiceProvider).track('weight_logged');
                      }),
                    ),
                  ),
                  _ValueRow(
                    label: 'Target',
                    value: data.targetWeightKg == null ? 'Not set' : Formatters.kg(data.targetWeightKg!),
                    onTap: () => _pickInt(
                      title: 'Target',
                      min: 40,
                      max: 180,
                      current: data.targetWeightKg?.round() ?? data.currentWeightKg?.round() ?? 70,
                      suffix: ' kg',
                      onSave: (int kg) => _run(() {
                        return ref.read(profileRepositoryProvider).updateActiveGoal(
                          targetWeightKg: kg.toDouble(),
                        );
                      }),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
                child: Text(
                  'Saving weight adds a new weigh-in. Earlier logs stay on Progress.',
                  style: AppTypography.meta(AppColors.muted(brightness)),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionLabel(text: 'Training', brightness: brightness),
              _InfoGroup(
                children: <Widget>[
                  _ValueRow(
                    label: 'Goal',
                    value: _goalLabel(data.goalType),
                    onTap: () => _pickGoal(data.goalType),
                  ),
                  _ValueRow(
                    label: 'Experience',
                    value: _experienceLabel(profile.trainingExperience),
                    onTap: () => _pickExperience(profile.trainingExperience),
                  ),
                  _ValueRow(
                    label: 'Activity',
                    value: _activityLabel(profile.activityLevel),
                    onTap: () => _pickActivity(profile.activityLevel),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xxl),
                child: Text(
                  'Age, height, weight, and activity update your nutrition targets. Training days and equipment stay in Preferences.',
                  style: AppTypography.meta(AppColors.muted(brightness)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editName(String? current) async {
    final String? next = await showCupertinoModalPopup<String>(
      context: context,
      builder: (BuildContext context) => _NameSheet(initial: current ?? ''),
    );
    final String trimmed = next?.trim() ?? '';
    if (trimmed.isEmpty) {
      return;
    }
    await _run(() {
      return ref.read(profileRepositoryProvider).updateProfileFields(displayName: trimmed);
    });
  }

  Future<void> _pickInt({
    required String title,
    required int min,
    required int max,
    required int current,
    required Future<void> Function(int value) onSave,
    String suffix = '',
  }) async {
    final int? picked = await showIntPicker(
      context: context,
      title: title,
      min: min,
      max: max,
      current: current,
      suffix: suffix,
    );
    if (picked == null) {
      return;
    }
    await onSave(picked);
  }

  Future<void> _pickSex(Sex? current) async {
    final Sex? picked = await AppActionSheet.show<Sex>(
      context: context,
      title: 'Sex',
      actions: Sex.values
          .map(
            (Sex value) => CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, value),
              child: Text(_sexLabel(value)),
            ),
          )
          .toList(),
    );
    if (picked == null || picked == current) {
      return;
    }
    await _run(() {
      return ref.read(profileRepositoryProvider).updateProfileFields(
        sex: picked,
        recalculateNutrition: true,
      );
    });
  }

  Future<void> _pickGoal(GoalType? current) async {
    final GoalType? picked = await AppActionSheet.show<GoalType>(
      context: context,
      title: 'Goal',
      actions: GoalType.values
          .where((GoalType type) => type != GoalType.custom)
          .map(
            (GoalType type) => CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, type),
              child: Text(_goalLabel(type)),
            ),
          )
          .toList(),
    );
    if (picked == null || picked == current) {
      return;
    }
    await _run(() {
      return ref.read(profileRepositoryProvider).updateActiveGoal(goalType: picked);
    });
  }

  Future<void> _pickExperience(TrainingExperience? current) async {
    final TrainingExperience? picked = await AppActionSheet.show<TrainingExperience>(
      context: context,
      title: 'Experience',
      actions: TrainingExperience.values
          .map(
            (TrainingExperience value) => CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, value),
              child: Text(_experienceLabel(value)),
            ),
          )
          .toList(),
    );
    if (picked == null || picked == current) {
      return;
    }
    await _run(() {
      return ref.read(profileRepositoryProvider).updateProfileFields(trainingExperience: picked);
    });
  }

  Future<void> _pickActivity(ActivityLevel? current) async {
    final ActivityLevel? picked = await AppActionSheet.show<ActivityLevel>(
      context: context,
      title: 'Activity',
      actions: ActivityLevel.values
          .map(
            (ActivityLevel value) => CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, value),
              child: Text(_activityLabel(value)),
            ),
          )
          .toList(),
    );
    if (picked == null || picked == current) {
      return;
    }
    await _run(() {
      return ref.read(profileRepositoryProvider).updateProfileFields(
        activityLevel: picked,
        recalculateNutrition: true,
      );
    });
  }
}

class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.initial});

  final String initial;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
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
                onCancel: () => Navigator.pop(context),
                onSave: _handleSave,
              ),
              AppTextField(
                controller: _controller,
                placeholder: 'Name',
                autofocus: true,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.name],
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.brightness});

  final String text;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
      child: Text(text, style: AppTypography.meta(AppColors.muted(brightness))),
    );
  }
}

class _InfoGroup extends StatelessWidget {
  const _InfoGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: ColoredBox(
        color: AppColors.surface(brightness),
        child: Column(
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0)
                Container(
                  height: 0.5,
                  margin: const EdgeInsets.only(left: AppSpacing.md),
                  color: AppColors.hairline(brightness),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return Semantics(
      button: true,
      label: '$label, $value',
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
          onPressed: onTap,
          child: Row(
            children: <Widget>[
              Text(label, style: AppTypography.body(AppColors.ink(brightness))),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: AppTypography.body(AppColors.muted(brightness)),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.muted(brightness)),
            ],
          ),
        ),
      ),
    );
  }
}

String _sexLabel(Sex? value) {
  switch (value) {
    case Sex.male:
      return 'Male';
    case Sex.female:
      return 'Female';
    case Sex.other:
      return 'Other';
    case null:
      return 'Not set';
  }
}

String _goalLabel(GoalType? type) {
  switch (type) {
    case GoalType.loseFat:
      return 'Lose fat';
    case GoalType.buildMuscle:
      return 'Build muscle';
    case GoalType.getStronger:
      return 'Get stronger';
    case GoalType.improveFitness:
      return 'Improve fitness';
    case GoalType.maintainWeight:
      return 'Maintain weight';
    case GoalType.custom:
      return 'Custom goal';
    case null:
      return 'Not set';
  }
}

String _activityLabel(ActivityLevel? level) {
  switch (level) {
    case ActivityLevel.sedentary:
      return 'Mostly sitting';
    case ActivityLevel.lightlyActive:
      return 'Lightly active';
    case ActivityLevel.moderatelyActive:
      return 'Moderately active';
    case ActivityLevel.veryActive:
      return 'Very active';
    case ActivityLevel.extraActive:
      return 'Athlete';
    case null:
      return 'Not set';
  }
}

String _experienceLabel(TrainingExperience? value) {
  switch (value) {
    case TrainingExperience.beginner:
      return 'Beginner';
    case TrainingExperience.intermediate:
      return 'Intermediate';
    case TrainingExperience.advanced:
      return 'Advanced';
    case null:
      return 'Not set';
  }
}
