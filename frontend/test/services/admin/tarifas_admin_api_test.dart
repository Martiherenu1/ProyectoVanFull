import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/models/admin/tarifa_gestion.dart';
import 'package:frontend/services/admin/tarifas_admin_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> tarifaJson({
  int id = 3,
  String? tipo = 'OCASIONAL',
  String? vigencia,
}) => {
  'id_tarifa': id,
  'nombre': 'Universitario ida',
  'tipo': ?tipo,
  'importe': 1500.5,
  'fecha_creacion': '2026-11-18',
  'fecha_vigencia': ?vigencia,
};

void main() {
  TarifasAdminApi api(Future<http.Response> Function(http.Request) responder) =>
      TarifasAdminApi(
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

  test('listar: GET autenticado a /administracion/tarifas', () async {
    final lista = await api((r) async {
      expect(r.method, 'GET');
      expect(r.url.path, '/api/administracion/tarifas');
      expect(r.headers['authorization'], 'Bearer token');
      return json({
        'items': [tarifaJson(), tarifaJson(id: 4, tipo: null)],
        'total': 2,
      });
    }).listar();
    expect(lista, hasLength(2));
    expect(lista.first.importe, 1500.5);
    expect(lista.last.tipo, isNull);
  });

  test('listar: respuesta fuera de contrato es de protocolo', () {
    expect(
      api((_) async => json([1])).listar(),
      throwsA(isA<ApiProtocolException>()),
    );
  });

  test('crear: POST sin opcionales vacíos', () async {
    final creada =
        await api((r) async {
          expect(r.method, 'POST');
          expect(r.url.path, '/api/administracion/tarifas');
          final cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
          expect(cuerpo, {'nombre': 'Universitario ida', 'importe': 1500.5});
          return json(tarifaJson(tipo: null), 201);
        }).crear(
          const TarifaGestionCreate(
            nombre: 'Universitario ida',
            importe: 1500.5,
            tipo: '',
            fechaVigencia: '',
          ),
        );
    expect(creada.idTarifa, 3);
  });

  test('modificar: PATCH con null para vaciar un campo', () async {
    await api((r) async {
      expect(r.method, 'PATCH');
      expect(r.url.path, '/api/administracion/tarifas/3');
      expect(jsonDecode(r.body), {'importe': 2000.0, 'tipo': null});
      return json(tarifaJson());
    }).modificar(3, {'importe': 2000.0, 'tipo': null});
  });

  test('un 404 llega como ApiException con su código', () async {
    final error = api(
      (_) async => json({
        'error': {'codigo': 'TARIFA_NO_ENCONTRADA', 'mensaje': 'No existe.'},
      }, 404),
    ).modificar(99, {'nombre': 'X'});
    await expectLater(
      error,
      throwsA(
        isA<ApiException>().having(
          (e) => e.codigo,
          'codigo',
          'TARIFA_NO_ENCONTRADA',
        ),
      ),
    );
  });
}
