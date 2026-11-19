import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/admin/choferes_admin_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'admin_choferes_session_test.dart' as base;
import 'services/admin/choferes_admin_api_test.dart' as datos;

import 'admin_menu_helpers.dart';

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
    testWidgets('dueño consulta choferes HTTP $status, desde el menú vigente', (
      t,
    ) async {
      var consultas = 0;
      final otras = <String>[];
      final transporte = MockClient((r) async {
        if (r.url.path.endsWith('/auth/login')) return ingreso(['dueno']);
        if (r.url.path.endsWith('/choferes')) {
          consultas++;
          expect(r.headers['authorization'], 'Bearer dueno-token');
          final codigo = consultas == 1 ? status : 200;
          return codigo == 200
              ? http.Response(jsonEncode([datos.choferJson()]), 200)
              : fallo(codigo);
        }
        if (r.url.path.endsWith('/viajes')) return http.Response('[]', 200);
        otras.add(r.url.path);
        return http.Response('[]', 200);
      });
      await montar(t, transporte);
      await base.login(t);
      await tocarMenuAdmin(t, const Key('admin-choferes'));
      await t.pumpAndSettle();
      if (status == 401) {
        expect(find.text('Ingresar'), findsOneWidget);
      } else if (status == 403) {
        expect(find.byKey(const Key('admin-acceso-denegado')), findsOneWidget);
        expect(find.text('Ingresar'), findsNothing);
      } else {
        if (status == 500) {
          await t.tap(find.text('Reintentar'));
          await t.pumpAndSettle();
        }
        expect(find.text('Ana Pérez'), findsOneWidget);
        await t.pageBack();
        await t.pumpAndSettle();
        await abrirMenuAdmin(t);
        for (final modulo in [
          'admin-salir',
          'admin-crear-viaje',
          'admin-administradores',
          'admin-tarifas',
          'admin-recorridos',
          'admin-historial-viajes',
          'admin-abonos',
          'admin-vehiculos',
        ]) {
          expect(find.byKey(Key(modulo)), findsOneWidget);
        }
      }
      expect(otras, isEmpty);
    });
  }

  testWidgets(
    'dueño registra y modifica usando su token y contrato existente',
    (t) async {
      final metodos = <String>[];
      Map<String, dynamic>? guardado;
      final transporte = MockClient((r) async {
        if (r.url.path.endsWith('/auth/login')) return ingreso(['dueno']);
        if (r.url.path.endsWith('/viajes')) return http.Response('[]', 200);
        expect(r.url.path, startsWith('/api/choferes'));
        expect(r.headers['authorization'], 'Bearer dueno-token');
        metodos.add(r.method);
        if (r.method == 'GET') return http.Response('[]', 200);
        final cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
        guardado = {...datos.choferJson(), ...?guardado, ...cuerpo};
        return http.Response(
          jsonEncode(guardado),
          r.method == 'POST' ? 201 : 200,
        );
      });
      await montar(t, transporte);
      await base.login(t);
      await tocarMenuAdmin(t, const Key('admin-choferes'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('registrar-chofer')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('chofer-nombre')), 'Andrea');
      await t.enterText(find.byKey(const Key('chofer-apellido')), 'Pérez');
      await t.enterText(find.byKey(const Key('chofer-dni')), '21000001');
      await t.tap(find.byKey(const Key('guardar-chofer')));
      await t.pumpAndSettle();
      expect(find.text('Andrea Pérez'), findsOneWidget);
      await t.tap(find.byKey(const Key('editar-chofer-7')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('chofer-nombre')), 'Ana');
      await t.tap(find.byKey(const Key('guardar-chofer')));
      await t.pumpAndSettle();
      expect(guardado?['nombre'], 'Ana');
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
          if (r.url.path.endsWith('/choferes')) {
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
        await tocarMenuAdmin(t, const Key('admin-choferes'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        final cargar = t
            .widget<ChoferesAdminScreen>(find.byType(ChoferesAdminScreen))
            .cargar;
        await t.pageBack();
        await t.pumpAndSettle();
        await tocarMenuAdmin(t, const Key('admin-salir'));
        await t.pumpAndSettle();
        await base.login(t);
        pendiente.complete(
          status == 200
              ? http.Response(jsonEncode([datos.choferJson()]), 200)
              : fallo(status),
        );
        await t.pumpAndSettle();
        await abrirMenuAdmin(t);
        expect(find.byKey(const Key('admin-choferes')), findsOneWidget);
        expect(find.text('Ana Pérez'), findsNothing);
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
    expect(find.byType(ChoferesAdminScreen), findsNothing);
    expect(consultas, 0);
  });
}
