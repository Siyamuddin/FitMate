import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitmate/core/constants/enums.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_radius.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/widgets/app_scaffold.dart';
import 'package:fitmate/core/widgets/buttons.dart';
import 'package:fitmate/core/widgets/states.dart';
import 'package:fitmate/core/sync/sync_engine.dart';
import 'package:fitmate/features/onboarding/presentation/onboarding_controller.dart';
import 'package:fitmate/services/health/health_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  bool _saving = false;
  String? _error;

  static const int _total = 8;

  Future<void> _handleNext() async {
    if (_step < _total - 1) {
      setState(() => _step += 1);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(onboardingControllerProvider.notifier).submit();
      if (!mounted) {
        return;
      }
      context.go('/generating-plan');
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final draft = ref.watch(onboardingControllerProvider);
    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.md),
          Text('Step ${_step + 1} of $_total', style: AppTypography.meta(AppColors.muted(brightness))),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: LinearProgressIndicatorLike(progress: (_step + 1) / _total, brightness: brightness),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(child: _buildStep(brightness, draft)),
          if (_error != null) Text(_error!, style: AppTypography.meta(AppColors.danger)),
          PrimaryButton(
            label: _saving ? 'Saving…' : (_step == _total - 1 ? 'Generate my plan' : 'Continue'),
            onPressed: _saving ? null : _handleNext,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildStep(Brightness brightness, dynamic draft) {
    switch (_step) {
      case 0:
        return _ChoiceStep(
          title: 'What is your primary goal?',
          options: GoalType.values
              .map((GoalType g) => _Option(label: _goalLabel(g), selected: draft.goalType == g, onTap: () {
                    ref.read(onboardingControllerProvider.notifier).setGoal(g);
                  }))
              .toList(),
        );
      case 1:
        return _BodyStep(
          age: draft.age,
          height: draft.heightCm,
          weight: draft.weightKg,
          target: draft.targetWeightKg,
          onChanged: (int age, double height, double weight, double target) {
            ref.read(onboardingControllerProvider.notifier).setBody(
              age: age,
              heightCm: height,
              weightKg: weight,
              targetWeightKg: target,
            );
          },
        );
      case 2:
        return _ChoiceStep(
          title: 'How active are you?',
          options: ActivityLevel.values
              .map((ActivityLevel level) => _Option(
                    label: _activityLabel(level),
                    selected: draft.activityLevel == level,
                    onTap: () => ref.read(onboardingControllerProvider.notifier).setActivity(level),
                  ))
              .toList(),
        );
      case 3:
        return _ChoiceStep(
          title: 'Where will you train?',
          options: TrainingEnvironment.values
              .map((TrainingEnvironment env) => _Option(
                    label: env.name,
                    selected: draft.environment == env,
                    onTap: () => ref.read(onboardingControllerProvider.notifier).setEnvironment(env),
                  ))
              .toList(),
        );
      case 4:
        return _ChoiceStep(
          title: 'What equipment do you have?',
          options: EquipmentType.values
              .map((EquipmentType item) => _Option(
                    label: item.name,
                    selected: draft.equipment.contains(item),
                    onTap: () => ref.read(onboardingControllerProvider.notifier).toggleEquipment(item),
                  ))
              .toList(),
        );
      case 5:
        return _ChoiceStep(
          title: 'How many days can you train?',
          options: <int>[3, 4, 5, 6]
              .map((int days) => _Option(
                    label: '$days days',
                    selected: draft.daysPerWeek == days,
                    onTap: () => ref.read(onboardingControllerProvider.notifier).setSchedule(days: days),
                  ))
              .toList(),
        );
      case 6:
        return _ChoiceStep(
          title: 'Diet preference',
          options: DietType.values
              .map((DietType diet) => _Option(
                    label: diet.name,
                    selected: draft.dietType == diet,
                    onTap: () => ref.read(onboardingControllerProvider.notifier).setDiet(diet),
                  ))
              .toList(),
        );
      default:
        return _HealthStep(
          onConnect: () async {
            try {
              await ref.read(healthServiceProvider).requestPermissions();
            } catch (_) {}
          },
        );
    }
  }

  String _goalLabel(GoalType type) {
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
    }
  }

  String _activityLabel(ActivityLevel level) {
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
    }
  }
}

class LinearProgressIndicatorLike extends StatelessWidget {
  const LinearProgressIndicatorLike({super.key, required this.progress, required this.brightness});

  final double progress;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      child: ColoredBox(
        color: AppColors.hairline(brightness),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0, 1),
            child: ColoredBox(color: AppColors.accent(brightness)),
          ),
        ),
      ),
    );
  }
}

class _Option {
  const _Option({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
}

class _ChoiceStep extends StatelessWidget {
  const _ChoiceStep({required this.title, required this.options});

  final String title;
  final List<_Option> options;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return ListView(
      children: <Widget>[
        Text(title, style: AppTypography.title(AppColors.ink(brightness))),
        const SizedBox(height: AppSpacing.lg),
        ...options.map((_Option option) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: CupertinoButton(
              padding: const EdgeInsets.all(AppSpacing.md),
              color: option.selected ? AppColors.accent(brightness) : AppColors.surface(brightness),
              borderRadius: BorderRadius.circular(AppRadius.button),
              onPressed: option.onTap,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  option.label,
                  style: AppTypography.headline(
                    option.selected ? CupertinoColors.white : AppColors.ink(brightness),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _BodyStep extends StatelessWidget {
  const _BodyStep({
    required this.age,
    required this.height,
    required this.weight,
    required this.target,
    required this.onChanged,
  });

  final int age;
  final double height;
  final double weight;
  final double target;
  final void Function(int age, double height, double weight, double target) onChanged;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return ListView(
      children: <Widget>[
        Text('Your body', style: AppTypography.title(AppColors.ink(brightness))),
        const SizedBox(height: AppSpacing.md),
        _PickerRow(label: 'Age', value: '$age', onTap: () => _pickInt(context, 'Age', 16, 80, age, (int v) {
          onChanged(v, height, weight, target);
        })),
        _PickerRow(label: 'Height', value: '${height.round()} cm', onTap: () => _pickInt(context, 'Height', 140, 210, height.round(), (int v) {
          onChanged(age, v.toDouble(), weight, target);
        })),
        _PickerRow(label: 'Weight', value: '${weight.toStringAsFixed(1)} kg', onTap: () => _pickInt(context, 'Weight', 40, 180, weight.round(), (int v) {
          onChanged(age, height, v.toDouble(), target);
        })),
        _PickerRow(label: 'Target', value: '${target.toStringAsFixed(1)} kg', onTap: () => _pickInt(context, 'Target', 40, 180, target.round(), (int v) {
          onChanged(age, height, weight, v.toDouble());
        })),
      ],
    );
  }

  Future<void> _pickInt(BuildContext context, String title, int min, int max, int current, ValueChanged<int> onPick) {
    int selected = current;
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 280,
          color: AppColors.surface(MediaQuery.platformBrightnessOf(context)),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 44,
                child: Row(
                  children: <Widget>[
                    CupertinoButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const Spacer(),
                    CupertinoButton(
                      onPressed: () {
                        onPick(selected);
                        Navigator.pop(context);
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: FixedExtentScrollController(initialItem: current - min),
                  onSelectedItemChanged: (int index) => selected = min + index,
                  children: <Widget>[
                    for (int value = min; value <= max; value++) Center(child: Text('$value')),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      onPressed: onTap,
      child: Row(
        children: <Widget>[
          Text(label, style: AppTypography.body(AppColors.ink(brightness))),
          const Spacer(),
          Text(value, style: AppTypography.body(AppColors.accent(brightness))),
        ],
      ),
    );
  }
}

class _HealthStep extends StatelessWidget {
  const _HealthStep({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return ListView(
      children: <Widget>[
        Text('Apple Health is optional', style: AppTypography.title(AppColors.ink(brightness))),
        const SizedBox(height: AppSpacing.md),
        Text(
          'You can connect later in Profile. iOS will ask for permission if you connect now. FitMate cannot turn Health on by itself.',
          style: AppTypography.body(AppColors.muted(brightness)),
        ),
        const SizedBox(height: AppSpacing.lg),
        SecondaryButton(label: 'Connect Apple Health', onPressed: onConnect),
      ],
    );
  }
}

class GeneratingPlanScreen extends ConsumerStatefulWidget {
  const GeneratingPlanScreen({super.key});

  @override
  ConsumerState<GeneratingPlanScreen> createState() => _GeneratingPlanScreenState();
}

class _GeneratingPlanScreenState extends ConsumerState<GeneratingPlanScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_generate);
  }

  Future<void> _generate() async {
    try {
      await ref.read(profileRepositoryProvider).generatePlan();
      await ref.read(syncEngineProvider).sync();
      if (!mounted) {
        return;
      }
      context.go('/plan-ready');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _error = 'We saved your profile. The AI plan can be generated when the coach is available.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return AppScaffold(
        child: EmptyState(
          title: 'Plan pending',
          message: _error!,
          actionLabel: 'Continue',
          onAction: () => context.go('/home'),
        ),
      );
    }
    return const AppScaffold(child: LoadingState(message: 'Building your plan'));
  }
}

class PlanReadyScreen extends StatelessWidget {
  const PlanReadyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Spacer(),
          Text('Your plan is ready', style: AppTypography.display(AppColors.ink(brightness))),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Train, log, and your coach will adapt with you.',
            style: AppTypography.body(AppColors.muted(brightness)),
          ),
          const Spacer(),
          PrimaryButton(label: 'Go to Home', onPressed: () => context.go('/home')),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
