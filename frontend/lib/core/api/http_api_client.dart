import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'api_error.dart';

/// Implementación HTTP del cliente común, sin almacenar sesión ni conocer DTO de negocio.
final class HttpApiClient implements ApiClient {
  HttpApiClient({
    required Uri baseUri,
    required this.transport,
    this.accessTokenProvider,
    this.onNoAutorizado,
  }) : _baseUri = _normalizeBaseUri(baseUri);

  final Uri _baseUri;
  final http.Client transport;
  final AccessTokenProvider? accessTokenProvider;

  /// Se llama con el token que viajó cuando el servidor responde 401. Quien lo
  /// recibe decide si ese token sigue siendo el de la sesión vigente: un pedido
  /// de una sesión anterior no debe cerrar la actual. Un 401 sin token (login)
  /// no lo dispara.
  final void Function(String token)? onNoAutorizado;

  @override
  Future<Object?> get(String path, {Map<String, String>? queryParameters}) =>
      _enviar(
        (headers) =>
            transport.get(_resolve(path, queryParameters), headers: headers),
      );

  @override
  Future<Object?> post(String path, {Object? body, String? accessToken}) =>
      _enviar(
        (headers) => transport.post(
          _resolve(path),
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        jsonBody: body != null,
        accessToken: accessToken,
      );

  @override
  Future<Object?> patch(String path, {Object? body}) => _enviar(
    (headers) => transport.patch(
      _resolve(path),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    ),
    jsonBody: body != null,
  );

  /// El token se fija antes de enviar: si la sesión cambia mientras el pedido
  /// está en vuelo, el 401 se informa con el token con el que salió.
  Future<Object?> _enviar(
    Future<http.Response> Function(Map<String, String> headers) enviar, {
    bool jsonBody = false,
    String? accessToken,
  }) async {
    final token = await _token(accessToken);
    final headers = <String, String>{'Accept': 'application/json'};
    if (jsonBody) headers['Content-Type'] = 'application/json';
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final response = await enviar(headers);
    try {
      return _decode(response);
    } on ApiException catch (e) {
      if (e.statusCode == 401 && token != null) onNoAutorizado?.call(token);
      rethrow;
    }
  }

  Future<String?> _token(String? explicito) async {
    final valor = explicito ?? await accessTokenProvider?.call();
    final token = valor?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  Uri _resolve(String path, [Map<String, String>? queryParameters]) {
    final relativePath = path.startsWith('/') ? path.substring(1) : path;
    final parsedPath = Uri.parse(relativePath);
    if (parsedPath.hasScheme || parsedPath.hasAuthority) {
      throw ArgumentError.value(path, 'path', 'Debe ser una ruta relativa.');
    }

    final resolved = _baseUri.resolveUri(parsedPath);
    if (queryParameters == null) return resolved;
    return resolved.replace(
      queryParameters: {...resolved.queryParameters, ...queryParameters},
    );
  }

  Object? _decode(http.Response response) {
    final body = response.body.trim();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body.isEmpty) return null;
      return _decodeJson(body, response.statusCode);
    }

    final decoded = _decodeJson(body, response.statusCode);
    if (decoded is Map<String, dynamic>) {
      final error = decoded['error'];
      if (error is Map<String, dynamic> &&
          error['codigo'] is String &&
          error['mensaje'] is String) {
        final rawDetails = error['detalles'];
        if (rawDetails != null && rawDetails is! Map<String, dynamic>) {
          throw ApiProtocolException(
            response.statusCode,
            'El campo error.detalles no es un objeto JSON.',
          );
        }
        throw ApiException(
          statusCode: response.statusCode,
          codigo: error['codigo'] as String,
          mensaje: error['mensaje'] as String,
          detalles: rawDetails as Map<String, dynamic>?,
        );
      }
    }
    throw ApiProtocolException(
      response.statusCode,
      'La respuesta de error no respeta el contrato.',
    );
  }

  Object? _decodeJson(String body, int statusCode) {
    if (body.isEmpty) {
      throw ApiProtocolException(statusCode, 'La respuesta JSON está vacía.');
    }
    try {
      return jsonDecode(body);
    } on FormatException {
      throw ApiProtocolException(
        statusCode,
        'La respuesta no contiene JSON válido.',
      );
    }
  }

  static Uri _normalizeBaseUri(Uri baseUri) {
    if ((baseUri.scheme != 'http' && baseUri.scheme != 'https') ||
        !baseUri.hasAuthority ||
        baseUri.hasQuery ||
        baseUri.hasFragment) {
      throw ArgumentError.value(
        baseUri,
        'baseUri',
        'Debe ser una URL base HTTP válida.',
      );
    }
    final value = baseUri.toString();
    return Uri.parse(value.endsWith('/') ? value : '$value/');
  }
}
