import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/admin/vehiculos_admin_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'admin_vehiculos_session_test.dart' as base;
import 'services/admin/vehiculos_admin_api_test.dart' as datos;

http.Response fallo(int status) => http.Response(
  jsonEncode({
    'error': {'codigo': 'PRUEBA', 'mensaje': 'Error informado'},
  }),
  status,
);

http.Response ingreso(List<String> roles, [String token = 'dueno-token']) =>
    http.Response(
      jsonEncode({
        'access_token': token,
        'token_type': 'bearer',
        'roles': roles,
      }),
      200,
    );

Future<void> montar(WidgetTester tester, http.Client transporte) =>
    tester.pumpWidget(
      VanFullBootstrap(
        apiBaseUrl: 'https://vanfull.test/api/',
        crearTransporte: () => transporte,
      ),
    );

void main() {
  for (final status in [200, 401, 403, 500]) {
    testWidgets(
      'dueño consulta vehículos HTTP $status desde su entrada vigente',
      (t) async {
        var consultas = 0;
        final otras = <String>[];
        final transporte = MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) return ingreso(['dueno']);
          if (r.url.path.endsWith('/vehiculos')) {
            consultas++;
            expect(r.headers['authorization'], 'Bearer dueno-token');
            final codigo = consultas == 1 ? status : 200;
            return codigo == 200
                ? http.Response(jsonEncode([datos.vehiculo()]), 200)
                : fallo(codigo);
          }
          if (r.url.path.endsWith('/viajes')) return http.Response('[]', 200);
          otras.add(r.url.path);
          return http.Response('[]', 200);
        });
        await montar(t, transporte);
        await base.login(t);
        await t.tap(find.byKey(const Key('admin-vehiculos')));
        await t.pumpAndSettle();
        if (status == 401) {
          expect(find.text('Ingresar'), findsOneWidget);
        } else if (status == 403) {
          expect(
            find.byKey(const Key('admin-acceso-denegado')),
            findsOneWidget,
          );
          expect(find.text('Ingresar'), findsNothing);
        } else {
          if (status == 500) {
            await t.tap(find.text('Reintentar'));
            await t.pumpAndSettle();
          }
          expect(find.text('VF022AA'), findsOneWidget);
          expect(find.byKey(const Key('vehiculo-1')), findsOneWidget);
        }
        expect(otras, isEmpty);
        if (status == 200 || status == 500) {
          await t.pageBack();
          await t.pumpAndSettle();
          expect(find.byKey(const Key('admin-crear-viaje')), findsOneWidget);
          expect(
            find.byKey(const Key('admin-administradores')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('admin-tarifas')), findsOneWidget);
          expect(find.byKey(const Key('admin-recorridos')), findsOneWidget);
          expect(
            find.byKey(const Key('admin-historial-viajes')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('admin-abonos')), findsOneWidget);
        }
      },
    );
  }

  testWidgets(
    'dueño registra y modifica usando su token y contrato existente',
    (t) async {
      final metodos = <String>[];
      Map<String, dynamic>? guardado;
      final transporte = MockClient((r) async {
        if (r.url.path.endsWith('/auth/login')) return ingreso(['dueno']);
        if (r.url.path.endsWith('/viajes')) return http.Response('[]', 200);
        expect(r.url.path, startsWith('/api/vehiculos'));
        expect(r.headers['authorization'], 'Bearer dueno-token');
        metodos.add(r.method);
        if (r.method == 'GET') return http.Response('[]', 200);
        final cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
        guardado = {...datos.vehiculo(), ...?guardado, ...cuerpo};
        return http.Response(
          jsonEncode(guardado),
          r.method == 'POST' ? 201 : 200,
        );
      });
      await montar(t, transporte);
      await base.login(t);
      await t.tap(find.byKey(const Key('admin-vehiculos')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('registrar-vehiculo')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('vehiculo-patente')), 'VF022DD');
      await t.enterText(find.byKey(const Key('vehiculo-capacidad')), '19');
      await t.tap(find.byKey(const Key('guardar-vehiculo')));
      await t.pumpAndSettle();
      expect(find.text('VF022DD'), findsOneWidget);
      await t.tap(find.byKey(const Key('editar-vehiculo-1')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('vehiculo-capacidad')), '20');
      await t.tap(find.byKey(const Key('guardar-vehiculo')));
      await t.pumpAndSettle();
      expect(guardado?['capacidad'], 20);
      expect(metodos, ['GET', 'POST', 'PATCH']);
    },
  );

  for (final status in [200, 401, 403]) {
    testWidgets(
      'respuesta $status del dueño anterior no afecta al administrador',
      (t) async {
        final pendiente = Completer<http.Response>();
        var logins = 0;
        var consultas = 0;
        final transporte = MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            logins++;
            return ingreso([
              logins == 1 ? 'dueno' : 'administrador',
            ], 'token-$logins');
          }
          if (r.url.path.endsWith('/auth/logout')) {
            return http.Response('', 204);
          }
          if (r.url.path.endsWith('/vehiculos')) {
            consultas++;
            return pendiente.future;
          }
          return http.Response('[]', 200);
        });
        await montar(t, transporte);
        await t.enterText(find.byType(TextField).at(0), 'dueno@vanfull.test');
        await t.enterText(find.byType(TextField).at(1), 'clave');
        await t.tap(find.text('Ingresar'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        await t.tap(find.byKey(const Key('admin-vehiculos')));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        final cargar = t
            .widget<VehiculosAdminScreen>(find.byType(VehiculosAdminScreen))
            .cargar;
        await t.pageBack();
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('admin-salir')));
        await t.pumpAndSettle();
        await base.login(t);
        pendiente.complete(
          status == 200
              ? http.Response(jsonEncode([datos.vehiculo()]), 200)
              : fallo(status),
        );
        await t.pumpAndSettle();
        expect(find.byKey(const Key('admin-vehiculos')), findsOneWidget);
        expect(find.text('VF022AA'), findsNothing);
        expect(find.text('Ingresar'), findsNothing);
        expect(find.byKey(const Key('admin-acceso-denegado')), findsNothing);
        await expectLater(cargar(), throwsStateError);
        expect(consultas, 1);
      },
    );
  }

  testWidgets('no elige permisos automáticamente entre dueño y administrador', (
    t,
  ) async {
    var consultas = 0;
    final transporte = MockClient((r) async {
      if (r.url.path.endsWith('/auth/login')) {
        return ingreso(['dueno', 'administrador']);
      }
      consultas++;
      return http.Response('[]', 200);
    });
    await montar(t, transporte);
    await base.login(t);
    expect(find.text('Selección de rol pendiente'), findsOneWidget);
    expect(find.byType(VehiculosAdminScreen), findsNothing);
    expect(consultas, 0);
  });
}
