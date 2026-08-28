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
    try {
      await _auth.signUp(
        email: email.trim(),
        password: password,
        data: displayName == null ? null : <String, dynamic>{'display_name': displayName},
        emailRedirectTo: 'io.fitmate.app://login-callback/',
      );
    } catch (error) {
      throw ErrorMapper.map(error);
    }
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
