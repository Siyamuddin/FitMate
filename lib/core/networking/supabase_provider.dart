import 'package:fitmate/core/networking/app_env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProvider {
  const SupabaseProvider._();

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() {
    return Supabase.initialize(
      url: AppEnv.supabaseUrl,
      publishableKey: AppEnv.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    );
  }
}
