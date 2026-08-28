import 'package:fitmate/core/errors/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorMapper {
  const ErrorMapper._();

  static AppException map(Object error) {
    if (error is AppException) {
      return error;
    }
    if (error is AuthException) {
      return AuthFailure(_authMessage(error.message), code: error.statusCode);
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

  static String _authMessage(String raw) {
    final String lower = raw.toLowerCase();
    if (lower.contains('invalid login')) {
      return 'Email or password is incorrect.';
    }
    if (lower.contains('already registered')) {
      return 'An account with this email already exists.';
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
