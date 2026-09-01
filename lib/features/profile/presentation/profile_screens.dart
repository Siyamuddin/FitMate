import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitmate/core/haptics/app_haptics.dart';
import 'package:fitmate/core/sync/sync_engine.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/utils/formatters.dart';
import 'package:fitmate/core/widgets/app_scaffold.dart';
import 'package:fitmate/core/widgets/buttons.dart';
import 'package:fitmate/features/auth/presentation/auth_controller.dart';
import 'package:fitmate/features/onboarding/domain/profile_models.dart';
import 'package:fitmate/features/onboarding/presentation/onboarding_controller.dart';
import 'package:fitmate/features/progress/presentation/progress_screen.dart';
import 'package:fitmate/services/notifications/notification_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final details = ref.watch(personalDetailsProvider);
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final String name = profile.value?.displayName ?? 'Athlete';
    final String experience = _experienceSummary(profile.value?.trainingExperience?.name);
    final String personalSummary = _personalSummary(details.value);
    return AppScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Profile'),
        trailing: ref.watch(syncStatusProvider).showNotSynced
            ? Semantics(
                button: true,
                label: 'Not synced. Retry.',
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => ref.read(syncEngineProvider).retry(),
                  child: Text('Not synced', style: AppTypography.meta(AppColors.danger)),
                ),
              )
            : null,
      ),
      child: ListView(
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(name, style: AppTypography.title(AppColors.ink(brightness))),
          if (experience.isNotEmpty)
            Text(experience, style: AppTypography.meta(AppColors.muted(brightness))),
          const SizedBox(height: AppSpacing.lg),
          _Row(
            label: 'Personal Info',
            value: personalSummary,
            onTap: () => context.push('/personal-info'),
          ),
          _Row(label: 'Settings', onTap: () => context.push('/settings')),
          _Row(label: 'Health', onTap: () => context.push('/health')),
          _Row(label: 'Preferences', onTap: () => context.push('/preferences')),
          const SizedBox(height: AppSpacing.xl),
          SecondaryButton(
            label: 'Sign out',
            onPressed: () async {
              final bool? confirmed = await showCupertinoDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return CupertinoAlertDialog(
                    title: const Text('Sign out?'),
                    actions: <Widget>[
                      CupertinoDialogAction(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      CupertinoDialogAction(
                        isDestructiveAction: true,
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign out'),
                      ),
                    ],
                  );
                },
              );
              if (confirmed == true) {
                await ref.read(authControllerProvider.notifier).signOut();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.onTap, this.value});
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return Semantics(
      button: true,
      label: value == null || value!.isEmpty ? label : '$label, $value',
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        onPressed: onTap,
        child: Row(
          children: <Widget>[
            Text(label, style: AppTypography.body(AppColors.ink(brightness))),
            if (value != null && value!.isNotEmpty) ...<Widget>[
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  value!,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(AppColors.muted(brightness)),
                ),
              ),
            ] else
              const Spacer(),
            const SizedBox(width: AppSpacing.xs),
            Icon(CupertinoIcons.chevron_right, size: 18, color: AppColors.muted(brightness)),
          ],
        ),
      ),
    );
  }
}

String _experienceSummary(String? raw) {
  if (raw == null || raw.isEmpty) {
    return '';
  }
  return '${raw[0].toUpperCase()}${raw.substring(1)}';
}

String _personalSummary(PersonalDetails? details) {
  if (details == null) {
    return '';
  }
  final List<String> parts = <String>[
    if (details.profile.age != null) '${details.profile.age}',
    if (details.profile.heightCm != null) '${details.profile.heightCm!.round()} cm',
    if (details.currentWeightKg != null) Formatters.kg(details.currentWeightKg!),
  ];
  return parts.join(' · ');
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Settings')),
      child: ListView(
        children: <Widget>[
          _Toggle(
            label: 'Workout reminders',
            onChanged: (bool value) {
              AppHaptics.toggle();
              ref.read(notificationServiceProvider).setWorkoutReminders(value);
            },
          ),
          _Toggle(
            label: 'Meal reminders',
            onChanged: (bool value) {
              AppHaptics.toggle();
              ref.read(notificationServiceProvider).setMealReminders(value);
            },
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatefulWidget {
  const _Toggle({required this.label, required this.onChanged});
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  State<_Toggle> createState() => _ToggleState();
}

class _ToggleState extends State<_Toggle> {
  bool _value = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(widget.label)),
        CupertinoSwitch(
          value: _value,
          onChanged: (bool value) {
            setState(() => _value = value);
            widget.onChanged(value);
          },
        ),
      ],
    );
  }
}

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('Preferences')),
      child: Padding(
        padding: EdgeInsets.only(top: AppSpacing.lg),
        child: Text('Change training days on the Workout tab. Diet and equipment can also be updated with your coach.'),
      ),
    );
  }
}

class WeightLogSheet {
  static Future<void> show(BuildContext context, WidgetRef ref) {
    return logWeightFromPicker(context, ref, ref.read(progressSnapshotProvider).value?.currentWeight);
  }
}
