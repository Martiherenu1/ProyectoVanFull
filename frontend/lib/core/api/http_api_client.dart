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
  }) : _baseUri = _normalizeBaseUri(baseUri);

  final Uri _baseUri;
  final http.Client transport;
  final AccessTokenProvider? accessTokenProvider;

  @override
  Future<Object?> get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await transport.get(
      _resolve(path, queryParameters),
      headers: await _headers(),
    );
    return _decode(response);
  }

  @override
  Future<Object?> post(String path, {Object? body}) async {
    final response = await transport.post(
      _resolve(path),
      headers: await _headers(jsonBody: body != null),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, String>> _headers({bool jsonBody = false}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (jsonBody) headers['Content-Type'] = 'application/json';

    final provider = accessTokenProvider;
    if (provider != null) {
      final token = (await provider())?.trim();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
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
