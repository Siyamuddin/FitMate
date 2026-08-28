import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/networking/supabase_provider.dart';

class AnalyticsService {
  const AnalyticsService();

  Future<void> track(String eventName, [Map<String, dynamic>? properties]) async {
    final String? userId = SupabaseProvider.client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }
    try {
      await SupabaseProvider.client.from('analytics_events').insert(<String, dynamic>{
        'user_id': userId,
        'event_name': eventName,
        'properties': properties ?? <String, dynamic>{},
      });
    } catch (_) {
      // Analytics must never break the product.
    }
  }
}

final analyticsServiceProvider = Provider<AnalyticsService>((Ref ref) {
  return const AnalyticsService();
});
