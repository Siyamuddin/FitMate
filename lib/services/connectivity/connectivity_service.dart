import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/networking/supabase_provider.dart';
import 'package:fitmate/features/workout/data/workout_local_cache.dart';

class ConnectivityService {
  ConnectivityService({WorkoutLocalCache? cache}) : _cache = cache ?? WorkoutLocalCache();

  final WorkoutLocalCache _cache;

  Stream<List<ConnectivityResult>> get changes => Connectivity().onConnectivityChanged;

  Future<void> flushOutbox() async {
    final List<Map<String, dynamic>> pending = await _cache.pending();
    for (final Map<String, dynamic> payload in pending) {
      try {
        await SupabaseProvider.client.from('workout_set_logs').upsert(
          payload,
          onConflict: 'session_id,client_id',
        );
        await _cache.markSynced(payload['client_id'] as String);
      } catch (_) {
        return;
      }
    }
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>((Ref ref) {
  return ConnectivityService();
});
