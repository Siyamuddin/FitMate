import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.email,
  });

  final String id;
  final String email;

  @override
  List<Object?> get props => <Object?>[id, email];
}

abstract class AuthRepository {
  AppUser? get currentUser;
  Stream<AppUser?> authStateChanges();
  Future<void> signIn({required String email, required String password});
  Future<void> signUp({required String email, required String password, String? displayName});
  Future<void> sendPasswordReset({required String email});
  Future<void> signOut();
  Future<void> signInWithApple();
  Future<void> signInWithGoogle();
}
