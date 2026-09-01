import 'package:fitmate/core/errors/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorMapper {
  const ErrorMapper._();

  static AppException map(Object error) {
    if (error is AppException) {
      return error;
    }
    if (error is AuthException) {
      final String lower = error.message.toLowerCase();
      if (error.statusCode == '429' || lower.contains('rate limit')) {
        return AuthFailure(
          'Too many sign-up emails were sent. Wait a minute, then Sign in if the account already exists.',
          code: error.statusCode,
        );
      }
      return AuthFailure(_authMessage(error.message, error.code), code: error.statusCode);
    }
    if (error is FunctionException) {
      if (error.status == 429) {
        return const RateLimitFailure();
      }
      return AppException(_friendly(error.reasonPhrase) ?? 'Something went wrong. Try again.');
    }
    if (error is PostgrestException) {
      return AppException(_friendly(error.message) ?? 'Could not save your data.');
    }
    return const NetworkFailure();
  }

  static String _authMessage(String raw, String? code) {
    final String lower = '${raw.toLowerCase()} ${code ?? ''}'.toLowerCase();
    if (lower.contains('email signups are disabled') ||
        lower.contains('email_provider_disabled') ||
        lower.contains('signups not allowed')) {
      return 'Email sign-up is turned off in Supabase. Enable the Email provider under Authentication → Sign In / Providers. If you already created this email, use Sign in.';
    }
    if (lower.contains('invalid login')) {
      return 'Email or password is incorrect.';
    }
    if (lower.contains('already registered')) {
      return 'An account with this email already exists. Sign in instead.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Check your email to confirm your account.';
    }
    if (lower.contains('password')) {
      return 'Use a stronger password with at least 8 characters.';
    }
    return 'Could not complete sign in. Try again.';
  }

  static String? _friendly(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    if (raw.contains('stack') || raw.contains('Exception')) {
      return 'Something went wrong. Try again.';
    }
    return raw;
  }
}
