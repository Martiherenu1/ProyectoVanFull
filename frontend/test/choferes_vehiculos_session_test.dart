import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/admin/choferes_admin_screen.dart';
import 'package:frontend/screens/admin/vehiculos_admin_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'admin_choferes_session_test.dart' as base;
import 'dueno_choferes_session_test.dart' as sesion;
import 'services/admin/choferes_admin_api_test.dart' as choferes;
import 'services/admin/vehiculos_admin_api_test.dart' as vehiculos;

http.Response lista(String recurso) => http.Response(
  jsonEncode([
    recurso == 'choferes' ? choferes.choferJson() : vehiculos.vehiculo(),
  ]),
  200,
);

void main() {
  for (final rol in ['dueno', 'administrador']) {
    testWidgets(
      '$rol navega entre Choferes y Vehículos sin perder otros módulos',
      (t) async {
        final consultas = <String>[];
        final transporte = MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            return sesion.ingreso([rol], 'token-$rol');
          }
          expect(r.method, 'GET');
          expect(r.headers['authorization'], 'Bearer token-$rol');
          consultas.add(r.url.path);
          for (final recurso in ['choferes', 'vehiculos']) {
            if (r.url.path.endsWith('/$recurso')) return lista(recurso);
          }
          return http.Response('[]', 200);
        });
        await sesion.montar(t, transporte);
        await base.login(t);
        for (final exclusivo in ['admin-administradores', 'admin-tarifas']) {
          expect(
            find.byKey(Key(exclusivo)),
            rol == 'dueno' ? findsOneWidget : findsNothing,
          );
        }
        for (final (recurso, tipo, texto) in <(String, Type, String)>[
          ('choferes', ChoferesAdminScreen, 'Ana Pérez'),
          ('vehiculos', VehiculosAdminScreen, 'VF022AA'),
          ('choferes', ChoferesAdminScreen, 'Ana Pérez'),
        ]) {
          await t.tap(find.byKey(Key('admin-$recurso')));
          await t.pumpAndSettle();
          expect(find.byType(tipo), findsOneWidget);
          expect(find.text(texto), findsOneWidget);
          expect(consultas, contains('/api/$recurso'));
          await t.pageBack();
          await t.pumpAndSettle();
          for (final key in [
            'admin-choferes',
            'admin-vehiculos',
            'admin-recorridos',
            'admin-historial-viajes',
            'admin-abonos',
          ]) {
            expect(find.byKey(Key(key)), findsOneWidget);
          }
        }
        expect(t.takeException(), isNull);
      },
    );
  }

  for (final saliente in ['choferes', 'vehiculos']) {
    final entrante = saliente == 'choferes' ? 'vehiculos' : 'choferes';
    for (final status in [200, 401, 403]) {
      testWidgets(
        '$saliente $status tardío no afecta $entrante de otra sesión',
        (t) async {
          final pendiente = Completer<http.Response>();
          var logins = 0;
          var consultasSalientes = 0;
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
            if (r.url.path.endsWith('/$saliente')) {
              consultasSalientes++;
              expect(r.headers['authorization'], 'Bearer token-1');
              return pendiente.future;
            }
            if (r.url.path.endsWith('/$entrante')) {
              expect(r.headers['authorization'], 'Bearer token-2');
              return lista(entrante);
            }
            return http.Response('[]', 200);
          });
          await sesion.montar(t, transporte);
          await base.login(t);
          await t.tap(find.byKey(Key('admin-$saliente')));
          await t.pump();
          await t.pump(const Duration(milliseconds: 400));
          final cargar = saliente == 'choferes'
              ? t
                    .widget<ChoferesAdminScreen>(
                      find.byType(ChoferesAdminScreen),
                    )
                    .cargar
              : t
                    .widget<VehiculosAdminScreen>(
                      find.byType(VehiculosAdminScreen),
                    )
                    .cargar;
          await t.pageBack();
          await t.pumpAndSettle();
          await t.tap(find.byKey(const Key('admin-salir')));
          await t.pumpAndSettle();
          await base.login(t);
          await t.tap(find.byKey(Key('admin-$entrante')));
          await t.pumpAndSettle();
          pendiente.complete(
            status == 200 ? lista(saliente) : sesion.fallo(status),
          );
          await t.pumpAndSettle();
          expect(
            find.byType(
              entrante == 'choferes'
                  ? ChoferesAdminScreen
                  : VehiculosAdminScreen,
            ),
            findsOneWidget,
          );
          expect(
            find.text(entrante == 'choferes' ? 'Ana Pérez' : 'VF022AA'),
            findsOneWidget,
          );
          expect(find.text('Ingresar'), findsNothing);
          expect(find.byKey(const Key('admin-acceso-denegado')), findsNothing);
          await expectLater(cargar(), throwsStateError);
          expect(consultasSalientes, 1);
        },
      );
    }
  }
}
