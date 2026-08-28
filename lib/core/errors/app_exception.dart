class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class AuthFailure extends AppException {
  const AuthFailure(super.message, {super.code});
}

class NetworkFailure extends AppException {
  const NetworkFailure([super.message = 'Check your connection and try again.']);
}

class RateLimitFailure extends AppException {
  const RateLimitFailure([
    super.message = 'You have reached today\'s coaching limit. Try again tomorrow.',
  ]);
}
