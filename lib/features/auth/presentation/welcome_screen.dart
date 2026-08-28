import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/widgets/app_scaffold.dart';
import 'package:fitmate/core/widgets/buttons.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Spacer(),
          Text('FitMate', style: AppTypography.display(AppColors.ink(brightness))),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your plan changes as you change.',
            style: AppTypography.body(AppColors.muted(brightness)),
          ),
          const Spacer(),
          PrimaryButton(
            label: 'Create account',
            onPressed: () => context.push('/sign-up'),
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'Sign in',
            onPressed: () => context.push('/sign-in'),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Apple and Google sign-in will be added later.',
            style: AppTypography.meta(AppColors.muted(brightness)),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
