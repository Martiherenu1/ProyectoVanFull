import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/services/chofer/avisos_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const clave = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  test('POST mínimo, autorización externa y recuperación por clave', () async {
    final requests = <http.Request>[];
    final transport = MockClient((r) async {
      requests.add(r);
      return http.Response(
        jsonEncode({
          'id_viaje': 7,
          'clave_solicitud': clave,
          'registro': 'confirmado',
          'id_evento_operativo': 10,
        }),
        r.method == 'POST' ? 201 : 200,
      );
    });
    final api = AvisosApi(
      HttpApiClient(
        baseUri: Uri.parse('https://vf.test/api/'),
        transport: transport,
        accessTokenProvider: () => 'sintetico',
      ),
    );
    expect(await api.registrar(7, clave, 'problema', 'interno'), 10);
    expect(await api.recuperar(7, '  ${clave.toUpperCase()}  '), 10);
    expect(requests.first.headers['Authorization'], 'Bearer sintetico');
    expect(jsonDecode(requests.first.body), {
      'clase': 'problema',
      'descripcion_interna': 'interno',
      'clave_solicitud': clave,
    });
    expect(requests.last.url.queryParameters['clave_solicitud'], clave);
    transport.close();
  });
  for (final status in [400, 401, 403, 404, 409, 500]) {
    test('HTTP $status distingue rechazo conocido de incierto', () async {
      var calls = 0;
      final transport = MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({
            'error': {
              'codigo': 'PRUEBA',
              'mensaje': 'privado',
              'detalles': null,
            },
          }),
          status,
        );
      });
      final api = AvisosApi(
        HttpApiClient(
          baseUri: Uri.parse('https://vf.test/api/'),
          transport: transport,
        ),
      );
      await expectLater(
        api.registrar(7, clave, 'demora', 'interno'),
        throwsA(
          status == 403
              ? isA<ApiException>().having((e) => e.statusCode, 'status', 403)
              : status == 500
              ? isNot(isA<AvisoRechazado>())
              : isA<AvisoRechazado>(),
        ),
      );
      expect(calls, 1);
      transport.close();
    });
  }
  test('respuesta de otro viaje nunca confirma', () async {
    final transport = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'id_viaje': 8,
          'clave_solicitud': clave,
          'registro': 'confirmado',
          'id_evento_operativo': 1,
        }),
        201,
      ),
    );
    final api = AvisosApi(
      HttpApiClient(
        baseUri: Uri.parse('https://vf.test/api/'),
        transport: transport,
      ),
    );
    await expectLater(
      api.registrar(7, clave, 'demora', 'interno'),
      throwsFormatException,
    );
    transport.close();
  });
}
