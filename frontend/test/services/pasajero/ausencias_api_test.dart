import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/services/pasajero/ausencias_api.dart';

void main() {
  for (final status in [200, 201, 400, 401, 403, 404, 409]) {
    test('HTTP $status con cuerpo y sesión contractuales', () async {
      final transport = MockClient((r) async {
        expect(r.method, 'POST');
        expect(r.url.path, '/api/ausencias');
        expect(jsonDecode(r.body), {'id_viaje': 12});
        expect(r.headers['Authorization'], 'Bearer A');
        return http.Response(
          status < 300
              ? '{"id_ausencia":1,"id_pasajero":7,"id_viaje":12}'
              : '{"error":{"codigo":"RECHAZO","mensaje":"Motivo"}}',
          status,
        );
      });
      addTearDown(transport.close);
      final api = AusenciasApi(
        HttpApiClient(
          baseUri: Uri.parse('https://example.test/api/'),
          transport: transport,
          accessTokenProvider: () => 'B',
        ),
      );
      if (status < 300) {
        await api.informar(12, accessToken: 'A');
      } else {
        await expectLater(
          api.informar(12, accessToken: 'A'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', status),
          ),
        );
      }
    });
  }
  test('propaga red', () async {
    final transport = MockClient(
      (_) async => throw http.ClientException('red'),
    );
    addTearDown(transport.close);
    await expectLater(
      AusenciasApi(
        HttpApiClient(
          baseUri: Uri.parse('https://example.test/'),
          transport: transport,
        ),
      ).informar(12, accessToken: 'A'),
      throwsA(isA<http.ClientException>()),
    );
  });
  for (final body in [
    'null',
    '{}',
    '{"id_ausencia":1,"id_pasajero":7,"id_viaje":99}',
  ]) {
    test('rechaza respuesta inválida $body', () async {
      final transport = MockClient((_) async => http.Response(body, 201));
      addTearDown(transport.close);
      await expectLater(
        AusenciasApi(
          HttpApiClient(
            baseUri: Uri.parse('https://example.test/'),
            transport: transport,
          ),
        ).informar(12, accessToken: 'A'),
        throwsFormatException,
      );
    });
  }
}
