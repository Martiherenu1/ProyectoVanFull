import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';
import 'package:frontend/services/admin/viajes_dia_admin_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> viaje(int id) => {
  'id_viaje': id,
  'id_servicio': 2,
  'id_recorrido': 3,
  'id_vehiculo': 4,
  'id_chofer': 5,
  'fecha': '2026-10-30',
  'horario': '07:30',
  'sentido': 'IDA',
  'estado': 'programado',
};

void main() {
  late Future<http.Response> Function(http.Request) responder;
  late MockClient transporte;
  late ViajesDiaAdminApi api;
  var llamadas = 0;

  setUp(() {
    llamadas = 0;
    responder = (_) async => http.Response('[]', 200);
    transporte = MockClient((request) {
      llamadas++;
      return responder(request);
    });
    api = ViajesDiaAdminApi(
      HttpApiClient(
        baseUri: Uri.parse('https://vanfull.test/api/'),
        transport: transporte,
        accessTokenProvider: () => 'token-sintetico',
      ),
    );
  });

  tearDown(() => transporte.close());

  test('envía GET /viajes con fecha obligatoria y token externo', () async {
    late http.Request enviada;
    responder = (request) async {
      enviada = request;
      return http.Response('[]', 200);
    };

    expect(await api.cargarViajes(DateTime.utc(2026, 2, 3, 23, 59)), isEmpty);
    expect(enviada.method, 'GET');
    expect(
      enviada.url.toString(),
      'https://vanfull.test/api/viajes?fecha=2026-02-03',
    );
    expect(enviada.headers['authorization'], 'Bearer token-sintetico');
    expect(llamadas, 1);
  });

  test(
    'decodifica en orden campos completos y asignaciones ausentes',
    () async {
      responder = (_) async => http.Response(
        jsonEncode([
          viaje(42),
          viaje(41)
            ..remove('horario')
            ..remove('id_vehiculo')
            ..remove('id_chofer'),
        ]),
        200,
      );

      final lista = await api.cargarViajes(DateTime(2026, 10, 30));

      expect(lista.map((item) => item.idViaje), [42, 41]);
      expect(lista.first.estado, EstadoViaje.programado);
      expect(lista.last.horario, isNull);
      expect(lista.last.idVehiculo, isNull);
      expect(lista.last.idChofer, isNull);
      expect(() => lista.clear(), throwsUnsupportedError);
    },
  );

  for (final estado in [400, 401, 403, 500]) {
    test('propaga el error HTTP $estado sin reintentar', () async {
      responder = (_) async => http.Response(
        jsonEncode({
          'error': {
            'codigo': 'ERROR_PRUEBA',
            'mensaje': 'Rechazado',
            'detalles': {'prueba': true},
          },
        }),
        estado,
      );

      await expectLater(
        api.cargarViajes(DateTime(2026, 10, 30)),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'status', estado)
              .having((error) => error.codigo, 'codigo', 'ERROR_PRUEBA'),
        ),
      );
      expect(llamadas, 1);
    });
  }

  test('propaga el mismo error de transporte sin reintentar', () async {
    final error = http.ClientException('Fallo simulado');
    responder = (_) async => throw error;

    await expectLater(
      api.cargarViajes(DateTime(2026, 10, 30)),
      throwsA(same(error)),
    );
    expect(llamadas, 1);
  });

  test('propaga JSON inválido como error de protocolo', () async {
    responder = (_) async => http.Response('<html>error</html>', 200);

    await expectLater(
      api.cargarViajes(DateTime(2026, 10, 30)),
      throwsA(isA<ApiProtocolException>()),
    );
    expect(llamadas, 1);
  });

  final respuestasInvalidas = <Object?>[
    null,
    {},
    [null],
    [1],
    [viaje(1), {}],
    [viaje(1)..['fecha'] = '2026-02-30'],
    [viaje(1)..['estado'] = 'desconocido'],
  ];
  for (var indice = 0; indice < respuestasInvalidas.length; indice++) {
    test(
      'rechaza respuesta incompatible $indice sin listado parcial',
      () async {
        responder = (_) async =>
            http.Response(jsonEncode(respuestasInvalidas[indice]), 200);

        await expectLater(
          api.cargarViajes(DateTime(2026, 10, 30)),
          throwsA(isA<ListadoViajesAdminInvalidoException>()),
        );
        expect(llamadas, 1);
      },
    );
  }

  test('rechaza años que no puede representar YYYY-MM-DD', () async {
    await expectLater(
      api.cargarViajes(DateTime(0, 10, 30)),
      throwsArgumentError,
    );
    expect(llamadas, 0);
  });
}
