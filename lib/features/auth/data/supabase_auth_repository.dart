import 'package:fitmate/core/errors/app_exception.dart';
import 'package:fitmate/core/errors/error_mapper.dart';
import 'package:fitmate/core/networking/supabase_provider.dart';
import 'package:fitmate/features/auth/domain/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({GoTrueClient? auth}) : _auth = auth ?? SupabaseProvider.client.auth;

  final GoTrueClient _auth;

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.onAuthStateChange.map((AuthState event) => _map(event.session?.user));
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final String trimmedEmail = email.trim();
    try {
      final AuthResponse result = await _auth.signUp(
        email: trimmedEmail,
        password: password,
        data: displayName == null ? null : <String, dynamic>{'display_name': displayName},
        emailRedirectTo: 'io.fitmate.app://login-callback/',
      );
      if (result.session != null) {
        return;
      }
      final User? created = result.user;
      if (created != null && (created.identities == null || created.identities!.isEmpty)) {
        await _signInExisting(email: trimmedEmail, password: password);
      }
    } on AuthException catch (error) {
      if (_isEmailSignupDisabled(error) || _isAlreadyRegistered(error)) {
        await _signInExisting(
          email: trimmedEmail,
          password: password,
          signupDisabled: _isEmailSignupDisabled(error),
        );
        return;
      }
      throw ErrorMapper.map(error);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<void> _signInExisting({
    required String email,
    required String password,
    bool signupDisabled = false,
  }) async {
    try {
      await _auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (error) {
      if (signupDisabled) {
        throw const AuthFailure(
          'Email sign-up is turned off in Supabase. Turn the Email provider on under Authentication → Sign In / Providers, then try again. If this email already has an account, use Sign in.',
        );
      }
      if (_isInvalidLogin(error)) {
        throw const AuthFailure('An account with this email already exists. Sign in instead.');
      }
      throw ErrorMapper.map(error);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  static bool _isEmailSignupDisabled(AuthException error) {
    final String haystack = '${error.message} ${error.code ?? ''} ${error.statusCode ?? ''}'.toLowerCase();
    return haystack.contains('email signups are disabled') ||
        haystack.contains('email_provider_disabled') ||
        haystack.contains('signups not allowed');
  }

  static bool _isAlreadyRegistered(AuthException error) {
    return error.message.toLowerCase().contains('already registered');
  }

  static bool _isInvalidLogin(AuthException error) {
    return error.message.toLowerCase().contains('invalid login');
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: 'io.fitmate.app://login-callback/',
      );
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  @override
  Future<void> signInWithApple() async {
    throw const AuthFailure('Apple Sign In is not available in this version.');
  }

  @override
  Future<void> signInWithGoogle() async {
    throw const AuthFailure('Google Sign In is not available in this version.');
  }

  AppUser? _map(User? user) {
    if (user == null) {
      return null;
    }
    return AppUser(id: user.id, email: user.email ?? '');
  }
}
