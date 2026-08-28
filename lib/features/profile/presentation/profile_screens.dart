import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitmate/core/haptics/app_haptics.dart';
import 'package:fitmate/core/networking/supabase_provider.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/widgets/app_scaffold.dart';
import 'package:fitmate/core/widgets/buttons.dart';
import 'package:fitmate/features/auth/presentation/auth_controller.dart';
import 'package:fitmate/features/onboarding/presentation/onboarding_controller.dart';
import 'package:fitmate/features/progress/presentation/progress_screen.dart';
import 'package:fitmate/services/analytics/analytics_service.dart';
import 'package:fitmate/services/notifications/notification_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return AppScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Profile')),
      child: ListView(
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(profile.value?.displayName ?? 'Athlete', style: AppTypography.title(AppColors.ink(brightness))),
          Text(profile.value?.trainingExperience?.name ?? '', style: AppTypography.meta(AppColors.muted(brightness))),
          const SizedBox(height: AppSpacing.lg),
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
  const _Row({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      onPressed: onTap,
      child: Row(
        children: <Widget>[
          Text(label),
          const Spacer(),
          const Icon(CupertinoIcons.chevron_right, size: 18),
        ],
      ),
    );
  }
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
        child: Text('Training days, diet, and equipment can be updated with your coach.'),
      ),
    );
  }
}

class WeightLogSheet {
  static Future<void> show(BuildContext context, WidgetRef ref) async {
    int kg = (ref.read(progressSnapshotProvider).value?.currentWeight ?? 74).round();
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 280,
          color: AppColors.surface(MediaQuery.platformBrightnessOf(context)),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  CupertinoButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const Spacer(),
                  CupertinoButton(
                    onPressed: () async {
                      await SupabaseProvider.client.from('body_metrics').insert(<String, dynamic>{
                        'user_id': SupabaseProvider.client.auth.currentUser!.id,
                        'weight_kg': kg,
                      });
                      ref.read(analyticsServiceProvider).track('weight_logged');
                      ref.invalidate(progressSnapshotProvider);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: FixedExtentScrollController(initialItem: kg - 40),
                  onSelectedItemChanged: (int index) => kg = 40 + index,
                  children: <Widget>[
                    for (int value = 40; value <= 180; value++) Center(child: Text('$value kg')),
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
