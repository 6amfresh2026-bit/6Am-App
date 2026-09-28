/// Thrown by the data layer only. Never surfaced to the UI verbatim.
sealed class AppException implements Exception {
  const AppException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => '$runtimeType($statusCode): $message';
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}

class TimeoutException extends AppException {
  const TimeoutException(super.message);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message) : super(statusCode: 401);
}

class NotFoundException extends AppException {
  const NotFoundException(super.message) : super(statusCode: 404);
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.statusCode});
}

class ServerException extends AppException {
  const ServerException(super.message, {super.statusCode});
}

class ParseException extends AppException {
  const ParseException(super.message);
}

class UnknownException extends AppException {
  const UnknownException(super.message, {super.statusCode});
}
