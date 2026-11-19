import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/admin/abonos_admin_screen.dart';
import 'package:frontend/screens/admin/administradores_admin_screen.dart';
import 'package:frontend/screens/admin/historial_viajes_screen.dart';
import 'package:frontend/screens/admin/recorridos_admin_screen.dart';
import 'package:frontend/screens/admin/tarifas_admin_screen.dart';
import 'package:frontend/screens/admin/vehiculos_admin_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'admin_vehiculos_session_test.dart' as base;
import 'dueno_vehiculos_session_test.dart' as sesion;
import 'services/admin/vehiculos_admin_api_test.dart' as datos;

void main() {
  for (final rol in ['dueno', 'administrador']) {
    testWidgets(
      '$rol conserva los módulos recientes al entrar y salir de Vehículos',
      (t) async {
        final consultas = <String>[];
        final transporte = MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            return sesion.ingreso([rol], 'token-$rol');
          }
          expect(r.method, 'GET');
          expect(r.headers['authorization'], 'Bearer token-$rol');
          consultas.add(r.url.path);
          if (r.url.path.endsWith('/vehiculos')) {
            return http.Response(jsonEncode([datos.vehiculo()]), 200);
          }
          if (r.url.path.endsWith('/viajes')) return http.Response('[]', 200);
          return http.Response('{"items":[]}', 200);
        });
        await sesion.montar(t, transporte);
        await base.login(t);
        for (final key in ['admin-administradores', 'admin-tarifas']) {
          expect(
            find.byKey(Key(key)),
            rol == 'dueno' ? findsOneWidget : findsNothing,
          );
        }
        await t.tap(find.byKey(const Key('admin-vehiculos')));
        await t.pumpAndSettle();
        expect(find.text('VF022AA'), findsOneWidget);
        await t.pageBack();
        await t.pumpAndSettle();
        final modulos = <(String, Type, String)>[
          if (rol == 'dueno') ...[
            (
              'admin-administradores',
              AdministradoresAdminScreen,
              '/api/administradores',
            ),
            (
              'admin-tarifas',
              TarifasAdminScreen,
              '/api/administracion/tarifas',
            ),
          ],
          (
            'admin-recorridos',
            RecorridosAdminScreen,
            '/api/administracion/recorridos',
          ),
          (
            'admin-historial-viajes',
            HistorialViajesScreen,
            '/api/administracion/historial-viajes',
          ),
          ('admin-abonos', AbonosAdminScreen, '/api/administracion/abonos'),
        ];
        for (final (key, pantalla, ruta) in modulos) {
          await t.tap(find.byKey(Key(key)));
          await t.pumpAndSettle();
          expect(find.byType(pantalla), findsOneWidget);
          expect(consultas, contains(ruta));
          expect(t.takeException(), isNull);
          await t.pageBack();
          await t.pumpAndSettle();
          expect(find.byKey(const Key('admin-vehiculos')), findsOneWidget);
        }
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  for (final status in [200, 401, 403]) {
    testWidgets(
      'Vehículos $status de dueño saliente no altera historial de otra sesión',
      (t) async {
        final pendiente = Completer<http.Response>();
        var logins = 0;
        final transporte = MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            logins++;
            return sesion.ingreso([
              logins == 1 ? 'dueno' : 'administrador',
            ], 'token-$logins');
          }
          if (r.url.path.endsWith('/auth/logout')) {
            return http.Response('', 204);
          }
          if (r.url.path.endsWith('/vehiculos')) return pendiente.future;
          if (r.url.path.endsWith('/viajes')) return http.Response('[]', 200);
          return http.Response('{"items":[]}', 200);
        });
        await sesion.montar(t, transporte);
        await base.login(t);
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
        await t.tap(find.byKey(const Key('admin-historial-viajes')));
        await t.pumpAndSettle();
        pendiente.complete(
          status == 200
              ? http.Response(jsonEncode([datos.vehiculo()]), 200)
              : sesion.fallo(status),
        );
        await t.pumpAndSettle();
        expect(find.byType(HistorialViajesScreen), findsOneWidget);
        expect(find.text('VF022AA'), findsNothing);
        expect(find.text('Ingresar'), findsNothing);
        expect(find.byKey(const Key('admin-acceso-denegado')), findsNothing);
        await expectLater(cargar(), throwsStateError);
      },
    );
  }
}
