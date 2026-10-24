import 'dart:async';

/// Provee el token vigente sin decidir cómo se obtiene o conserva.
typedef AccessTokenProvider = FutureOr<String?> Function();

/// Transporte común para consumir operaciones del contrato HTTP.
abstract interface class ApiClient {
  Future<Object?> get(String path, {Map<String, String>? queryParameters});

  Future<Object?> post(String path, {Object? body});

  Future<Object?> patch(String path, {Object? body});
}
