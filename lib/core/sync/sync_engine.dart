import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/constants/enums.dart';
import 'package:fitmate/core/local/local_store.dart';
import 'package:fitmate/core/local/outbox_op.dart';
import 'package:fitmate/core/local/snapshot_keys.dart';
import 'package:fitmate/core/networking/edge_functions.dart';
import 'package:fitmate/core/networking/supabase_provider.dart';
import 'package:fitmate/core/sync/sync_status.dart';
import 'package:fitmate/features/nutrition/data/nutrition_repository.dart';
import 'package:fitmate/features/onboarding/domain/profile_models.dart';
import 'package:fitmate/features/progress/domain/progress_snapshot.dart';
import 'package:fitmate/features/workout/domain/workout_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final localStoreProvider = Provider<LocalStore>((Ref ref) {
  return LocalStore();
});

final localEpochProvider = StateProvider<int>((Ref ref) => 0);

bool _localNotifyScheduled = false;
bool _localNotifySync = false;
bool _statusNotifyScheduled = false;
SyncStatus? _pendingStatus;

/// Coalesce store updates onto the next frame so Apply cannot mutate
/// providers while IndexedStack children (Home / Workout) are building.
void notifyLocalChange(Ref ref, {bool sync = true}) {
  if (sync) {
    _localNotifySync = true;
  }
  if (_localNotifyScheduled) {
    return;
  }
  _localNotifyScheduled = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _localNotifyScheduled = false;
    final bool shouldSync = _localNotifySync;
    _localNotifySync = false;
    try {
      ref.read(localEpochProvider.notifier).state++;
      if (shouldSync) {
        unawaited(ref.read(syncEngineProvider).sync());
      }
    } catch (_) {}
  });
}

void _notifySyncStatus(Ref ref, SyncStatus status) {
  _pendingStatus = status;
  if (_statusNotifyScheduled) {
    return;
  }
  _statusNotifyScheduled = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _statusNotifyScheduled = false;
    final SyncStatus? next = _pendingStatus;
    _pendingStatus = null;
    if (next == null) {
      return;
    }
    try {
      ref.read(syncStatusProvider.notifier).set(next);
    } catch (_) {}
  });
}

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => const SyncStatus();

  void set(SyncStatus next) {
    state = next;
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(SyncStatusNotifier.new);

final syncEngineProvider = Provider<SyncEngine>((Ref ref) {
  final SyncEngine engine = SyncEngine(
    store: ref.read(localStoreProvider),
    onChange: () {
      notifyLocalChange(ref, sync: false);
    },
    onStatus: (SyncStatus status) {
      _notifySyncStatus(ref, status);
    },
  );
  ref.onDispose(engine.dispose);
  return engine;
});

class SyncEngine with WidgetsBindingObserver {
  SyncEngine({
    required LocalStore store,
    required VoidCallback onChange,
    required void Function(SyncStatus status) onStatus,
  })  : _store = store,
        _onChange = onChange,
        _onStatus = onStatus;

  final LocalStore _store;
  final VoidCallback _onChange;
  final void Function(SyncStatus status) _onStatus;

  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  bool _running = false;
  bool _queued = false;
  bool _started = false;
  SyncStatus _status = const SyncStatus();

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _connectivity = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final bool online = results.any((ConnectivityResult item) => item != ConnectivityResult.none);
      _setStatus(_status.copyWith(online: online));
      if (online) {
        unawaited(sync());
      }
    });
    final List<ConnectivityResult> current = await Connectivity().checkConnectivity();
    _setStatus(_status.copyWith(
      online: current.any((ConnectivityResult item) => item != ConnectivityResult.none),
    ));
    await sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(sync());
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivity?.cancel();
  }

  Future<void> sync() async {
    if (_running) {
      _queued = true;
      return;
    }
    final String? userId = SupabaseProvider.client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }
    _running = true;
    try {
      do {
        _queued = false;
        await _store.ensureReady();
        if (_status.online) {
          await _push();
          await _pull();
          _setStatus(_status.copyWith(hydrated: true, clearError: true));
        } else {
          await _refreshCounts();
          _setStatus(_status.copyWith(hydrated: true));
        }
        _onChange();
      } while (_queued);
    } catch (error) {
      _setStatus(_status.copyWith(lastError: error.toString()));
    } finally {
      _running = false;
    }
  }

  Future<void> retry() => sync();

  Future<void> clear() async {
    await _store.clear();
    _setStatus(const SyncStatus());
    _onChange();
  }

  Future<void> _push() async {
    final List<OutboxOp> pending = await _store.pending();
    for (final OutboxOp op in pending) {
      try {
        await _pushOp(op);
        await _store.remove(op.id);
      } catch (error) {
        await _store.markError(op.id, error.toString());
        _setStatus(_status.copyWith(lastError: error.toString()));
        await _refreshCounts();
        return;
      }
    }
    await _refreshCounts();
  }

  Future<void> _pushOp(OutboxOp op) async {
    final SupabaseClient client = SupabaseProvider.client;
    final Map<String, dynamic> payload = op.payload;
    switch (op.type) {
      case OutboxType.upsertSetLog:
        await client.from('workout_set_logs').upsert(
          Map<String, dynamic>.from(payload['row'] as Map),
          onConflict: 'session_id,client_id',
        );
        return;
      case OutboxType.upsertSession:
        await client.from('workout_sessions').upsert(payload);
        return;
      case OutboxType.insertDay:
        await client.from('workout_days').upsert(payload);
        return;
      case OutboxType.updateDay:
        await client.from('workout_days').update(Map<String, dynamic>.from(payload['patch'] as Map)).eq('id', payload['id']);
        return;
      case OutboxType.deleteDay:
        await client.from('workout_days').delete().eq('id', payload['id']);
        return;
      case OutboxType.insertExercise:
        await client.from('workout_exercises').upsert(payload);
        return;
      case OutboxType.updateExercise:
        await client.from('workout_exercises').update(Map<String, dynamic>.from(payload['patch'] as Map)).eq('id', payload['id']);
        return;
      case OutboxType.deleteExercise:
        await client.from('workout_exercises').delete().eq('id', payload['id']);
        return;
      case OutboxType.replaceSets:
        final String workoutExerciseId = payload['workout_exercise_id'] as String;
        await client.from('workout_sets').delete().eq('workout_exercise_id', workoutExerciseId);
        final List<dynamic> rows = payload['rows'] as List<dynamic>? ?? <dynamic>[];
        if (rows.isNotEmpty) {
          await client.from('workout_sets').insert(rows);
        }
        return;
      case OutboxType.updatePlan:
        await client.from('workout_plans').update(Map<String, dynamic>.from(payload['patch'] as Map)).eq('id', payload['id']);
        return;
      case OutboxType.updatePreferences:
        await client.from('user_preferences').update(Map<String, dynamic>.from(payload['patch'] as Map)).eq('user_id', payload['user_id']);
        return;
      case OutboxType.upsertCustomExercise:
        await client.from('exercises').upsert(payload);
        return;
      case OutboxType.insertFoodLog:
        await client.from('food_logs').upsert(payload);
        return;
      case OutboxType.deleteFoodLog:
        await client.from('food_logs').delete().eq('id', payload['id']);
        return;
      case OutboxType.updateProfile:
        await client.from('profiles').update(Map<String, dynamic>.from(payload['patch'] as Map)).eq('user_id', payload['user_id']);
        return;
      case OutboxType.insertBodyMetric:
        await client.from('body_metrics').upsert(payload);
        return;
      case OutboxType.upsertGoal:
        final Map<String, dynamic> row = Map<String, dynamic>.from(payload['row'] as Map);
        await client.from('fitness_goals').update(<String, dynamic>{'is_active': false}).eq('user_id', row['user_id']);
        await client.from('fitness_goals').upsert(row);
        return;
      case OutboxType.upsertNutritionTargets:
        await client.from('nutrition_targets').upsert(payload, onConflict: 'user_id');
        return;
      case OutboxType.ackAiActions:
        await EdgeFunctions.invoke('apply-ai-action', body: payload);
        return;
      default:
        throw StateError('Unknown outbox type ${op.type}');
    }
  }

  Future<void> _pull() async {
    final SupabaseClient client = SupabaseProvider.client;
    final bool profileDirty = await _store.isDirty(SnapshotKeys.profile) ||
        await _store.isDirty(SnapshotKeys.personalDetails) ||
        await _store.isDirty(SnapshotKeys.progress);
    if (!profileDirty) {
      await _pullProfile(client);
      await _pullProgress(client);
    }
    if (!await _store.isDirty(SnapshotKeys.activePlan)) {
      await _pullPlan(client);
    }
    if (!await _store.isDirty(SnapshotKeys.exerciseCatalog)) {
      await _pullCatalog(client);
    }
    if (!await _store.isDirty(SnapshotKeys.workoutHistory) && !await _store.isDirty(SnapshotKeys.sessions)) {
      await _pullHistory(client);
    }
    if (!await _store.isDirty(SnapshotKeys.setLogs)) {
      await _pullSetLogs(client);
    }
    if (!await _store.isDirty(SnapshotKeys.todayNutrition) &&
        !await _store.isDirty(SnapshotKeys.foodLogsToday) &&
        !await _store.isDirty(SnapshotKeys.nutritionTargets)) {
      await _pullNutrition(client);
    }
    if (!await _store.isDirty(SnapshotKeys.foodsCache)) {
      await _pullFoods(client);
    }
    if (!await _store.isDirty(SnapshotKeys.coachMessages)) {
      await _pullCoach(client);
    }
  }

  Future<void> _pullProfile(SupabaseClient client) async {
    final String? userId = client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }
    final dynamic row = await client.from('profiles').select().eq('user_id', userId).maybeSingle();
    if (row == null) {
      return;
    }
    final Profile profile = Profile.fromJson(Map<String, dynamic>.from(row as Map));
    await _store.setJson(SnapshotKeys.profile, profile.toJson());
    final dynamic metric = await client
        .from('body_metrics')
        .select('weight_kg')
        .eq('user_id', userId)
        .order('recorded_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final dynamic goal = await client
        .from('fitness_goals')
        .select('goal_type, target_weight_kg')
        .eq('user_id', userId)
        .eq('is_active', true)
        .maybeSingle();
    await _store.setJson(
      SnapshotKeys.personalDetails,
      PersonalDetails(
        profile: profile,
        currentWeightKg: metric == null ? null : (Map<String, dynamic>.from(metric as Map)['weight_kg'] as num?)?.toDouble(),
        targetWeightKg: goal == null ? null : (Map<String, dynamic>.from(goal as Map)['target_weight_kg'] as num?)?.toDouble(),
        goalType: goal == null
            ? null
            : enumFromValue(
                goalTypeValues,
                Map<String, dynamic>.from(goal as Map)['goal_type'] as String?,
                GoalType.maintainWeight,
              ),
      ).toJson(),
    );
  }

  Future<void> _pullPlan(SupabaseClient client) async {
    final dynamic row = await client
        .from('workout_plans')
        .select('*, workout_days(*, workout_exercises(*, exercises(*)))')
        .eq('status', 'active')
        .maybeSingle();
    if (row == null) {
      await _store.deleteSnapshot(SnapshotKeys.activePlan);
      return;
    }
    await _store.setJson(SnapshotKeys.activePlan, WorkoutPlan.fromJson(Map<String, dynamic>.from(row as Map)).toJson());
  }

  Future<void> _pullCatalog(SupabaseClient client) async {
    final List<dynamic> rows = await client.from('exercises').select().eq('is_active', true).order('name');
    await _store.setList(
      SnapshotKeys.exerciseCatalog,
      rows.map((dynamic row) => Exercise.fromJson(Map<String, dynamic>.from(row as Map)).toJson()).toList(),
    );
  }

  Future<void> _pullHistory(SupabaseClient client) async {
    final List<dynamic> rows = await client
        .from('workout_sessions')
        .select('*, workout_days(name)')
        .order('started_at', ascending: false)
        .limit(30);
    final List<Map<String, dynamic>> sessions = rows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList();
    await _store.replaceSessions(sessions);
    await _store.setList(
      SnapshotKeys.workoutHistory,
      sessions
          .where((Map<String, dynamic> row) => row['status'] == 'completed')
          .map((Map<String, dynamic> row) => WorkoutSessionSummary.fromJson(row).toJson())
          .toList(),
    );
  }

  Future<void> _pullSetLogs(SupabaseClient client) async {
    final List<dynamic> rows = await client
        .from('workout_set_logs')
        .select()
        .eq('completed', true)
        .order('completed_at', ascending: false)
        .limit(200);
    await _store.replaceSetLogs(
      rows.map((dynamic row) => Map<String, dynamic>.from(row as Map)).toList(),
    );
  }

  Future<void> _pullNutrition(SupabaseClient client) async {
    final DateTime now = DateTime.now().toUtc();
    final String date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final dynamic row = await client.from('nutrition_daily_logs').select().eq('log_date', date).maybeSingle();
    final dynamic targets = await client.from('nutrition_targets').select().maybeSingle();
    if (targets != null) {
      await _store.setJson(SnapshotKeys.nutritionTargets, Map<String, dynamic>.from(targets as Map));
    }
    final Map<String, dynamic>? targetMap = targets == null ? null : Map<String, dynamic>.from(targets as Map);
    if (row == null) {
      await _store.setJson(
        SnapshotKeys.todayNutrition,
        DailyNutrition(
          calories: 0,
          protein: 0,
          carbohydrates: 0,
          fat: 0,
          calorieTarget: targetMap?['calories'] as int?,
          proteinTarget: (targetMap?['protein_g'] as num?)?.toDouble(),
        ).toJson(),
      );
    } else {
      final Map<String, dynamic> json = Map<String, dynamic>.from(row as Map);
      await _store.setJson(
        SnapshotKeys.todayNutrition,
        DailyNutrition(
          calories: (json['calories'] as num?)?.toDouble() ?? 0,
          protein: (json['protein'] as num?)?.toDouble() ?? 0,
          carbohydrates: (json['carbohydrates'] as num?)?.toDouble() ?? 0,
          fat: (json['fat'] as num?)?.toDouble() ?? 0,
          calorieTarget: json['calorie_target'] as int? ?? targetMap?['calories'] as int?,
          proteinTarget: (json['protein_target'] as num?)?.toDouble() ?? (targetMap?['protein_g'] as num?)?.toDouble(),
        ).toJson(),
      );
    }
    final DateTime start = DateTime.utc(now.year, now.month, now.day);
    final List<dynamic> logs = await client
        .from('food_logs')
        .select('id, quantity, calories, protein, meal_slot, foods(name)')
        .gte('logged_at', start.toIso8601String())
        .order('logged_at');
    await _store.setList(
      SnapshotKeys.foodLogsToday,
      logs.map((dynamic item) => FoodLog.fromJson(Map<String, dynamic>.from(item as Map)).toJson()).toList(),
    );
  }

  Future<void> _pullFoods(SupabaseClient client) async {
    final List<dynamic> rows = await client.from('foods').select().eq('is_active', true).order('name').limit(500);
    await _store.setList(
      SnapshotKeys.foodsCache,
      rows.map((dynamic row) => Food.fromJson(Map<String, dynamic>.from(row as Map)).toJson()).toList(),
    );
  }

  Future<void> _pullProgress(SupabaseClient client) async {
    final List<dynamic> metrics = await client
        .from('body_metrics')
        .select('weight_kg, recorded_at')
        .order('recorded_at')
        .limit(30);
    final List<double> weights = metrics
        .map((dynamic row) => ((row as Map)['weight_kg'] as num).toDouble())
        .toList();
    final dynamic goal = await client.from('fitness_goals').select('target_weight_kg').eq('is_active', true).maybeSingle();
    final DateTime weekAgo = DateTime.now().toUtc().subtract(const Duration(days: 7));
    final List<dynamic> sessions = await client
        .from('workout_sessions')
        .select('id')
        .eq('status', 'completed')
        .gte('started_at', weekAgo.toIso8601String());
    int planned = 4;
    final Map<String, dynamic>? planJson = await _store.getJson(SnapshotKeys.activePlan);
    if (planJson != null) {
      planned = WorkoutPlan.fromJson(planJson).days.length;
    }
    await _store.setJson(
      SnapshotKeys.progress,
      ProgressSnapshot(
        weights: weights,
        currentWeight: weights.isEmpty ? null : weights.last,
        targetWeight: goal == null ? null : ((goal as Map)['target_weight_kg'] as num?)?.toDouble(),
        workoutsThisWeek: sessions.length,
        workoutsPlanned: planned,
      ).toJson(),
    );
  }

  Future<void> _pullCoach(SupabaseClient client) async {
    final List<dynamic> rows = await client
        .from('ai_messages')
        .select('role, content, conversation_id, created_at, ai_conversations!inner(user_id)')
        .order('created_at')
        .limit(20);
    final List<Map<String, dynamic>> local = (await _store.getList(SnapshotKeys.coachMessages) ?? <dynamic>[])
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
    final Map<String, Map<String, dynamic>> flags = <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> item in local) {
      final String key = _actionKey(item['actions']);
      if (key.isNotEmpty) {
        flags[key] = item;
      }
    }
    final List<Map<String, dynamic>> merged = rows.map((dynamic row) {
      final Map<String, dynamic> json = Map<String, dynamic>.from(row as Map);
      final dynamic content = json['content'];
      Map<String, dynamic> map = <String, dynamic>{};
      List<dynamic> actions = <dynamic>[];
      String text = '';
      bool requiresConfirmation = false;
      bool applied = false;
      bool dismissed = false;
      if (content is Map) {
        map = Map<String, dynamic>.from(content);
        actions = map['actions'] as List<dynamic>? ?? <dynamic>[];
        text = map['message'] as String? ?? content.toString();
        requiresConfirmation = map['requires_confirmation'] == true && actions.isNotEmpty;
        applied = map['applied'] == true;
        dismissed = map['dismissed'] == true;
      } else {
        text = content.toString();
      }
      final String key = _actionKey(actions);
      final Map<String, dynamic>? overlay = flags[key];
      if (overlay != null) {
        applied = overlay['applied'] == true || applied;
        dismissed = overlay['dismissed'] == true || dismissed;
      }
      return <String, dynamic>{
        'role': json['role'],
        'text': text,
        'actions': actions,
        'requires_confirmation': requiresConfirmation,
        'applied': applied,
        'dismissed': dismissed,
      };
    }).toList();
    await _store.setList(SnapshotKeys.coachMessages, merged);
  }

  String _actionKey(Object? actions) {
    if (actions is! List || actions.isEmpty) {
      return '';
    }
    return actions.toString();
  }

  Future<void> _refreshCounts() async {
    _setStatus(
      _status.copyWith(
        pendingCount: await _store.pendingCount(),
        oldestPendingAt: await _store.oldestPendingAt(),
      ),
    );
  }

  void _setStatus(SyncStatus next) {
    _status = next;
    _onStatus(next);
  }
}
