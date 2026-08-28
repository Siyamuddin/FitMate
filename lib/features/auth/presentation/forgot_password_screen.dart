import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/widgets/app_scaffold.dart';
import 'package:fitmate/core/widgets/app_text_field.dart';
import 'package:fitmate/core/widgets/buttons.dart';
import 'package:fitmate/features/auth/presentation/auth_controller.dart';
import 'package:fitmate/features/auth/presentation/sign_in_screen.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final AsyncValue<void> auth = ref.watch(authControllerProvider);
    return AppScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Reset password')),
      child: ListView(
        children: <Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Enter your email and we will send a reset link.',
            style: AppTypography.body(AppColors.muted(brightness)),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _email,
            placeholder: 'Email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (auth.hasError)
            Text(ErrorMapperMessage.of(auth.error!), style: AppTypography.meta(AppColors.danger)),
          if (auth.hasValue && !auth.isLoading)
            Text('If an account exists, a reset email is on the way.', style: AppTypography.meta(AppColors.muted(brightness))),
          PrimaryButton(
            label: auth.isLoading ? 'Sending…' : 'Send reset link',
            onPressed: auth.isLoading
                ? null
                : () => ref.read(authControllerProvider.notifier).sendReset(_email.text),
          ),
        ],
      ),
    );
  }
}
