import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/models/admin/abono_gestion.dart';
import 'package:frontend/services/admin/abonos_admin_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> abonoJson({int id = 5}) => {
  'id_abono_mensual': id,
  'id_contratacion': 9,
  'id_pasajero': 3,
  'nombre': 'Ana',
  'apellido': 'Abono',
  'id_servicio': 2,
  'tipo_servicio': 'LABORAL',
  'modalidad': 'IDA_VUELTA',
  'dias_semanales': 'L,M,X,J,V',
  'importe_acordado': 45000.5,
  'estado': 'activo',
  'periodos': [
    {'id_periodo_abono': 1, 'periodo': '2026-11', 'estado': 'vigente'},
  ],
};

void main() {
  AbonosAdminApi api(Future<http.Response> Function(http.Request) responder) =>
      AbonosAdminApi(
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

  test('listar lee abonos y períodos', () async {
    final lista = await api((r) async {
      expect(r.method, 'GET');
      expect(r.url.path, '/api/administracion/abonos');
      expect(r.url.query, isEmpty);
      expect(r.headers['authorization'], 'Bearer token');
      return json({
        'items': [abonoJson()],
        'total': 1,
      });
    }).listar();
    expect(lista.single.pasajero, 'Ana Abono');
    expect(lista.single.importeAcordado, 45000.5);
    expect(lista.single.periodos.single.periodo, '2026-11');
  });

  test('listar por pasajero manda el filtro', () async {
    await api((r) async {
      expect(r.url.queryParameters, {'id_pasajero': '3'});
      return json({'items': [], 'total': 0});
    }).listar(idPasajero: 3);
  });

  test('un abono sin datos opcionales se lee igual', () async {
    final lista = await api(
      (_) async => json({
        'items': [
          abonoJson()
            ..remove('modalidad')
            ..remove('dias_semanales')
            ..remove('importe_acordado'),
        ],
        'total': 1,
      }),
    ).listar();
    expect(lista.single.modalidad, isNull);
    expect(lista.single.importeAcordado, isNull);
  });

  test('listar fuera de contrato es de protocolo', () {
    expect(
      api((_) async => json([1])).listar(),
      throwsA(isA<ApiProtocolException>()),
    );
  });

  test(
    'listarServicios lee la lista plana y marca los que admiten abono',
    () async {
      final servicios = await api((r) async {
        expect(r.url.path, '/api/servicios');
        return json([
          {'id_servicio': 1, 'tipo_servicio': 'UNIVERSITARIO'},
          {'id_servicio': 3, 'tipo_servicio': 'ESPECIAL'},
        ]);
      }).listarServicios();
      expect(servicios.map((s) => s.admiteAbono), [true, false]);
    },
  );

  test('crear manda solo lo informado', () async {
    final creado =
        await api((r) async {
          expect(r.method, 'POST');
          expect(r.url.path, '/api/administracion/abonos');
          expect(jsonDecode(r.body), {
            'id_pasajero': 3,
            'id_servicio': 2,
            'modalidad': 'IDA',
            'dias_semanales': 'M,J',
          });
          return json(abonoJson(id: 8), 201);
        }).crear(
          const AbonoGestionCreate(
            idPasajero: 3,
            idServicio: 2,
            modalidad: 'IDA',
            diasSemanales: 'M,J',
          ),
        );
    expect(creado.idAbonoMensual, 8);
  });

  test('crear con importe y período los incluye', () {
    const datos = AbonoGestionCreate(
      idPasajero: 3,
      idServicio: 2,
      modalidad: 'IDA_VUELTA',
      diasSemanales: 'L',
      importeAcordado: 100.5,
      periodo: '2026-12',
    );
    expect(datos.toJson()['importe_acordado'], 100.5);
    expect(datos.toJson()['periodo'], '2026-12');
  });

  test('modificar usa PATCH con los cambios', () async {
    await api((r) async {
      expect(r.method, 'PATCH');
      expect(r.url.path, '/api/administracion/abonos/5');
      expect(jsonDecode(r.body), {'modalidad': 'VUELTA'});
      return json(abonoJson());
    }).modificar(5, {'modalidad': 'VUELTA'});
  });

  test('agregarPeriodo manda el período', () async {
    await api((r) async {
      expect(r.method, 'POST');
      expect(r.url.path, '/api/administracion/abonos/5/periodos');
      expect(jsonDecode(r.body), {'periodo': '2026-12'});
      return json(abonoJson(), 201);
    }).agregarPeriodo(5, '2026-12');
  });

  test('un 409 PERIODO_DUPLICADO llega con su código', () async {
    final error = api(
      (_) async => json({
        'error': {'codigo': 'PERIODO_DUPLICADO', 'mensaje': 'x'},
      }, 409),
    ).agregarPeriodo(5, '2026-11');
    await expectLater(
      error,
      throwsA(
        isA<ApiException>()
            .having((e) => e.codigo, 'codigo', 'PERIODO_DUPLICADO')
            .having((e) => e.statusCode, 'statusCode', 409),
      ),
    );
  });

  test('una respuesta de abono fuera de contrato es de protocolo', () {
    expect(
      api((_) async => json({'id_abono_mensual': 1})).modificar(1, {}),
      throwsA(isA<ApiProtocolException>()),
    );
  });

  test('periodoValido exige AAAA-MM con mes de 01 a 12', () {
    expect(periodoValido('2026-11'), isTrue);
    expect(periodoValido('2026-12'), isTrue);
    expect(periodoValido('2026-13'), isFalse);
    expect(periodoValido('2026-00'), isFalse);
    expect(periodoValido('2026-1'), isFalse);
    expect(periodoValido('202611'), isFalse);
  });
}
