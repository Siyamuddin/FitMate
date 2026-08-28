import 'package:fitmate/core/errors/app_exception.dart';
import 'package:fitmate/core/errors/error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('maps invalid login to a friendly auth error', () {
    final AppException mapped = ErrorMapper.map(
      const AuthException('Invalid login credentials'),
    );
    expect(mapped, isA<AuthFailure>());
    expect(mapped.message, contains('incorrect'));
  });

  test('does not leak stack traces', () {
    final AppException mapped = ErrorMapper.map(Exception('Null check operator used on a null value'));
    expect(mapped.message.toLowerCase().contains('null check'), isFalse);
  });
}
