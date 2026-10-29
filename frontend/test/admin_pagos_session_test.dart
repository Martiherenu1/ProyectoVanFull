import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/admin/pagos_pendientes_screen.dart';
import 'package:frontend/services/admin/pagos_admin_api.dart';
import 'package:frontend/screens/admin/viajes_dia_admin_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'services/admin/pagos_admin_api_test.dart' as datos;

void main() {
  for (final estado in [200, 401, 403]) {
    testWidgets('decisión tardía $estado no afecta la sesión siguiente', (
      tester,
    ) async {
      final pendiente = Completer<http.Response>();
      var logins = 0;
      var envios = 0;
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
        if (r.url.path.endsWith('/confirmacion')) {
          envios++;
          return pendiente.future;
        }
        if (r.url.path.endsWith('/pagos/pendientes')) {
          return http.Response(jsonEncode([datos.pagoJson()]), 200);
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
      await tester.tap(find.byKey(const Key('admin-pagos-pendientes')));
      await tester.pumpAndSettle();
      final decidir = tester
          .widget<PagosPendientesScreen>(find.byType(PagosPendientesScreen))
          .decidir;
      final operacion = decidir(1, DecisionPago.confirmar);
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
            estado == 200
                ? datos.pagoJson(estado: 'CONFIRMADO')
                : {
                    'error': {
                      'codigo': 'ERROR',
                      'mensaje': 'Error de la cuenta anterior',
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
      await expectLater(decidir(1, DecisionPago.rechazar), throwsStateError);
      expect(envios, 1);
    });
  }
}
