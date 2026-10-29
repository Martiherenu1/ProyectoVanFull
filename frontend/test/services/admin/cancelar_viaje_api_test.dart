import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';
import 'package:frontend/services/admin/viajes_admin_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'viajes_admin_api_test.dart' as datos;

void main() {
  test('POST cancelación reutiliza token y modelo', () async {
    final api = ViajesAdminApi(
      HttpApiClient(
        baseUri: Uri.parse('https://vanfull.test/api/'),
        accessTokenProvider: () => 'sesion',
        transport: MockClient((r) async {
          expect(r.method, 'POST');
          expect(r.url.path, '/api/viajes/10/cancelacion');
          expect(r.headers['authorization'], 'Bearer sesion');
          return http.Response(
            jsonEncode({...datos.viajeCreado(), 'estado': 'cancelado'}),
            200,
          );
        }),
      ),
    );
    expect((await api.cancelarViaje(10)).estado, EstadoViaje.cancelado);
  });
  for (final codigo in [
    'ESTADO_VIAJE_INVALIDO',
    'VIAJE_CON_COMPROMISOS',
    'NO_AUTENTICADO',
  ]) {
    test('propaga $codigo', () async {
      final api = ViajesAdminApi(
        HttpApiClient(
          baseUri: Uri.parse('https://vanfull.test/api/'),
          transport: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'error': {'codigo': codigo, 'mensaje': codigo},
              }),
              codigo == 'NO_AUTENTICADO' ? 401 : 409,
            ),
          ),
        ),
      );
      await expectLater(
        api.cancelarViaje(10),
        throwsA(isA<ApiException>().having((e) => e.codigo, 'codigo', codigo)),
      );
    });
  }
}
