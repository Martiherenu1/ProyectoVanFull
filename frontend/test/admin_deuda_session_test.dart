import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/admin/consultar_deuda_admin_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<void> login(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'admin@vanfull.test');
  await tester.enterText(find.byType(TextField).at(1), 'clave');
  await tester.tap(find.text('Ingresar'));
  await tester.pumpAndSettle();
}

void main() {
  for (final status in [200, 401, 403, 404]) {
    testWidgets('consulta administrativa HTTP $status en sesión vigente', (
      tester,
    ) async {
      final transporte = MockClient((r) async {
        if (r.url.path.endsWith('/auth/login')) {
          return http.Response(
            jsonEncode({
              'access_token': 'token',
              'token_type': 'bearer',
              'roles': ['administrador'],
            }),
            200,
          );
        }
        if (r.url.path.endsWith('/clientes/12/deuda')) {
          expect(r.headers['authorization'], 'Bearer token');
          return http.Response(
            jsonEncode(
              status == 200
                  ? {'saldo': 120.25, 'estado': 'con_deuda'}
                  : {
                      'error': {
                        'codigo': status == 404
                            ? 'CLIENTE_NO_ENCONTRADO'
                            : 'SIN_PERMISO',
                        'mensaje': 'Cliente no encontrado',
                      },
                    },
            ),
            status,
          );
        }
        return http.Response('[]', 200);
      });
      await tester.pumpWidget(
        VanFullBootstrap(
          apiBaseUrl: 'https://vanfull.test/api/',
          crearTransporte: () => transporte,
        ),
      );
      await login(tester);
      await tester.tap(find.byKey(const Key('admin-consultar-deuda')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('deuda-id-cliente')), '12');
      await tester.tap(find.byKey(const Key('consultar-deuda-admin')));
      await tester.pumpAndSettle();
      if (status == 200) {
        expect(find.text('Cliente 12'), findsOneWidget);
        expect(find.text(r'Saldo deudor: $ 120,25'), findsOneWidget);
      } else if (status == 404) {
        expect(find.text('Cliente no encontrado'), findsOneWidget);
      } else if (status == 401) {
        expect(find.text('Ingresar'), findsOneWidget);
      } else {
        expect(find.byKey(const Key('admin-acceso-denegado')), findsOneWidget);
      }
    });
  }
  for (final status in [200, 401, 403]) {
    testWidgets('respuesta tardía $status no afecta sesión siguiente', (
      tester,
    ) async {
      final pendiente = Completer<http.Response>();
      var logins = 0;
      var consultas = 0;
      final transporte = MockClient((r) async {
        if (r.url.path.endsWith('/auth/login')) {
          return http.Response(
            jsonEncode({
              'access_token': 'token-${++logins}',
              'token_type': 'bearer',
              'roles': ['administrador'],
            }),
            200,
          );
        }
        if (r.url.path.endsWith('/auth/logout')) return http.Response('', 204);
        if (r.url.path.endsWith('/clientes/12/deuda')) {
          consultas++;
          return pendiente.future;
        }
        return http.Response('[]', 200);
      });
      await tester.pumpWidget(
        VanFullBootstrap(
          apiBaseUrl: 'https://vanfull.test/api/',
          crearTransporte: () => transporte,
        ),
      );
      await login(tester);
      await tester.tap(find.byKey(const Key('admin-consultar-deuda')));
      await tester.pumpAndSettle();
      final consulta = tester
          .widget<ConsultarDeudaAdminScreen>(
            find.byType(ConsultarDeudaAdminScreen),
          )
          .consulta;
      final operacion = consulta.consultar(12);
      final expectativa = expectLater(operacion, throwsA(anything));
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin-salir')));
      await tester.pumpAndSettle();
      await login(tester);
      pendiente.complete(
        http.Response(
          jsonEncode(
            status == 200
                ? {'saldo': 120, 'estado': 'con_deuda'}
                : {
                    'error': {'codigo': 'ERROR', 'mensaje': 'Anterior'},
                  },
          ),
          status,
        ),
      );
      await tester.pumpAndSettle();
      // Errores HTTP se propagan, pero no invalidan ni deniegan la cuenta siguiente.
      await expectativa;
      expect(find.byKey(const Key('admin-consultar-deuda')), findsOneWidget);
      expect(find.byKey(const Key('admin-acceso-denegado')), findsNothing);
      await expectLater(consulta.consultar(12), throwsStateError);
      expect(consultas, 1);
    });
  }
}
