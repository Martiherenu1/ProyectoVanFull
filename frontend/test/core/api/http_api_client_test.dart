import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('GET combina base, ruta, query y token provisto externamente', () async {
    late http.Request sent;
    final transport = MockClient((request) async {
      sent = request;
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final client = HttpApiClient(
      baseUri: Uri.parse('https://api.vanfull.test/api/'),
      transport: transport,
      accessTokenProvider: () async => ' token-vigente ',
    );

    final result = await client.get(
      '/servicios',
      queryParameters: {'fecha': '2026-10-21'},
    );

    expect(sent.method, 'GET');
    expect(
      sent.url,
      Uri.parse('https://api.vanfull.test/api/servicios?fecha=2026-10-21'),
    );
    expect(sent.headers['accept'], 'application/json');
    expect(sent.headers['authorization'], 'Bearer token-vigente');
    expect(result, {'ok': true});
  });

  test('POST codifica JSON sin agregar token cuando no hay uno', () async {
    late http.Request sent;
    final transport = MockClient((request) async {
      sent = request;
      return http.Response(jsonEncode({'id_pago': 8}), 201);
    });
    final client = HttpApiClient(
      baseUri: Uri.parse('https://api.vanfull.test'),
      transport: transport,
      accessTokenProvider: () => null,
    );

    final result = await client.post('/api/pagos', body: {'importe': 1500});

    expect(sent.method, 'POST');
    expect(sent.url, Uri.parse('https://api.vanfull.test/api/pagos'));
    expect(sent.headers['content-type'], 'application/json');
    expect(sent.headers, isNot(contains('authorization')));
    expect(jsonDecode(sent.body), {'importe': 1500});
    expect(result, {'id_pago': 8});
  });

  test('PATCH codifica JSON y manda el token', () async {
    late http.Request sent;
    final client = HttpApiClient(
      baseUri: Uri.parse('https://api.vanfull.test/api/'),
      transport: MockClient((request) async {
        sent = request;
        return http.Response(jsonEncode({'telefono': '1155550000'}), 200);
      }),
      accessTokenProvider: () async => 'tok',
    );

    final result = await client.patch(
      'pasajeros/me',
      body: {'telefono': '1155550000'},
    );

    expect(sent.method, 'PATCH');
    expect(sent.url, Uri.parse('https://api.vanfull.test/api/pasajeros/me'));
    expect(sent.headers['content-type'], 'application/json');
    expect(sent.headers['authorization'], 'Bearer tok');
    expect(jsonDecode(sent.body), {'telefono': '1155550000'});
    expect(result, {'telefono': '1155550000'});
  });

  test('una respuesta exitosa sin cuerpo devuelve null', () async {
    final client = HttpApiClient(
      baseUri: Uri.parse('https://api.vanfull.test'),
      transport: MockClient((_) async => http.Response('', 204)),
    );

    expect(await client.post('/api/auth/logout'), isNull);
  });

  test('convierte el error contractual de FastAPI en ApiException', () async {
    final client = HttpApiClient(
      baseUri: Uri.parse('https://api.vanfull.test'),
      transport: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {
              'codigo': 'SIN_PERMISO',
              'mensaje': 'No tenés permiso.',
              'detalles': {
                'roles_requeridos': ['administrador'],
              },
            },
          }),
          403,
        ),
      ),
    );

    await expectLater(
      client.get('/api/pagos'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having((error) => error.codigo, 'codigo', 'SIN_PERMISO')
            .having(
              (error) => error.detalles?['roles_requeridos'],
              'detalles',
              ['administrador'],
            ),
      ),
    );
  });

  test('rechaza respuestas que no respetan el contrato JSON', () async {
    final client = HttpApiClient(
      baseUri: Uri.parse('https://api.vanfull.test'),
      transport: MockClient((_) async => http.Response('error interno', 500)),
    );

    await expectLater(
      client.get('/api/pagos'),
      throwsA(
        isA<ApiProtocolException>().having(
          (error) => error.statusCode,
          'statusCode',
          500,
        ),
      ),
    );
  });

  http.Response rechazo(int estado) => http.Response(
    jsonEncode({
      'error': {'codigo': 'X', 'mensaje': 'Mensaje.'},
    }),
    estado,
  );

  test('un 401 con token avisa con el token que viajó', () async {
    var vigente = 'A';
    final avisos = <String>[];
    final client = HttpApiClient(
      baseUri: Uri.parse('https://api.vanfull.test'),
      transport: MockClient((_) async {
        // La sesión cambia mientras el pedido está en vuelo.
        vigente = 'B';
        return rechazo(401);
      }),
      accessTokenProvider: () => vigente,
      onNoAutorizado: avisos.add,
    );

    await expectLater(client.get('/api/pagos'), throwsA(isA<ApiException>()));

    expect(avisos, ['A']);
  });

  test('ni el 401 sin token ni el 403 avisan', () async {
    var estado = 401;
    final avisos = <String>[];
    String? token;
    final client = HttpApiClient(
      baseUri: Uri.parse('https://api.vanfull.test'),
      transport: MockClient((_) async => rechazo(estado)),
      accessTokenProvider: () => token,
      onNoAutorizado: avisos.add,
    );

    await expectLater(
      client.post('/api/auth/login'),
      throwsA(isA<ApiException>()),
    );
    token = 'A';
    estado = 403;
    await expectLater(client.get('/api/pagos'), throwsA(isA<ApiException>()));

    expect(avisos, isEmpty);
  });

  test('un token explícito reemplaza al del proveedor', () async {
    late http.Request sent;
    final client = HttpApiClient(
      baseUri: Uri.parse('https://api.vanfull.test'),
      transport: MockClient((request) async {
        sent = request;
        return http.Response('', 204);
      }),
      accessTokenProvider: () => null,
    );

    await client.post('/api/auth/logout', accessToken: 'saliente');

    expect(sent.headers['authorization'], 'Bearer saliente');
  });

  test('rechaza URL base inválida y rutas absolutas', () async {
    expect(
      () => HttpApiClient(
        baseUri: Uri.parse('file:///tmp/api'),
        transport: MockClient((_) async => http.Response('', 200)),
      ),
      throwsArgumentError,
    );

    final client = HttpApiClient(
      baseUri: Uri.parse('https://api.vanfull.test'),
      transport: MockClient((_) async => http.Response('', 200)),
    );
    await expectLater(client.get('https://otro.test/api'), throwsArgumentError);
  });
}
