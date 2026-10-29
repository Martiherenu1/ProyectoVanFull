import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/admin/borrador_imputacion_pago.dart';
import 'package:frontend/models/pasajero/pago.dart';
import 'package:frontend/services/admin/registro_pagos_admin_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> pagoRegistrado() => {
  'id_pago': 5,
  'id_cliente': 12,
  'importe': 1250.5,
  'medio_pago': 'TRANSFERENCIA',
  'estado': 'PENDIENTE',
  'fecha_hora': '2026-10-29T10:00:00Z',
};
void main() {
  RegistroPagosAdminApi api(
    Future<http.Response> Function(http.Request) responder,
  ) => RegistroPagosAdminApi(
    HttpApiClient(
      baseUri: Uri.parse('https://vanfull.test/api/'),
      transport: MockClient(responder),
      accessTokenProvider: () => 'token-admin',
    ),
  );
  for (final medio in [MedioPago.transferencia, MedioPago.billetera]) {
    test(
      'registra ${medio.valorApi} con destinatario y token sin campos no persistibles',
      () async {
        final pago = await api((r) async {
          expect(r.method, 'POST');
          expect(r.url.path, '/api/pagos');
          expect(r.headers['authorization'], 'Bearer token-admin');
          expect(jsonDecode(r.body), {
            'id_cliente': 12,
            'importe': 1250.5,
            'medio_pago': medio.valorApi,
          });
          return http.Response(
            jsonEncode({...pagoRegistrado(), 'medio_pago': medio.valorApi}),
            201,
          );
        }).registrar(idCliente: 12, importe: 1250.5, medio: medio);
        expect(pago.idPago, 5);
        expect(pago.estado, EstadoPago.pendiente);
      },
    );
  }
  for (final codigo in [
    'CLIENTE_NO_ENCONTRADO',
    'CUENTA_CORRIENTE_NO_ENCONTRADA',
    'VALIDACION',
    'SIN_PERMISO',
    'NO_AUTENTICADO',
  ]) {
    test('propaga $codigo', () async {
      final status = codigo == 'VALIDACION'
          ? 400
          : codigo == 'SIN_PERMISO'
          ? 403
          : codigo == 'NO_AUTENTICADO'
          ? 401
          : 404;
      await expectLater(
        api(
          (_) async => http.Response(
            jsonEncode({
              'error': {'codigo': codigo, 'mensaje': codigo},
            }),
            status,
          ),
        ).registrar(idCliente: 12, importe: 1, medio: MedioPago.transferencia),
        throwsA(isA<ApiException>().having((e) => e.codigo, 'codigo', codigo)),
      );
    });
  }
  test('rechaza efectivo y borradores sin enviarlos ni perder datos', () async {
    var llamadas = 0;
    final cliente = api((_) async {
      llamadas++;
      return http.Response('{}', 201);
    });
    await expectLater(
      cliente.registrar(idCliente: 12, importe: 1, medio: MedioPago.efectivo),
      throwsUnsupportedError,
    );
    for (final borrador in [
      const BorradorImputacionPago(tipo: TipoPagoBorrador.senia),
      const BorradorImputacionPago(evidencia: 'referencia'),
    ]) {
      await expectLater(
        cliente.registrar(
          idCliente: 12,
          importe: 1,
          medio: MedioPago.transferencia,
          borrador: borrador,
        ),
        throwsUnsupportedError,
      );
    }
    expect(llamadas, 0);
  });
  test('rechaza datos inválidos y respuesta de otro cliente', () async {
    var llamadas = 0;
    final cliente = api((_) async {
      llamadas++;
      return http.Response(
        jsonEncode({...pagoRegistrado(), 'id_cliente': 99}),
        201,
      );
    });
    await expectLater(
      cliente.registrar(
        idCliente: 0,
        importe: 1,
        medio: MedioPago.transferencia,
      ),
      throwsArgumentError,
    );
    await expectLater(
      cliente.registrar(
        idCliente: 12,
        importe: double.nan,
        medio: MedioPago.transferencia,
      ),
      throwsArgumentError,
    );
    expect(llamadas, 0);
    await expectLater(
      cliente.registrar(
        idCliente: 12,
        importe: 1,
        medio: MedioPago.transferencia,
      ),
      throwsA(isA<ApiProtocolException>()),
    );
  });
}
