import 'dart:async';

import 'package:fitmate/core/errors/app_exception.dart';
import 'package:fitmate/core/local/local_store.dart';
import 'package:fitmate/core/local/outbox_op.dart';
import 'package:fitmate/core/sync/sync_engine.dart';
import 'package:fitmate/features/auth/domain/auth_repository.dart';
import 'package:fitmate/features/health/data/health_repository.dart';
import 'package:fitmate/features/nutrition/data/nutrition_repository.dart';
import 'package:fitmate/features/onboarding/data/profile_repository.dart';
import 'package:fitmate/features/workout/data/workout_repository.dart';
import 'package:fitmate/services/analytics/analytics_service.dart';
import 'package:fitmate/services/health/health_service.dart';
import 'package:mocktail/mocktail.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? user}) : _user = user;

  AppUser? _user;
  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw const AuthFailure('Enter your email and password.');
    }
    _user = AppUser(id: 'user-1', email: email.trim());
    _controller.add(_user);
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw const AuthFailure('Enter your email and password.');
    }
    _user = AppUser(id: 'user-1', email: email.trim());
    _controller.add(_user);
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    if (email.trim().isEmpty) {
      throw const AuthFailure('Enter your email.');
    }
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> signInWithApple() async {}

  @override
  Future<void> signInWithGoogle() async {}

  Future<void> dispose() => _controller.close();
}

class FakeLocalStore extends LocalStore {
  final Map<String, Map<String, dynamic>> _json =
      <String, Map<String, dynamic>>{};
  final Map<String, List<dynamic>> _lists = <String, List<dynamic>>{};
  final List<OutboxOp> _outbox = <OutboxOp>[];
  final Map<String, Map<String, dynamic>> _sessions =
      <String, Map<String, dynamic>>{};
  final List<Map<String, dynamic>> _setLogs = <Map<String, dynamic>>[];
  int _op = 0;

  @override
  Future<void> ensureReady() async {}

  @override
  Future<Map<String, dynamic>?> getJson(String key) async => _json[key];

  @override
  Future<List<dynamic>?> getList(String key) async => _lists[key];

  @override
  Future<void> setJson(String key, Map<String, dynamic>? value) async {
    if (value == null) {
      _json.remove(key);
      return;
    }
    _json[key] = value;
  }

  @override
  Future<void> setList(String key, List<dynamic> value) async {
    _lists[key] = List<dynamic>.from(value);
  }

  @override
  Future<void> deleteSnapshot(String key) async {
    _json.remove(key);
    _lists.remove(key);
  }

  @override
  Future<String> enqueue({
    required String type,
    required String entity,
    required Map<String, dynamic> payload,
    String? id,
  }) async {
    final String opId = id ?? 'op-${_op++}';
    _outbox.add(
      OutboxOp(
        id: opId,
        type: type,
        entity: entity,
        payload: payload,
        createdAt: DateTime.now(),
      ),
    );
    return opId;
  }

  @override
  Future<List<OutboxOp>> pending() async => List<OutboxOp>.from(_outbox);

  @override
  Future<int> pendingCount() async => _outbox.length;

  @override
  Future<DateTime?> oldestPendingAt() async {
    if (_outbox.isEmpty) {
      return null;
    }
    return _outbox.first.createdAt;
  }

  @override
  Future<bool> isDirty(String entity) async {
    return _outbox.any((OutboxOp op) => op.entity == entity);
  }

  @override
  Future<void> remove(String id) async {
    _outbox.removeWhere((OutboxOp op) => op.id == id);
  }

  @override
  Future<void> markError(String id, String error) async {}

  @override
  Future<void> saveSetLog(String sessionId, Map<String, dynamic> row) async {
    _setLogs.add(row);
  }

  @override
  Future<List<Map<String, dynamic>>> setLogsForExercise(
    String workoutExerciseId,
  ) async {
    return _setLogs
        .where(
          (Map<String, dynamic> row) =>
              row['workout_exercise_id'] == workoutExerciseId,
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> sessionById(String id) async => _sessions[id];

  @override
  Future<void> saveSession(Map<String, dynamic> row) async {
    _sessions[row['id'] as String] = row;
  }

  @override
  Future<List<Map<String, dynamic>>> completedSessions({int limit = 30}) async {
    return _sessions.values
        .where((Map<String, dynamic> row) => row['status'] == 'completed')
        .take(limit)
        .toList();
  }

  @override
  Future<void> replaceSetLogs(List<Map<String, dynamic>> rows) async {
    _setLogs
      ..clear()
      ..addAll(rows);
  }

  @override
  Future<void> replaceSessions(List<Map<String, dynamic>> rows) async {
    _sessions
      ..clear()
      ..addEntries(
        rows.map(
          (Map<String, dynamic> row) =>
              MapEntry<String, Map<String, dynamic>>(row['id'] as String, row),
        ),
      );
  }

  @override
  Future<void> clear() async {
    _json.clear();
    _lists.clear();
    _outbox.clear();
    _sessions.clear();
    _setLogs.clear();
  }
}

class FakeSyncEngine extends SyncEngine {
  FakeSyncEngine({LocalStore? store})
    : super(
        store: store ?? FakeLocalStore(),
        onChange: () {},
        onStatus: (_) {},
      );

  @override
  Future<void> start() async {}

  @override
  Future<void> sync() async {}

  @override
  Future<void> retry() async {}

  @override
  Future<void> clear() async {}

  @override
  void dispose() {}
}

class SilentAnalytics extends AnalyticsService {
  const SilentAnalytics();

  @override
  Future<void> track(
    String eventName, [
    Map<String, dynamic>? properties,
  ]) async {}
}

class FakeHealthRepository extends HealthRepository {
  FakeHealthRepository({this.connected = false})
    : super(service: StubHealthService());

  final bool connected;

  @override
  Future<bool> isConnected() async => connected;
}

class MockWorkoutRepository extends Mock implements WorkoutRepository {
  @override
  Future<T> transact<T>(Future<T> Function() body) => body();
}

class MockProfileRepository extends Mock implements ProfileRepository {
  @override
  Future<T> transact<T>(Future<T> Function() body) => body();
}

class MockNutritionRepository extends Mock implements NutritionRepository {}
