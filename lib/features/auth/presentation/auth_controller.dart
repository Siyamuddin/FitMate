import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/sync/sync_engine.dart';
import 'package:fitmate/features/auth/data/supabase_auth_repository.dart';
import 'package:fitmate/features/auth/domain/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((Ref ref) {
  return SupabaseAuthRepository();
});

final authStateProvider = StreamProvider<AppUser?>((Ref ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

class AuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(authRepositoryProvider).signIn(email: email, password: password);
    });
  }

  Future<void> signUp(String email, String password, String displayName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(authRepositoryProvider).signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
    });
  }

  Future<void> sendReset(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(authRepositoryProvider).sendPasswordReset(email: email);
    });
  }

  Future<void> signOut() async {
    await ref.read(syncEngineProvider).clear();
    await ref.read(authRepositoryProvider).signOut();
  }
}

final authControllerProvider = AsyncNotifierProvider.autoDispose<AuthController, void>(
  AuthController.new,
);
