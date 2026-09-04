import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/errors/app_exception.dart';
import 'package:fitmate/core/networking/supabase_provider.dart';

typedef EdgeFunctionInvoker = Future<Map<String, dynamic>> Function(
  String name, {
  Map<String, dynamic>? body,
});

final edgeFunctionsProvider = Provider<EdgeFunctionInvoker>((Ref ref) {
  return EdgeFunctions.invoke;
});

class EdgeFunctions {
  const EdgeFunctions._();

  static Future<Map<String, dynamic>> invoke(
    String name, {
    Map<String, dynamic>? body,
  }) async {
    final response = await SupabaseProvider.client.functions.invoke(
      name,
      body: body ?? <String, dynamic>{},
    );
    if (response.status == 429) {
      throw const RateLimitFailure();
    }
    if (response.status >= 400) {
      final dynamic data = response.data;
      if (data is Map && data['error'] != null) {
        throw AppException(data['error'].toString(), code: '${response.status}');
      }
      throw AppException(
        'Could not complete that request.',
        code: '${response.status}',
      );
    }
    final dynamic data = response.data;
    if (data is Map && data['error'] != null) {
      throw AppException(data['error'].toString());
    }
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{'data': data};
  }
}
