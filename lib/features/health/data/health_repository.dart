import 'package:fitmate/core/networking/supabase_provider.dart';
import 'package:fitmate/features/health/domain/health_models.dart';
import 'package:fitmate/services/health/health_service.dart';

class HealthRepository {
  HealthRepository({HealthService? service}) : _service = service ?? HealthKitHealthService();

  final HealthService _service;

  Future<void> requestPermissions() => _service.requestPermissions();

  Future<HealthSnapshot> today() async {
    final HealthData data = await _service.getTodayData();
    return HealthSnapshot(
      steps: data.steps,
      sleepHours: data.sleepHours,
      activeEnergy: data.activeEnergy,
      connected: data.steps != null,
    );
  }

  Future<void> syncToday() => _service.syncToday();

  Future<bool> isConnected() async {
    final String? userId = SupabaseProvider.client.auth.currentUser?.id;
    if (userId == null) {
      return false;
    }
    final dynamic row = await SupabaseProvider.client
        .from('health_connections')
        .select('connected')
        .eq('provider', 'apple_health')
        .maybeSingle();
    return row != null && (row as Map)['connected'] == true;
  }
}
