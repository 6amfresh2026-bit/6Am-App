import 'package:dio/dio.dart';

import 'app_exception.dart';
import 'failure.dart';

/// Dio/transport errors → typed [AppException] (data layer), and
/// [AppException] → [Failure] (domain/UI boundary).
abstract final class ErrorMapper {
  static AppException fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutException('The request timed out.');
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return const NetworkException('Could not reach the server.');
      case DioExceptionType.cancel:
        return const NetworkException('Request cancelled.');
      case DioExceptionType.badCertificate:
        return const NetworkException('Insecure connection.');
      case DioExceptionType.badResponse:
        return fromResponse(e.response);
      default:
        return const UnknownException('The request failed.');
    }
  }

  static AppException fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode ?? 0;
    final body = response?.data;
    final message = _messageFrom(body) ?? 'Request failed ($status).';
    return switch (status) {
      401 || 403 => UnauthorizedException(message),
      404 => NotFoundException(message),
      400 || 409 || 422 => ValidationException(message, statusCode: status),
      >= 500 => ServerException(message, statusCode: status),
      _ => UnknownException(message, statusCode: status),
    };
  }

  static String? _messageFrom(dynamic body) {
    if (body is Map && body['message'] is String) {
      final m = (body['message'] as String).trim();
      return m.isEmpty ? null : _brandTerms(m);
    }
    return null;
  }

  /// The backend is a food-delivery service reused for grocery, so its copy
  /// says "Restaurant" where this app brands every seller a "Store". Every
  /// user-facing backend message flows through here, so rewriting the term
  /// once keeps the two from disagreeing — e.g. "Restaurant is currently
  /// closed" becomes "Store is currently closed" on screen. Harmless once the
  /// backend copy is updated; essential until it is deployed.
  static String _brandTerms(String message) => message
      .replaceAll('Restaurants', 'Stores')
      .replaceAll('Restaurant', 'Store')
      .replaceAll('restaurants', 'stores')
      .replaceAll('restaurant', 'store');

  static Failure toFailure(Object error) => switch (error) {
        NetworkException() => NetworkFailure(error.message),
        TimeoutException() => TimeoutFailure(error.message),
        UnauthorizedException() => AuthFailure(error.message),
        NotFoundException() => NotFoundFailure(error.message),
        ValidationException() => ValidationFailure(error.message),
        ServerException() => ServerFailure(error.message),
        ParseException() => const UnknownFailure('We received an unexpected response.'),
        AppException() => UnknownFailure(error.message),
        _ => const UnknownFailure(),
      };
}
