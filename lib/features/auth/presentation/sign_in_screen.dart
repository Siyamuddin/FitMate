import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitmate/core/errors/app_exception.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/widgets/app_scaffold.dart';
import 'package:fitmate/core/widgets/app_text_field.dart';
import 'package:fitmate/core/widgets/buttons.dart';
import 'package:fitmate/features/auth/presentation/auth_controller.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    await ref.read(authControllerProvider.notifier).signIn(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final AsyncValue<void> auth = ref.watch(authControllerProvider);
    final String? error = auth.hasError ? ErrorMapperMessage.of(auth.error!) : null;

    return AppScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Sign in')),
      child: ListView(
        children: <Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text('Welcome back', style: AppTypography.title(AppColors.ink(brightness))),
          const SizedBox(height: AppSpacing.xl),
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
            autofillHints: const <String>[AutofillHints.password],
            onSubmitted: (_) => _handleSignIn(),
          ),
          const SizedBox(height: AppSpacing.md),
          if (error != null)
            Text(error, style: AppTypography.meta(AppColors.danger)),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: auth.isLoading ? 'Signing in…' : 'Sign in',
            onPressed: auth.isLoading ? null : _handleSignIn,
          ),
          CupertinoButton(
            onPressed: () => context.push('/forgot-password'),
            child: const Text('Forgot password?'),
          ),
        ],
      ),
    );
  }
}

class ErrorMapperMessage {
  static String of(Object error) {
    if (error is AppException) {
      return error.message;
    }
    return 'Could not complete that request.';
  }
}
