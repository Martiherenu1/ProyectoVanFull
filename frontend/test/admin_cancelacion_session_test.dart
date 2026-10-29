import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/admin/viajes_dia_admin_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'services/admin/viajes_admin_api_test.dart' as datos;

void main() {
  for (final estado in [200, 401]) {
    testWidgets('respuesta tardía $estado no afecta otra sesión', (
      tester,
    ) async {
      var logins = 0;
      final pendiente = Completer<http.Response>();
      final client = MockClient((r) async {
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
        if (r.url.path.endsWith('/cancelacion')) return pendiente.future;
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
          crearTransporte: () => client,
        ),
      );
      await login();
      final cancelar = tester
          .widget<ViajesDiaAdminScreen>(find.byType(ViajesDiaAdminScreen))
          .cancelarViaje!;
      final operacion = cancelar(10);
      final expectativa = expectLater(operacion, throwsA(anything));
      await tester.pump();
      await tester.tap(find.byKey(const Key('admin-salir')));
      await tester.pumpAndSettle();
      await login();
      pendiente.complete(
        http.Response(
          jsonEncode(
            estado == 200
                ? {...datos.viajeCreado(), 'estado': 'cancelado'}
                : {
                    'error': {
                      'codigo': 'NO_AUTENTICADO',
                      'mensaje': 'Sesión vencida',
                    },
                  },
          ),
          estado,
        ),
      );
      await tester.pumpAndSettle();
      await expectativa;
      expect(logins, 2);
      expect(find.byType(ViajesDiaAdminScreen), findsOneWidget);
      await expectLater(cancelar(10), throwsStateError);
    });
  }
}
