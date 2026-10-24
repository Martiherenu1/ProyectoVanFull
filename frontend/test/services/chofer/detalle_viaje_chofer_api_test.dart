import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/screens/chofer/detalle_viaje_chofer_screen.dart';
import 'package:frontend/services/chofer/detalle_viaje_chofer_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../fixtures/chofer/operacion_asignada_fixture.dart';

class TransporteObservado extends MockClient {
  TransporteObservado(super.handler);

  bool cerrado = false;

  @override
  void close() {
    cerrado = true;
    super.close();
  }
}

void main() {
  late TransporteObservado transport;
  late DetalleViajeChoferApi api;
  var llamadas = 0;
  String? token = 'token-externo';

  void responder(Future<http.Response> Function(http.Request) handler) {
    transport = TransporteObservado((request) {
      llamadas++;
      return handler(request);
    });
    api = DetalleViajeChoferApi(
      HttpApiClient(
        baseUri: Uri.parse('https://example.test/api/'),
        transport: transport,
        accessTokenProvider: () => token,
      ),
    );
  }

  setUp(() {
    llamadas = 0;
    token = 'token-externo';
  });
  tearDown(() {
    expect(transport.cerrado, isFalse);
    transport.close();
  });

  test(
    'GET correcto, token vigente y callback compatible con la pantalla',
    () async {
      responder((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://example.test/api/choferes/me/viajes/41',
        );
        expect(request.headers['Authorization'], 'Bearer $token');
        expect(request.body, isEmpty);
        return http.Response(jsonEncode(detalleJson()), 200);
      });
      final CargarDetalleViajeChofer cargar = api.cargarDetalle;
      final detalle = (await cargar(41))!;
      expect(detalle.viaje.idViaje, 41);
      expect(detalle.capacidadPlanificada, 18);
      expect(detalle.paradas.map((p) => p.idParada), [11, 12]);
      expect(detalle.pasajerosConReserva.map((p) => p.idReserva), [61, 62]);
      expect(detalle.integrantesNomina.single.idIntegranteNomina, 71);
      expect(detalle.pasajerosConReserva.first.fotografia, isNull);
      expect(detalle.pasajerosConReserva.last.fotografia, 'foto-referenciada');
      expect(detalle.cantidades.totalNomina, 1);
      token = 'token-renovado';
      await cargar(
        41,
      ); // El adaptador no cierra el transporte ni conserva el token.
      expect(llamadas, 2);
    },
  );

  test('usa el ID solicitado sin fijarlo al fixture', () async {
    responder((request) async {
      expect(request.url.path, '/api/choferes/me/viajes/782');
      return http.Response(jsonEncode(detalleJson(id: 782)), 200);
    });
    expect((await api.cargarDetalle(782))!.viaje.idViaje, 782);
    expect(llamadas, 1);
  });

  test('conserva listas vacías, capacidad nula y horario omitido', () async {
    final json = detalleJson();
    (json['viaje'] as Map).remove('horario');
    json['capacidad_planificada'] = null;
    (json['viaje'] as Map).remove('id_chofer');
    (json['viaje'] as Map)['id_vehiculo'] = null;
    for (final campo in [
      'paradas',
      'pasajeros_con_reserva',
      'integrantes_nomina',
    ]) {
      json[campo] = [];
    }
    responder((_) async => http.Response(jsonEncode(json), 200));
    final detalle = (await api.cargarDetalle(41))!;
    expect(detalle.viaje.horario, isNull);
    expect(detalle.capacidadPlanificada, isNull);
    expect(detalle.viaje.idChofer, isNull);
    expect(detalle.viaje.idVehiculo, isNull);
    expect(detalle.paradas, isEmpty);
    expect(detalle.pasajerosConReserva, isEmpty);
    expect(detalle.integrantesNomina, isEmpty);
    // Se conservan las cantidades recibidas, sin recalcularlas desde las listas.
    expect(detalle.cantidades.totalReservas, 2);
  });

  for (final status in [400, 401, 403, 404, 500]) {
    test('error contractual $status sin reintentos', () async {
      responder(
        (_) async => http.Response(
          jsonEncode({
            'error': {'codigo': 'ERROR', 'mensaje': 'Mensaje servidor'},
          }),
          status,
        ),
      );
      if (status == 404) {
        expect(await api.cargarDetalle(41), isNull);
      } else {
        await expectLater(
          api.cargarDetalle(41),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'status', status)
                .having((e) => e.codigo, 'codigo', 'ERROR'),
          ),
        );
      }
      expect(llamadas, 1);
    });
  }

  for (final status in [200, 404, 502]) {
    test('JSON ilegible $status sigue siendo error de protocolo', () async {
      responder((_) async => http.Response('no es JSON', status));
      await expectLater(
        api.cargarDetalle(41),
        throwsA(isA<ApiProtocolException>()),
      );
      expect(llamadas, 1);
    });
  }

  test('fallo de transporte se propaga sin reintentos', () async {
    final error = http.ClientException('Sin conexión');
    responder((_) async => throw error);
    await expectLater(api.cargarDetalle(41), throwsA(same(error)));
    expect(llamadas, 1);
  });

  final invalidos = <String, Object? Function()>{
    'null': () => null,
    'lista': () => [],
    'objeto vacío': () => {},
    'ID diferente': () => detalleJson(id: 42),
    'nullable requerido omitido': () =>
        detalleJson()..remove('capacidad_planificada'),
    'elemento inválido después de uno válido': () {
      final json = detalleJson();
      (json['pasajeros_con_reserva'] as List).add({'dni': 'dato-privado'});
      return json;
    },
    'enum desconocido': () {
      final json = detalleJson();
      (json['viaje'] as Map)['estado'] = 'dato-privado';
      return json;
    },
  };
  for (final caso in invalidos.entries) {
    test('${caso.key}: error fijo sin datos ni resultado parcial', () async {
      responder((_) async => http.Response(jsonEncode(caso.value()), 200));
      await expectLater(
        api.cargarDetalle(41),
        throwsA(
          isA<DetalleViajeInvalidoException>().having(
            (e) => e.toString(),
            'mensaje',
            'La respuesta del detalle del viaje es inválida.',
          ),
        ),
      );
      expect(llamadas, 1);
    });
  }
}
