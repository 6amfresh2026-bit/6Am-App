/// The only error type that crosses into Domain and UI.
sealed class Failure {
  const Failure(this.message);

  final String message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'The request took too long.']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Please sign in again.']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'We could not find that.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Our servers are having a moment.']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong.']);
}
