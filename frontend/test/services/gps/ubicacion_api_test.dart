import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/services/gps/ubicacion_api.dart';

void main() {
  test('POST contratado fija token de sesión y no hace reintentos', () async {
    var solicitudes = 0;
    final transport = MockClient((r) async {
      solicitudes++;
      expect(r.url.path, '/api/viajes/4/ubicacion');
      expect(r.headers['Authorization'], 'Bearer saliente');
      expect((jsonDecode(r.body) as Map).keys.toSet(), {
        'latitud',
        'longitud',
        'fecha_hora_posicion',
      });
      return http.Response(
        '{"actualizada":true,"fecha_hora_posicion":"2026-01-01T00:00:00Z"}',
        200,
      );
    });
    final api = UbicacionApi(
      HttpApiClient(
        baseUri: Uri.parse('http://localhost/api'),
        transport: transport,
        accessTokenProvider: () => 'nueva',
      ),
    );
    await api.enviar(4, 0, 0, DateTime.utc(2026), 'saliente');
    expect(solicitudes, 1);
    transport.close();
  });
  test('GET valida viaje y no inventa ETA', () async {
    final transport = MockClient(
      (r) async => http.Response(
        jsonEncode({
          'id_viaje': 4,
          'latitud': 0,
          'longitud': 0,
          'fecha_hora_posicion': '2026-01-01T00:00:00Z',
          'desactualizada': true,
          'eta_minutos': null,
        }),
        200,
      ),
    );
    final api = UbicacionApi(
      HttpApiClient(
        baseUri: Uri.parse('http://localhost/api'),
        transport: transport,
      ),
    );
    expect((await api.consultar(4)).etaMinutos, isNull);
    await expectLater(api.consultar(5), throwsFormatException);
    transport.close();
  });
}
