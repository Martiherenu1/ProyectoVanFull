import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/models/admin/viaje_create.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';
import 'package:frontend/services/admin/viajes_admin_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> viajeCreado({int? idVehiculo = 3, int? idChofer = 4}) => {
  'id_viaje': 10,
  'id_servicio': 1,
  'id_recorrido': 2,
  'id_vehiculo': idVehiculo,
  'id_chofer': idChofer,
  'fecha': '2026-10-30',
  'horario': '07:30',
  'sentido': 'IDA',
  'estado': 'programado',
};

ViajeCreate solicitudBase() => ViajeCreate(
  idServicio: 1,
  idRecorrido: 2,
  fecha: DateTime(2026, 10, 30),
  sentido: SentidoViaje.ida,
);

void main() {
  late Future<http.Response> Function(http.Request) responder;
  late ViajesAdminApi api;
  var llamadas = 0;

  setUp(() {
    llamadas = 0;
    responder = (_) async => http.Response(jsonEncode(viajeCreado()), 201);
    final transporte = MockClient((request) {
      llamadas++;
      return responder(request);
    });
    api = ViajesAdminApi(
      HttpApiClient(
        baseUri: Uri.parse('https://vanfull.test/api/'),
        transport: transporte,
        accessTokenProvider: () => 'token-administrativo-sintetico',
      ),
    );
  });

  test('crea el viaje con el cuerpo contractual y token externo', () async {
    late http.Request enviada;
    responder = (request) async {
      enviada = request;
      return http.Response(jsonEncode(viajeCreado()), 201);
    };

    final resultado = await api.crearViaje(
      ViajeCreate(
        idServicio: 1,
        idRecorrido: 2,
        idVehiculo: 3,
        idChofer: 4,
        fecha: DateTime(2026, 10, 30),
        horario: '07:30',
        sentido: SentidoViaje.ida,
        capacidadPlanificada: 18,
      ),
    );

    expect(enviada.method, 'POST');
    expect(enviada.url.toString(), 'https://vanfull.test/api/viajes');
    expect(
      enviada.headers['authorization'],
      'Bearer token-administrativo-sintetico',
    );
    expect(enviada.headers['content-type'], 'application/json');
    expect(jsonDecode(enviada.body), {
      'id_servicio': 1,
      'id_recorrido': 2,
      'id_vehiculo': 3,
      'id_chofer': 4,
      'fecha': '2026-10-30',
      'horario': '07:30',
      'sentido': 'IDA',
      'capacidad_planificada': 18,
    });
    expect(resultado.idViaje, 10);
    expect(resultado.sentido, SentidoViaje.ida);
    expect(resultado.estado, EstadoViaje.programado);
    expect(llamadas, 1);
  });

  test('envía asignaciones nulas y omite los opcionales ausentes', () async {
    late Map<String, dynamic> cuerpo;
    responder = (request) async {
      cuerpo = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(viajeCreado(idVehiculo: null, idChofer: null)),
        201,
      );
    };

    final resultado = await api.crearViaje(
      ViajeCreate(
        idServicio: 1,
        idRecorrido: 2,
        fecha: DateTime(2026, 10, 30),
        sentido: SentidoViaje.vuelta,
      ),
    );

    expect(cuerpo['id_vehiculo'], isNull);
    expect(cuerpo['id_chofer'], isNull);
    expect(cuerpo, isNot(contains('horario')));
    expect(cuerpo, isNot(contains('capacidad_planificada')));
    expect(resultado.idVehiculo, isNull);
    expect(resultado.idChofer, isNull);
    expect(llamadas, 1);
  });

  test('acepta propiedades ausentes porque Viaje no las exige', () async {
    responder = (_) async => http.Response('{}', 201);
    final resultado = await api.crearViaje(solicitudBase());
    expect(resultado.idViaje, isNull);
    expect(resultado.estado, isNull);
  });

  test('propaga el 403 contractual sin reinterpretarlo', () async {
    responder = (_) async => http.Response(
      jsonEncode({
        'error': {
          'codigo': 'SIN_PERMISO',
          'mensaje': 'No tiene permisos.',
          'detalles': {'rol': 'pasajero'},
        },
      }),
      403,
    );

    await expectLater(
      api.crearViaje(solicitudBase()),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'status', 403)
            .having((error) => error.codigo, 'código', 'SIN_PERMISO'),
      ),
    );
    expect(llamadas, 1);
  });

  test('propaga JSON inválido como error de protocolo', () async {
    responder = (_) async => http.Response('<html>error</html>', 201);
    await expectLater(
      api.crearViaje(solicitudBase()),
      throwsA(isA<ApiProtocolException>()),
    );
    expect(llamadas, 1);
  });

  test('rechaza una estructura JSON incompatible con Viaje', () async {
    responder = (_) async => http.Response(
      jsonEncode({...viajeCreado(), 'estado': 'desconocido'}),
      201,
    );
    await expectLater(
      api.crearViaje(solicitudBase()),
      throwsA(isA<ViajeCreadoInvalidoException>()),
    );
    expect(llamadas, 1);
  });

  test('propaga el error de transporte sin reintentar', () async {
    final error = http.ClientException('Fallo simulado');
    responder = (_) async => throw error;
    await expectLater(api.crearViaje(solicitudBase()), throwsA(same(error)));
    expect(llamadas, 1);
  });
}
