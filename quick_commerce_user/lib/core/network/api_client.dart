/// Transport abstraction. Repositories depend on this, never on Dio.
///
/// Implementations return the decoded `data` payload of the backend's
/// `{success, message, data}` envelope, and throw an `AppException` otherwise.
abstract interface class ApiClient {
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool requiresAuth,
  });

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool requiresAuth,
  });

  Future<dynamic> patch(
    String path, {
    Object? body,
    bool requiresAuth,
  });

  Future<dynamic> put(
    String path, {
    Object? body,
    bool requiresAuth,
  });

  Future<dynamic> delete(
    String path, {
    Object? body,
    bool requiresAuth,
  });
}
