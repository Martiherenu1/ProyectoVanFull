import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/services/admin/deuda_admin_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  DeudaAdminApi api(Future<http.Response> Function(http.Request) responder) =>
      DeudaAdminApi(
        HttpApiClient(
          baseUri: Uri.parse('https://vanfull.test/api/'),
          accessTokenProvider: () => 'token',
          transport: MockClient(responder),
        ),
      );
  test('consulta cliente elegido con token y modelo Deuda', () async {
    final deuda = await api((r) async {
      expect(r.method, 'GET');
      expect(r.url.path, '/api/clientes/12/deuda');
      expect(r.headers['authorization'], 'Bearer token');
      return http.Response('{"saldo":120.25,"estado":"con_deuda"}', 200);
    }).consultar(12);
    expect(deuda.saldo, 120.25);
    expect(deuda.estado.valorApi, 'con_deuda');
  });
  test('sin cuenta acepta cero informado', () async {
    final deuda = await api(
      (_) async => http.Response('{"saldo":0.0,"estado":"al_dia"}', 200),
    ).consultar(12);
    expect(deuda.saldo, 0);
    expect(deuda.estado.valorApi, 'al_dia');
  });
  for (final caso in [
    (401, 'NO_AUTENTICADO'),
    (403, 'SIN_PERMISO'),
    (404, 'CLIENTE_NO_ENCONTRADO'),
  ]) {
    test('propaga ${caso.$2}', () async {
      await expectLater(
        api(
          (_) async => http.Response(
            jsonEncode({
              'error': {'codigo': caso.$2, 'mensaje': 'Mensaje informado'},
            }),
            caso.$1,
          ),
        ).consultar(12),
        throwsA(isA<ApiException>().having((e) => e.codigo, 'codigo', caso.$2)),
      );
    });
  }
  for (final cuerpo in [
    'null',
    '{}',
    '{"saldo":-1,"estado":"al_dia"}',
    '{"saldo":0,"estado":"otro"}',
  ]) {
    test('rechaza respuesta inválida $cuerpo', () async {
      await expectLater(
        api((_) async => http.Response(cuerpo, 200)).consultar(12),
        throwsA(isA<ApiProtocolException>()),
      );
    });
  }
  test('id inválido no hace HTTP', () async {
    await expectLater(
      api((_) async => fail('HTTP inesperado')).consultar(0),
      throwsArgumentError,
    );
  });
}
