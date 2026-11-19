import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/models/admin/historial_viaje.dart';
import 'package:frontend/services/admin/historial_viajes_admin_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> viajeJson({int id = 7}) => {
  'id_viaje': id,
  'fecha': '2026-03-10',
  'horario': '07:30',
  'sentido': 'IDA',
  'estado': 'finalizado',
  'id_servicio': 1,
  'tipo_servicio': 'LABORAL',
  'id_recorrido': 2,
  'chofer': {'id_persona': 4, 'nombre': 'Carla', 'apellido': 'Ruta'},
  'vehiculo': {'id_vehiculo': 3, 'patente': 'AB123CD'},
};

void main() {
  HistorialViajesAdminApi api(
    Future<http.Response> Function(http.Request) responder,
  ) => HistorialViajesAdminApi(
    HttpApiClient(
      baseUri: Uri.parse('https://vanfull.test/api/'),
      accessTokenProvider: () => 'token',
      transport: MockClient(responder),
    ),
  );

  http.Response json(Object cuerpo, [int estado = 200]) => http.Response(
    jsonEncode(cuerpo),
    estado,
    headers: {'content-type': 'application/json'},
  );

  test('listar sin criterios no manda query y lee los viajes', () async {
    final lista = await api((r) async {
      expect(r.method, 'GET');
      expect(r.url.path, '/api/administracion/historial-viajes');
      expect(r.url.query, isEmpty);
      expect(r.headers['authorization'], 'Bearer token');
      return json({
        'items': [viajeJson()],
        'total': 1,
      });
    }).listar(const HistorialFiltros());
    expect(lista.single.idViaje, 7);
    expect(lista.single.chofer!.nombreCompleto, 'Carla Ruta');
    expect(lista.single.patente, 'AB123CD');
  });

  test('listar manda los criterios con fechas YYYY-MM-DD', () async {
    await api((r) async {
      expect(r.url.queryParameters, {
        'desde': '2026-03-01',
        'hasta': '2026-03-31',
        'estado': 'cancelado',
        'sentido': 'VUELTA',
      });
      return json({'items': [], 'total': 0});
    }).listar(
      HistorialFiltros(
        desde: DateTime(2026, 3, 1),
        hasta: DateTime(2026, 3, 31),
        estado: 'cancelado',
        sentido: 'VUELTA',
      ),
    );
  });

  test('un viaje sin chofer ni vehículo se lee sin ellos', () async {
    final lista = await api(
      (_) async => json({
        'items': [
          viajeJson()
            ..remove('chofer')
            ..remove('vehiculo')
            ..remove('horario'),
        ],
        'total': 1,
      }),
    ).listar(const HistorialFiltros());
    expect(lista.single.chofer, isNull);
    expect(lista.single.patente, isNull);
    expect(lista.single.horario, isNull);
  });

  test('una respuesta fuera de contrato es de protocolo', () {
    expect(
      api((_) async => json([1])).listar(const HistorialFiltros()),
      throwsA(isA<ApiProtocolException>()),
    );
  });

  test('detalle lee paradas y conteos', () async {
    final d = await api((r) async {
      expect(r.url.path, '/api/administracion/historial-viajes/7');
      return json({
        ...viajeJson(),
        'capacidad_planificada': 10,
        'paradas': [
          {'orden': 1, 'id_parada': 5, 'nombre_descripcion': 'Plaza'},
          {'orden': 2, 'id_parada': 6},
        ],
        'conteos': {
          'reservas_provisionales': 1,
          'reservas_consolidadas': 2,
          'reservas_canceladas': 3,
          'abordajes': 4,
          'ausencias': 5,
        },
      });
    }).detalle(7);
    expect(d.capacidadPlanificada, 10);
    expect(d.paradas.first.etiqueta, 'Plaza');
    expect(d.paradas.last.etiqueta, 'Parada 6');
    expect(d.conteos.consolidadas, 2);
    expect(d.conteos.ausencias, 5);
  });

  test('un 404 del detalle llega con su código', () async {
    final error = api(
      (_) async => json({
        'error': {'codigo': 'VIAJE_NO_ENCONTRADO', 'mensaje': 'no'},
      }, 404),
    ).detalle(9);
    await expectLater(
      error,
      throwsA(
        isA<ApiException>().having(
          (e) => e.codigo,
          'codigo',
          'VIAJE_NO_ENCONTRADO',
        ),
      ),
    );
  });

  test('detalle fuera de contrato es de protocolo', () {
    expect(
      api((_) async => json({'id_viaje': 1})).detalle(1),
      throwsA(isA<ApiProtocolException>()),
    );
  });
}
