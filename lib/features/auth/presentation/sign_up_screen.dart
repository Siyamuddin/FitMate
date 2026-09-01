import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/widgets/app_scaffold.dart';
import 'package:fitmate/core/widgets/app_text_field.dart';
import 'package:fitmate/core/widgets/buttons.dart';
import 'package:fitmate/features/auth/presentation/auth_controller.dart';
import 'package:fitmate/features/auth/presentation/sign_in_screen.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    await ref.read(authControllerProvider.notifier).signUp(
      _email.text,
      _password.text,
      _name.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final AsyncValue<void> auth = ref.watch(authControllerProvider);
    final String? error = auth.hasError ? ErrorMapperMessage.of(auth.error!) : null;

    return AppScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Create account')),
      child: ListView(
        children: <Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text('Start training with a plan that adapts.', style: AppTypography.title(AppColors.ink(brightness))),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(controller: _name, placeholder: 'Name', autofillHints: const <String>[AutofillHints.name]),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _email,
            placeholder: 'Email',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const <String>[AutofillHints.email],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _password,
            placeholder: 'Password',
            obscureText: true,
            autofillHints: const <String>[AutofillHints.newPassword],
          ),
          const SizedBox(height: AppSpacing.md),
          if (error != null) Text(error, style: AppTypography.meta(AppColors.danger)),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: auth.isLoading ? 'Creating account…' : 'Create account',
            onPressed: auth.isLoading ? null : _handleSignUp,
          ),
          CupertinoButton(
            onPressed: () => context.go('/sign-in'),
            child: const Text('Already have an account? Sign in'),
          ),
        ],
      ),
    );
  }
}
