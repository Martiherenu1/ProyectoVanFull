import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/gps/ubicacion_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'admin_deuda_session_test.dart' show login;
import 'screens/admin/registrar_pago_admin_screen_test.dart' as formulario;
import 'services/admin/registro_pagos_admin_api_test.dart' as pagos;
import 'services/admin/viajes_dia_admin_api_test.dart' as viajes;

Future<void> abrir(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  for (final decision in ['CONFIRMADO', 'RECHAZADO']) {
    testWidgets(
      'UI registro→pendientes→$decision→deuda con sesión compartida',
      (tester) async {
        Map<String, dynamic>? pago;
        var saldoInformado = 2000.0;
        final operaciones = <String>[];
        final transporte = MockClient((r) async {
          final path = r.url.path;
          if (path.endsWith('/auth/login')) {
            return http.Response(
              jsonEncode({
                'access_token': 'token-admin',
                'token_type': 'bearer',
                'roles': ['administrador'],
              }),
              200,
            );
          }
          expect(r.headers['authorization'], 'Bearer token-admin');
          if (path.endsWith('/viajes') && r.method == 'GET') {
            return http.Response('[]', 200);
          }
          operaciones.add('${r.method} $path');
          if (path.endsWith('/clientes/12/deuda')) {
            return http.Response(
              jsonEncode({'saldo': saldoInformado, 'estado': 'con_deuda'}),
              200,
            );
          }
          if (path.endsWith('/pagos') && r.method == 'POST') {
            expect(jsonDecode(r.body), {
              'id_cliente': 12,
              'importe': 1250.5,
              'medio_pago': 'TRANSFERENCIA',
            });
            pago = pagos.pagoRegistrado();
            return http.Response(jsonEncode(pago), 201);
          }
          if (path.endsWith('/pagos/pendientes')) {
            return http.Response(
              jsonEncode(pago?['estado'] == 'PENDIENTE' ? [pago] : []),
              200,
            );
          }
          if (path.endsWith('/pagos/5/confirmacion')) {
            expect(r.method, 'POST');
            expect(jsonDecode(r.body), {'decision': decision});
            pago = {...pago!, 'estado': decision};
            // Respuestas suministradas por el backend simulado; la UI no calcula deuda.
            saldoInformado = decision == 'CONFIRMADO' ? 749.5 : 2000.0;
            return http.Response(jsonEncode(pago), 200);
          }
          fail('Petición inesperada: ${r.method} $path');
        });
        await tester.pumpWidget(
          VanFullBootstrap(
            apiBaseUrl: 'https://vanfull.test/api/',
            crearTransporte: () => transporte,
          ),
        );
        await login(tester);
        Future<void> consultarDeuda() async {
          await abrir(tester, 'admin-consultar-deuda');
          await tester.enterText(
            find.byKey(const Key('deuda-id-cliente')),
            '12',
          );
          await abrir(tester, 'consultar-deuda-admin');
        }

        await consultarDeuda();
        expect(find.text(r'Saldo deudor: $ 2.000,00'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await abrir(tester, 'admin-registrar-pago');
        await formulario.completarRegistro(tester);
        expect(operaciones.where((o) => o == 'POST /api/pagos'), isEmpty);
        await formulario.confirmarRegistro(tester);
        expect(
          find.text('Pago 5 registrado para el cliente 12.'),
          findsOneWidget,
        );
        expect(find.text('Estado: Pendiente'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await abrir(tester, 'admin-pagos-pendientes');
        expect(find.text('Pago 5 · Cliente 12'), findsOneWidget);
        final accion = decision == 'CONFIRMADO' ? 'confirmar' : 'rechazar';
        await abrir(tester, '$accion-pago-5');
        await abrir(tester, 'confirmar-decision-pago');
        expect(find.text('No hay pagos pendientes.'), findsOneWidget);
        expect(
          find.text(
            'Pago 5: ${decision == 'CONFIRMADO' ? 'Confirmado' : 'Rechazado'}.',
          ),
          findsOneWidget,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        await consultarDeuda();
        expect(
          find.text(
            decision == 'CONFIRMADO'
                ? r'Saldo deudor: $ 749,50'
                : r'Saldo deudor: $ 2.000,00',
          ),
          findsOneWidget,
        );
        expect(operaciones, [
          'GET /api/clientes/12/deuda',
          'POST /api/pagos',
          'GET /api/pagos/pendientes',
          'POST /api/pagos/5/confirmacion',
          'GET /api/pagos/pendientes',
          'GET /api/clientes/12/deuda',
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('edición UI usa PATCH autenticado y renueva detalle/listado', (
    tester,
  ) async {
    var viaje = viajes.viaje(41);
    var listados = 0;
    var actualizaciones = 0;
    final transporte = MockClient((r) async {
      if (r.url.path.endsWith('/auth/login')) {
        return http.Response(
          jsonEncode({
            'access_token': 'token-admin',
            'token_type': 'bearer',
            'roles': ['administrador'],
          }),
          200,
        );
      }
      expect(r.headers['authorization'], 'Bearer token-admin');
      if (r.url.path.endsWith('/viajes') && r.method == 'GET') {
        listados++;
        return http.Response(jsonEncode([viaje]), 200);
      }
      if (r.url.path.endsWith('/viajes/41') && r.method == 'PATCH') {
        actualizaciones++;
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        expect(body, {
          'fecha': '2026-10-30',
          'horario': '09:15',
          'sentido': 'IDA',
          'capacidad_planificada': null,
          'id_chofer': 5,
          'id_vehiculo': 4,
        });
        viaje = {...viaje, ...body};
        return http.Response(jsonEncode(viaje), 200);
      }
      if (r.url.path.endsWith('/viajes/41/ubicacion')) {
        return http.Response(
          '{"error":{"codigo":"UBICACION_NO_DISPONIBLE","mensaje":"Sin posición de prueba"}}',
          404,
        );
      }
      fail('Petición inesperada: ${r.method} ${r.url.path}');
    });
    await tester.pumpWidget(
      VanFullBootstrap(
        apiBaseUrl: 'https://vanfull.test/api/',
        crearTransporte: () => transporte,
      ),
    );
    await login(tester);
    await tester.tap(find.text('41'));
    await tester.pumpAndSettle();
    await abrir(tester, 'editar-viaje');
    await tester.enterText(find.byKey(const Key('editar-horario')), '09:15');
    await tester.ensureVisible(find.byKey(const Key('guardar-viaje')));
    await abrir(tester, 'guardar-viaje');
    expect(find.text('Horario: 09:15'), findsOneWidget);
    expect(actualizaciones, 1);
    expect(listados, 2);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    // La navegación administrativa existente también abre la ubicación del viaje.
    if (find.byType(UbicacionScreen).evaluate().isNotEmpty) {
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    expect(find.text('09:15'), findsOneWidget);
    expect(find.text('07:30'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
