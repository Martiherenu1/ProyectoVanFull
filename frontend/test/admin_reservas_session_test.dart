import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/admin/consultar_reservas_admin_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'services/admin/reservas_admin_api_test.dart' as datos;

Future<void> login(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'admin@vanfull.test');
  await tester.enterText(find.byType(TextField).at(1), 'clave');
  await tester.tap(find.text('Ingresar'));
  await tester.pumpAndSettle();
}

void main() {
  for (final status in [200, 401, 403, 500]) {
    testWidgets('consulta autenticada $status, detalle local y reintento', (
      tester,
    ) async {
      var consultas = 0;
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
        if (r.url.path.endsWith('/reservas')) {
          consultas++;
          expect(r.method, 'GET');
          expect(r.headers['authorization'], 'Bearer token');
          final codigo = consultas == 1 ? status : 200;
          return http.Response(
            jsonEncode(
              codigo == 200
                  ? [datos.reservaJson()]
                  : {
                      'error': {
                        'codigo': 'ERROR',
                        'mensaje': 'Error informado',
                      },
                    },
            ),
            codigo,
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
      await tester.tap(find.byKey(const Key('admin-consultar-reservas')));
      await tester.pumpAndSettle();
      if (status == 401) {
        expect(find.text('Ingresar'), findsOneWidget);
        return;
      }
      if (status == 403) {
        expect(find.byKey(const Key('admin-acceso-denegado')), findsOneWidget);
        return;
      }
      if (status == 500) {
        expect(find.text('Error informado'), findsOneWidget);
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('Pasajero: 5'), findsOneWidget);
      final antes = consultas;
      await tester.tap(find.byKey(const Key('reserva-7')));
      await tester.pumpAndSettle();
      expect(find.text('Pasajero: 5'), findsOneWidget);
      expect(consultas, antes);
    });
  }
  for (final status in [200, 401, 403]) {
    testWidgets('respuesta $status de sesión anterior no afecta siguiente', (
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
        if (r.url.path.endsWith('/reservas')) {
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
      await tester.tap(find.byKey(const Key('admin-consultar-reservas')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final consulta = tester
          .widget<ConsultarReservasAdminScreen>(
            find.byType(ConsultarReservasAdminScreen),
          )
          .consulta;
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin-salir')));
      await tester.pumpAndSettle();
      await login(tester);
      pendiente.complete(
        http.Response(
          jsonEncode(
            status == 200
                ? [datos.reservaJson()]
                : {
                    'error': {'codigo': 'ERROR', 'mensaje': 'Anterior'},
                  },
          ),
          status,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('admin-consultar-reservas')), findsOneWidget);
      expect(find.byKey(const Key('reserva-7')), findsNothing);
      expect(find.byKey(const Key('admin-acceso-denegado')), findsNothing);
      await expectLater(consulta.listar(), throwsStateError);
      expect(consultas, 1);
    });
  }
}
