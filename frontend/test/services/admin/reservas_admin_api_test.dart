import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/services/admin/reservas_admin_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> reservaJson({
  int id = 7,
  int pasajero = 5,
  String estado = 'consolidada',
}) => {
  'id_reserva': id,
  'id_pasajero': pasajero,
  'id_viaje': 41,
  'id_recorrido': 2,
  'orden_parada': 3,
  'fecha': '2026-10-30',
  'horario': null,
  'sentido': 'IDA',
  'estado': estado,
};

void main() {
  ReservasAdminApi api(
    Future<http.Response> Function(http.Request) responder,
  ) => ReservasAdminApi(
    HttpApiClient(
      baseUri: Uri.parse('https://vanfull.test/api/'),
      accessTokenProvider: () => 'token',
      transport: MockClient(responder),
    ),
  );
  test(
    'GET autenticado sin filtros, preserva orden, pasajeros y tres estados',
    () async {
      final reservas = await api((r) async {
        expect(r.method, 'GET');
        expect(r.url.path, '/api/reservas');
        expect(r.url.query, isEmpty);
        expect(r.headers['authorization'], 'Bearer token');
        return http.Response(
          jsonEncode([
            reservaJson(id: 7, pasajero: 5, estado: 'provisional'),
            reservaJson(id: 8, pasajero: 6),
            reservaJson(id: 9, pasajero: 7, estado: 'cancelada'),
          ]),
          200,
        );
      }).listar();
      expect(reservas.map((r) => r.reserva.idReserva), [7, 8, 9]);
      expect(reservas.map((r) => r.idPasajero), [5, 6, 7]);
      expect(reservas.map((r) => r.reserva.estado.valorApi), [
        'provisional',
        'consolidada',
        'cancelada',
      ]);
      expect(reservas.first.reserva.horario, isNull);
    },
  );
  test('lista vacía se conserva', () async {
    expect(await api((_) async => http.Response('[]', 200)).listar(), isEmpty);
  });
  for (final status in [401, 403, 500]) {
    test('propaga error HTTP $status', () async {
      await expectLater(
        api(
          (_) async => http.Response(
            '{"error":{"codigo":"SIN_PERMISO","mensaje":"Mensaje"}}',
            status,
          ),
        ).listar(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'status', status),
        ),
      );
    });
  }
  test(
    'rechaza listado y pasajero ausente o inválido sin perder identidad',
    () async {
      for (final json in [
        null,
        {},
        [reservaJson()..remove('id_pasajero')],
        [reservaJson()..['id_pasajero'] = '5'],
      ]) {
        await expectLater(
          api((_) async => http.Response(jsonEncode(json), 200)).listar(),
          throwsA(isA<ApiProtocolException>()),
        );
      }
    },
  );
}
