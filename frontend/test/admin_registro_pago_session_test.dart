import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/admin/registrar_pago_admin_screen.dart';
import 'package:frontend/screens/admin/viajes_dia_admin_screen.dart';
import 'package:frontend/models/pasajero/pago.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'services/admin/registro_pagos_admin_api_test.dart' as datos;

void main() {
  for (final estado in [201, 401, 403]) {
    testWidgets('registro tardío $estado no afecta a la cuenta siguiente', (
      tester,
    ) async {
      var logins = 0;
      var registros = 0;
      final pendiente = Completer<http.Response>();
      final transporte = MockClient((r) async {
        if (r.url.path.endsWith('/auth/login')) {
          logins++;
          return http.Response(
            jsonEncode({
              'access_token': 'token-$logins',
              'token_type': 'bearer',
              'roles': ['administrador'],
            }),
            200,
          );
        }
        if (r.url.path.endsWith('/auth/logout')) return http.Response('', 204);
        if (r.url.path.endsWith('/pagos')) {
          registros++;
          return pendiente.future;
        }
        return http.Response('[]', 200);
      });
      Future<void> login() async {
        await tester.enterText(
          find.byType(TextField).at(0),
          'admin@vanfull.test',
        );
        await tester.enterText(find.byType(TextField).at(1), 'clave');
        await tester.tap(find.text('Ingresar'));
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        VanFullBootstrap(
          apiBaseUrl: 'https://vanfull.test/api/',
          crearTransporte: () => transporte,
        ),
      );
      await login();
      await tester.tap(find.byKey(const Key('admin-registrar-pago')));
      await tester.pumpAndSettle();
      final registrar = tester
          .widget<RegistrarPagoAdminScreen>(
            find.byType(RegistrarPagoAdminScreen),
          )
          .registrar;
      final operacion = registrar(
        idCliente: 12,
        importe: 1250.5,
        medio: MedioPago.transferencia,
      );
      final expectativa = expectLater(operacion, throwsA(anything));
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin-salir')));
      await tester.pumpAndSettle();
      await login();
      pendiente.complete(
        http.Response(
          jsonEncode(
            estado == 201
                ? datos.pagoRegistrado()
                : {
                    'error': {
                      'codigo': 'ERROR',
                      'mensaje': 'Error de otra sesión',
                    },
                  },
          ),
          estado,
        ),
      );
      await tester.pumpAndSettle();
      await expectativa;
      expect(find.byType(ViajesDiaAdminScreen), findsOneWidget);
      expect(find.byKey(const Key('admin-acceso-denegado')), findsNothing);
      await expectLater(
        registrar(idCliente: 12, importe: 1, medio: MedioPago.transferencia),
        throwsStateError,
      );
      expect(registros, 1);
    });
  }
}
