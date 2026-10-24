import 'dart:async';

/// Provee el token vigente sin decidir cómo se obtiene o conserva.
typedef AccessTokenProvider = FutureOr<String?> Function();

/// Transporte común para consumir operaciones del contrato HTTP.
abstract interface class ApiClient {
  Future<Object?> get(String path, {Map<String, String>? queryParameters});

  /// [accessToken] reemplaza al del proveedor: lo usa quien actúa en nombre de
  /// una sesión que ya no es la vigente (la saliente en el logout).
  Future<Object?> post(String path, {Object? body, String? accessToken});

  Future<Object?> patch(String path, {Object? body});
}
