import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';
import 'package:frontend/services/chofer/viajes_chofer_api.dart';
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

class TransporteObservable extends MockClient {
  TransporteObservable(super.handler);
  bool cerrado = false;
  @override
  void close() {
    cerrado = true;
    super.close();
  }
}

void main() {
  late TransporteObservable transporte;
  late ViajesChoferApi api;
  var llamadas = 0;
  String? token;
  late Future<http.Response> Function(http.Request) responder;

  setUp(() {
    llamadas = 0;
    token = 'token-sintetico';
    responder = (_) async => http.Response('[]', 200);
    transporte = TransporteObservable((request) {
      llamadas++;
      return responder(request);
    });
    api = ViajesChoferApi(
      HttpApiClient(
        baseUri: Uri.parse('https://vanfull.test/api/'),
        transport: transporte,
        accessTokenProvider: () async => token,
      ),
    );
  });
  tearDown(() => transporte.close());

  test(
    'ruta sin duplicar /api, fecha explícita y token externo vigente',
    () async {
      final enviadas = <http.Request>[];
      responder = (request) async {
        enviadas.add(request);
        return http.Response('[]', 200);
      };
      await api.cargarViajes(DateTime.utc(2026, 10, 30, 0, 15));
      token = 'otro-token-sintetico';
      await api.cargarViajes(DateTime(2026, 10, 31, 23, 59));
      expect(enviadas.first.method, 'GET');
      expect(
        enviadas.first.url.toString(),
        'https://vanfull.test/api/choferes/me/viajes?fecha=2026-10-30',
      );
      expect(enviadas.first.body, isEmpty);
      expect(enviadas.first.headers['authorization'], 'Bearer token-sintetico');
      expect(
        enviadas.last.headers['authorization'],
        'Bearer otro-token-sintetico',
      );
      expect(enviadas.last.url.queryParameters, {'fecha': '2026-10-31'});
      expect(llamadas, 2);
      expect(transporte.cerrado, isFalse);
    },
  );

  test('ceros iniciales, lista vacía y transporte reutilizable', () async {
    responder = (request) async {
      expect(request.url.queryParameters, {'fecha': '0001-02-03'});
      return http.Response('[]', 200);
    };
    expect(await api.cargarViajes(DateTime(1, 2, 3)), isEmpty);
    expect(transporte.cerrado, isFalse);
    await api.cargarViajes(DateTime(1, 2, 3));
    expect(llamadas, 2);
  });

  test('deserializa sin ordenar y conserva horario omitido', () async {
    responder = (_) async => http.Response(
      jsonEncode([
        viaje(42),
        viaje(41)
          ..remove('horario')
          ..remove('id_vehiculo'),
      ]),
      200,
    );
    final lista = await api.cargarViajes(DateTime(2026, 10, 30));
    expect(lista.map((v) => v.idViaje), [42, 41]);
    final v = lista.first;
    expect(
      [v.idServicio, v.idRecorrido, v.idVehiculo, v.idChofer],
      [2, 3, 4, 5],
    );
    expect(v.fecha, DateTime(2026, 10, 30));
    expect(v.horario, '07:30');
    expect(v.sentido, SentidoViaje.ida);
    expect(v.estado, EstadoViaje.programado);
    expect(lista.last.horario, isNull);
    expect(lista.last.idVehiculo, isNull);
    expect(() => lista.clear(), throwsUnsupportedError);
    expect(llamadas, 1);
  });

  for (final status in [400, 401, 403, 500]) {
    test(
      'propaga error contractual $status sin reintentar ni cerrar',
      () async {
        responder = (_) async => http.Response(
          jsonEncode({
            'error': {
              'codigo': 'ERROR_PRUEBA',
              'mensaje': 'Rechazado',
              'detalles': {'prueba': true},
            },
          }),
          status,
        );
        await expectLater(
          api.cargarViajes(DateTime(2026, 10, 30)),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'status', status)
                .having((e) => e.codigo, 'codigo', 'ERROR_PRUEBA')
                .having((e) => e.mensaje, 'mensaje', 'Rechazado')
                .having((e) => e.detalles, 'detalles', {'prueba': true}),
          ),
        );
        expect(llamadas, 1);
        expect(transporte.cerrado, isFalse);
      },
    );
  }

  test(
    'propaga el mismo fallo de transporte sin reintentar ni cerrar',
    () async {
      final error = http.ClientException('Fallo simulado');
      responder = (_) async => throw error;
      await expectLater(
        api.cargarViajes(DateTime(2026, 10, 30)),
        throwsA(same(error)),
      );
      expect(llamadas, 1);
      expect(transporte.cerrado, isFalse);
    },
  );

  for (final body in ['<html>respuesta</html>', '']) {
    test('conserva error de protocolo JSON: $body', () async {
      responder = (_) async => http.Response(body, 200);
      await expectLater(
        api.cargarViajes(DateTime(2026, 10, 30)),
        throwsA(
          body.isEmpty
              ? isA<ListadoViajesInvalidoException>()
              : isA<ApiProtocolException>(),
        ),
      );
      expect(llamadas, 1);
      expect(transporte.cerrado, isFalse);
    });
  }

  final invalidas = <Object?>[
    null,
    {},
    [null],
    [1],
    [viaje(1), {}],
    [viaje(1)..['id_viaje'] = 'dato-privado-sintetico'],
    [viaje(1)..['fecha'] = '2026-02-30'],
    [viaje(1)..['estado'] = 'dato-privado-sintetico'],
    [viaje(1)..['sentido'] = 'OTRO'],
  ];
  for (var i = 0; i < invalidas.length; i++) {
    test(
      'estructura/DTO inválido $i: error fijo, sin listado parcial',
      () async {
        responder = (_) async => http.Response(jsonEncode(invalidas[i]), 200);
        await expectLater(
          api.cargarViajes(DateTime(2026, 10, 30)),
          throwsA(
            isA<ListadoViajesInvalidoException>().having(
              (e) => e.toString(),
              'mensaje seguro',
              'La respuesta del listado de viajes es inválida.',
            ),
          ),
        );
        expect(llamadas, 1);
        expect(transporte.cerrado, isFalse);
      },
    );
  }
}
