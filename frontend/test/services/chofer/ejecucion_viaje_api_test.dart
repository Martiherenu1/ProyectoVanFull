import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/controllers/chofer/ejecucion_viaje_controller.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';
import 'package:frontend/services/chofer/ejecucion_viaje_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> viaje(String estado) => {
  'id_viaje': 7,
  'id_servicio': 2,
  'id_recorrido': 3,
  'id_vehiculo': 4,
  'id_chofer': 5,
  'fecha': '2026-10-30',
  'sentido': 'IDA',
  'estado': estado,
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
  late EjecucionViajeApi api;
  late Future<http.Response> Function(http.Request) responder;
  late List<http.Request> solicitudes;
  String? token;

  setUp(() {
    solicitudes = [];
    token = 'token-sintetico';
    responder = (_) async =>
        http.Response(jsonEncode(viaje('finalizado')), 200);
    transporte = TransporteObservable((request) {
      solicitudes.add(request);
      return responder(request);
    });
    api = EjecucionViajeApi(
      HttpApiClient(
        baseUri: Uri.parse('https://vanfull.test/api/'),
        transport: transporte,
        accessTokenProvider: () async => token,
      ),
    );
  });
  tearDown(() {
    expect(transporte.cerrado, isFalse);
    transporte.close();
  });

  test(
    'acciones compatibles, POST sin cuerpo y token externo vigente',
    () async {
      final acciones = AccionesEjecucionViaje(
        iniciar: api.iniciar,
        finalizar: api.finalizar,
      );
      await acciones.iniciar(7);
      token = 'token-renovado';
      await acciones.finalizar(7);
      expect(solicitudes.map((r) => r.url.toString()), [
        'https://vanfull.test/api/viajes/7/inicio',
        'https://vanfull.test/api/viajes/7/finalizacion',
      ]);
      for (final request in solicitudes) {
        expect(request.method, 'POST');
        expect(request.bodyBytes, isEmpty);
        expect(request.headers['accept'], 'application/json');
        expect(request.headers['content-type'], isNull);
      }
      expect(
        solicitudes.first.headers['authorization'],
        'Bearer token-sintetico',
      );
      expect(
        solicitudes.last.headers['authorization'],
        'Bearer token-renovado',
      );
    },
  );

  for (final finalizar in [false, true]) {
    final operacion = finalizar ? 'finalizar' : 'iniciar';
    Future<ViajeResumen> enviar(EjecucionViajeApi api) =>
        finalizar ? api.finalizar(7) : api.iniciar(7);

    for (final estado in EstadoViaje.values) {
      test(
        '$operacion valida estado ${estado.valorApi} e idempotencia',
        () async {
          responder = (_) async =>
              http.Response(jsonEncode(viaje(estado.valorApi)), 200);
          if (estado == EstadoViaje.finalizado ||
              (!finalizar && estado == EstadoViaje.enCurso)) {
            final resultado = await enviar(api);
            expect(resultado.idViaje, 7);
            expect(resultado.estado, estado);
            expect(resultado.horario, isNull);
            expect(resultado.fecha, DateTime(2026, 10, 30));
            expect(resultado.sentido, SentidoViaje.ida);
          } else {
            await expectLater(
              enviar(api),
              throwsA(isA<ResultadoViajeIncierto>()),
            );
          }
          expect(solicitudes, hasLength(1));
        },
      );
    }

    for (final entry in {
      400: MotivoRechazoViaje.validacion,
      401: MotivoRechazoViaje.noAutenticado,
      403: MotivoRechazoViaje.sinPermiso,
      404: MotivoRechazoViaje.noDisponible,
      409: MotivoRechazoViaje.conflicto,
    }.entries) {
      test('$operacion traduce ${entry.key} sin filtrar detalles', () async {
        responder = (_) async => http.Response(
          jsonEncode({
            'error': {
              'codigo': 'CODIGO_SINTETICO',
              'mensaje': 'dato privado sintético',
              'detalles': {'privado': 'dato privado sintético'},
            },
          }),
          entry.key,
        );
        await expectLater(
          enviar(api),
          throwsA(
            isA<RechazoOperacionViaje>()
                .having((e) => e.motivo, 'motivo', entry.value)
                .having((e) => e.codigo, 'codigo', 'CODIGO_SINTETICO')
                .having(
                  (e) => e.toString(),
                  'texto',
                  isNot(contains('privado')),
                ),
          ),
        );
        expect(solicitudes, hasLength(1));
      });
    }

    final respuestasInvalidas = <String, Object?>{
      'vacía': null,
      'lista': [],
      'texto': 'dato privado sintético',
      'objeto incompleto': {'id_viaje': 7},
      'otro ID': {...viaje('finalizado'), 'id_viaje': 8},
      'ID de otro tipo': {...viaje('finalizado'), 'id_viaje': '7'},
      'fecha imposible': {...viaje('finalizado'), 'fecha': '2026-02-30'},
      'estado desconocido': {...viaje('finalizado'), 'estado': 'nuevo'},
      'sentido desconocido': {...viaje('finalizado'), 'sentido': 'nuevo'},
      'horario de otro tipo': {...viaje('finalizado'), 'horario': 730},
    };
    for (final entry in respuestasInvalidas.entries) {
      test('$operacion respuesta ${entry.key} es incierta', () async {
        responder = (_) async => http.Response(jsonEncode(entry.value), 200);
        await expectLater(enviar(api), throwsA(isA<ResultadoViajeIncierto>()));
        expect(solicitudes, hasLength(1));
      });
    }

    for (final status in [200, 204, 400, 401, 403, 404, 409, 422, 500, 503]) {
      test('$operacion protocolo inválido $status es incierto', () async {
        responder = (_) async =>
            http.Response('respuesta no JSON privada', status);
        await expectLater(enviar(api), throwsA(isA<ResultadoViajeIncierto>()));
        expect(solicitudes, hasLength(1));
      });
    }
    for (final status in [422, 500, 503]) {
      test('$operacion error JSON $status es incierto', () async {
        responder = (_) async => http.Response(
          jsonEncode({
            'error': {'codigo': 'ERROR', 'mensaje': 'privado'},
          }),
          status,
        );
        await expectLater(enviar(api), throwsA(isA<ResultadoViajeIncierto>()));
        expect(solicitudes, hasLength(1));
      });
    }
    for (final status in [200, 204]) {
      test('$operacion respuesta vacía $status es incierta', () async {
        responder = (_) async => http.Response('', status);
        await expectLater(enviar(api), throwsA(isA<ResultadoViajeIncierto>()));
        expect(solicitudes, hasLength(1));
      });
    }
    for (final status in [400, 401, 403, 404, 409]) {
      test('$operacion error JSON malformado $status es incierto', () async {
        responder = (_) async => http.Response(
          jsonEncode({
            'error': {'codigo': 'ERROR'},
          }),
          status,
        );
        await expectLater(enviar(api), throwsA(isA<ResultadoViajeIncierto>()));
        expect(solicitudes, hasLength(1));
      });
    }
    for (final fallo in [
      http.ClientException('dato privado sintético'),
      TimeoutException('dato privado sintético'),
      StateError('dato privado sintético'),
    ]) {
      test('$operacion fallo ${fallo.runtimeType} sin reenvío', () async {
        responder = (_) async => throw fallo;
        await expectLater(enviar(api), throwsA(isA<ResultadoViajeIncierto>()));
        expect(solicitudes, hasLength(1));
        // El propietario puede seguir usando el mismo transporte.
        responder = (_) async =>
            http.Response(jsonEncode(viaje('finalizado')), 200);
        expect((await enviar(api)).estado, EstadoViaje.finalizado);
        expect(solicitudes, hasLength(2));
      });
    }
  }

  test('sin token no agrega autenticación ni obtiene sesión propia', () async {
    token = null;
    await api.finalizar(7);
    expect(solicitudes.single.headers, isNot(contains('authorization')));
  });

  test(
    'conserva horario y datos del Viaje confirmado por el servidor',
    () async {
      responder = (_) async => http.Response(
        jsonEncode({...viaje('en_curso'), 'horario': '07:30'}),
        200,
      );
      final resultado = await api.iniciar(7);
      expect(resultado.horario, '07:30');
      expect(resultado.idServicio, 2);
      expect(resultado.idRecorrido, 3);
      expect(resultado.idVehiculo, 4);
      expect(resultado.idChofer, 5);
    },
  );
}
