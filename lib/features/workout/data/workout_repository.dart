import 'package:fitmate/core/errors/error_mapper.dart';
import 'package:fitmate/core/networking/supabase_provider.dart';
import 'package:fitmate/features/workout/data/workout_local_cache.dart';
import 'package:fitmate/features/workout/domain/workout_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkoutRepository {
  WorkoutRepository({
    SupabaseClient? client,
    WorkoutLocalCache? cache,
  })  : _client = client ?? SupabaseProvider.client,
        _cache = cache ?? WorkoutLocalCache();

  final SupabaseClient _client;
  final WorkoutLocalCache _cache;

  Future<WorkoutPlan?> fetchActivePlan() async {
    try {
      final dynamic row = await _client
          .from('workout_plans')
          .select(
            '*, workout_days(*, workout_exercises(*, exercises(*)))',
          )
          .eq('status', 'active')
          .maybeSingle();
      if (row == null) {
        return null;
      }
      return WorkoutPlan.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<String> startSession({required String planId, required String dayId}) async {
    try {
      final Map<String, dynamic> row = await _client.from('workout_sessions').insert(<String, dynamic>{
        'user_id': _client.auth.currentUser!.id,
        'plan_id': planId,
        'day_id': dayId,
        'status': 'in_progress',
      }).select('id').single();
      return row['id'] as String;
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<void> upsertSetLog(String sessionId, SetLog log) async {
    await _cache.save(sessionId, log);
    try {
      await _client.from('workout_set_logs').upsert(log.toJson(sessionId), onConflict: 'session_id,client_id');
      await _cache.markSynced(log.clientId);
    } catch (_) {
      // Keep the local copy; Phase 8 outbox will retry.
    }
  }

  Future<void> completeSession(String sessionId, int durationSeconds) async {
    try {
      await _client.from('workout_sessions').update(<String, dynamic>{
        'status': 'completed',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'duration_seconds': durationSeconds,
      }).eq('id', sessionId);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<List<SetLog>> previousSetLogs(String workoutExerciseId) async {
    try {
      final List<dynamic> rows = await _client
          .from('workout_set_logs')
          .select()
          .eq('workout_exercise_id', workoutExerciseId)
          .eq('completed', true)
          .order('completed_at', ascending: false)
          .limit(12);
      return rows
          .map((dynamic row) {
            final Map<String, dynamic> json = Map<String, dynamic>.from(row as Map);
            return SetLog(
              clientId: json['client_id'] as String? ?? json['id'] as String,
              workoutExerciseId: json['workout_exercise_id'] as String? ?? workoutExerciseId,
              setNumber: json['set_number'] as int,
              weightKg: (json['weight_kg'] as num?)?.toDouble(),
              reps: json['reps'] as int?,
              completed: json['completed'] as bool? ?? true,
            );
          })
          .toList();
    } catch (_) {
      return <SetLog>[];
    }
  }

  Future<List<WorkoutSessionSummary>> history() async {
    try {
      final List<dynamic> rows = await _client
          .from('workout_sessions')
          .select('*, workout_days(name)')
          .eq('status', 'completed')
          .order('started_at', ascending: false)
          .limit(30);
      return rows
          .map((dynamic row) => WorkoutSessionSummary.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<List<Exercise>> allExercises() async {
    final List<dynamic> rows = await _client.from('exercises').select().eq('is_active', true).order('name');
    return rows.map((dynamic row) => Exercise.fromJson(Map<String, dynamic>.from(row as Map))).toList();
  }
}
