import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/services/admin/pagos_admin_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> pagoJson({String estado = 'PENDIENTE'}) => {
  'id_pago': 1,
  'id_cliente': 2,
  'importe': 1250.5,
  'medio_pago': 'TRANSFERENCIA',
  'estado': estado,
  'fecha_hora': '2026-10-29T10:00:00Z',
};

void main() {
  PagosAdminApi api(Future<http.Response> Function(http.Request) responder) =>
      PagosAdminApi(
        HttpApiClient(
          baseUri: Uri.parse('https://vanfull.test/api/'),
          accessTokenProvider: () => 'token',
          transport: MockClient(responder),
        ),
      );
  test('lista pendientes con token y campos administrativos', () async {
    final pagos = await api((r) async {
      expect(r.method, 'GET');
      expect(r.url.path, '/api/pagos/pendientes');
      expect(r.headers['authorization'], 'Bearer token');
      return http.Response(jsonEncode([pagoJson()]), 200);
    }).pendientes();
    expect(pagos.single.idCliente, 2);
    expect(pagos.single.importe, 1250.5);
    expect(pagos.single.fechaHora, DateTime.utc(2026, 10, 29, 10));
  });
  for (final decision in DecisionPago.values) {
    test('envía decisión ${decision.valorApi}', () async {
      final pago = await api((r) async {
        expect(r.method, 'POST');
        expect(r.url.path, '/api/pagos/1/confirmacion');
        expect(jsonDecode(r.body), {'decision': decision.valorApi});
        return http.Response(
          jsonEncode(pagoJson(estado: decision.valorApi)),
          200,
        );
      }).decidir(1, decision);
      expect(pago.estado.valorApi, decision.valorApi);
    });
  }
  for (final status in [401, 403, 404]) {
    test('propaga error $status', () async {
      await expectLater(
        api(
          (_) async => http.Response(
            jsonEncode({
              'error': {'codigo': 'ERROR', 'mensaje': 'Error informado'},
            }),
            status,
          ),
        ).decidir(1, DecisionPago.confirmar),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'status', status),
        ),
      );
    });
  }
  test('rechaza listado y pago malformados', () async {
    await expectLater(
      api((_) async => http.Response('{}', 200)).pendientes(),
      throwsA(isA<ApiProtocolException>()),
    );
    await expectLater(
      api((_) async => http.Response('{}', 200))
          .decidir(1, DecisionPago.confirmar),
      throwsA(isA<ApiProtocolException>()),
    );
  });
}
