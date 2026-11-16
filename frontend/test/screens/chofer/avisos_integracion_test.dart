import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/core/session/sesion_app.dart';

import 'ejecucion_autenticada_chofer_test.dart' as base;

class CircuitoAvisos extends base.Escenario {
  Map<String, dynamic>? guardado;
  final reportes = <http.Request>[];
  final consultas = <http.BaseRequest>[];
  bool fallarConsultas = false;
  Completer<http.StreamedResponse>? consultaPendiente;
  int? statusRegistro;
  int? statusConsulta;
  Completer<http.StreamedResponse>? registroPendiente;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest r) async {
    if (r.url.path.endsWith('/avisos') && r.method == 'POST') {
      final req = r as http.Request;
      reportes.add(req);
      if (registroPendiente != null) return registroPendiente!.future;
      if (statusRegistro != null) return base.Escenario.error(statusRegistro!);
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      guardado = {
        'id_viaje': 41,
        'id_evento_operativo': 51,
        'registro': 'confirmado',
        'clave_solicitud': body['clave_solicitud'],
      };
      // Simula respuesta perdida después de persistir, no un servicio externo.
      throw TimeoutException('Respuesta perdida controlada');
    }
    if (r.url.path.endsWith('/avisos/resultado')) {
      consultas.add(r);
      if (statusConsulta != null) return base.Escenario.error(statusConsulta!);
      if (fallarConsultas) throw TimeoutException('Consulta controlada');
      if (consultaPendiente != null) return consultaPendiente!.future;
      expect(
        r.url.queryParameters['clave_solicitud'],
        guardado!['clave_solicitud'],
      );
      return base.Escenario.json(200, guardado!);
    }
    return super.send(r);
  }
}

void main() {
  for (final registro in [true, false]) {
    for (final status in [200, 401, 403]) {
      testWidgets(
        'aviso tardío registro=$registro HTTP $status no afecta otra sesión',
        (t) async {
          final e = CircuitoAvisos()..estado = 'en_curso';
          final pendiente = Completer<http.StreamedResponse>();
          await e.montar(t);
          await base.ingresar(t);
          const clave = '11111111-1111-4111-8111-111111111111';
          if (registro) {
            e.registroPendiente = pendiente;
            await base.detalle(t);
            await t.tap(find.text('Informar demora o problema'));
            await base.paso(t);
            await t.enterText(find.byType(TextField), 'Cuenta anterior');
            await t.tap(find.text('Registrar aviso'));
          } else {
            e.consultaPendiente = pendiente;
            await t.tap(find.text('Resultado propio'));
            await base.paso(t);
            await t.enterText(find.byType(TextField).at(0), '41');
            await t.enterText(find.byType(TextField).at(1), clave);
            await t.tap(find.text('Consultar resultado'));
          }
          await base.paso(t);
          await base.nuevaCuenta(t);
          pendiente.complete(
            status == 200
                ? base.Escenario.json(200, {
                    'id_viaje': 41,
                    'id_evento_operativo': 51,
                    'registro': 'confirmado',
                    'clave_solicitud': registro
                        ? jsonDecode(e.reportes.single.body)['clave_solicitud']
                        : clave,
                  })
                : base.Escenario.error(status),
          );
          await base.paso(t);
          expect(
            t.widget<SesionApp>(find.byType(SesionApp)).controller.token,
            'cuenta-2',
          );
          expect(find.text('Acceso denegado.'), findsNothing);
          expect(find.textContaining('Aviso registrado'), findsNothing);
          expect(find.byKey(const ValueKey('viaje-41')), findsOneWidget);
          await t.tap(find.text('Resultado propio'));
          await base.paso(t);
          expect(
            find.textContaining('Recuperar aviso sin confirmar del viaje'),
            findsNothing,
          );
          for (final campo in t.widgetList<TextField>(find.byType(TextField))) {
            expect(campo.controller!.text, isEmpty);
          }
          expect(e.reportes.length, registro ? 1 : 0);
          expect(e.consultas.length, registro ? 0 : 1);
          await t.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    testWidgets('401 vigente de aviso registro=$registro vuelve al ingreso', (
      t,
    ) async {
      final e = CircuitoAvisos()..estado = 'en_curso';
      await e.montar(t);
      await base.ingresar(t);
      if (registro) {
        e.statusRegistro = 401;
        await base.detalle(t);
        await t.tap(find.text('Informar demora o problema'));
        await base.paso(t);
        await t.enterText(find.byType(TextField), 'Interno');
        await t.tap(find.text('Registrar aviso'));
      } else {
        e.statusConsulta = 401;
        await t.tap(find.text('Resultado propio'));
        await base.paso(t);
        await t.enterText(find.byType(TextField).at(0), '41');
        await t.enterText(
          find.byType(TextField).at(1),
          '11111111-1111-4111-8111-111111111111',
        );
        await t.tap(find.text('Consultar resultado'));
      }
      await base.paso(t);
      expect(find.text('Ingresar'), findsOneWidget);
      expect(find.text('Resultado propio'), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final registro in [true, false]) {
    testWidgets(
      '403 vigente de aviso registro=$registro protege acceso común',
      (t) async {
        final e = CircuitoAvisos()..estado = 'en_curso';
        await e.montar(t);
        await base.ingresar(t);
        if (registro) {
          e.statusRegistro = 403;
          await base.detalle(t);
          await t.tap(find.text('Informar demora o problema'));
          await base.paso(t);
          await t.enterText(find.byType(TextField), 'Interno');
          await t.tap(find.text('Registrar aviso'));
        } else {
          e.statusConsulta = 403;
          await t.tap(find.text('Resultado propio'));
          await base.paso(t);
          await t.enterText(find.byType(TextField).at(0), '41');
          await t.enterText(
            find.byType(TextField).at(1),
            '11111111-1111-4111-8111-111111111111',
          );
          await t.tap(find.text('Consultar resultado'));
        }
        await base.paso(t);
        expect(find.text('Acceso denegado.'), findsOneWidget);
        expect(find.text('Resultado propio'), findsNothing);
        expect(find.text('Finalizar viaje'), findsNothing);
        expect(
          t.widget<SesionApp>(find.byType(SesionApp)).controller.token,
          'cuenta-1',
        );
        expect(e.reportes.length, registro ? 1 : 0);
        expect(e.consultas.length, registro ? 0 : 1);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'acción de recuperación pertenece al listado y no cubre rutas internas',
    (t) async {
      final e = CircuitoAvisos()..estado = 'en_curso';
      await e.montar(t);
      await base.ingresar(t);
      expect(find.text('Resultado propio'), findsOneWidget);
      await base.detalle(t);
      await t.pumpAndSettle();
      expect(find.text('Resultado propio'), findsNothing);
      await t.tap(find.text('Informar demora o problema'));
      await base.paso(t);
      final pendiente = Completer<http.StreamedResponse>();
      e.registroPendiente = pendiente;
      await t.enterText(find.byType(TextField), 'Interno');
      await t.tap(find.text('Registrar aviso'));
      await base.paso(t);
      expect(find.text('Resultado propio'), findsNothing);
      await base.volver(t);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Registrar aviso'), findsOneWidget);
      pendiente.completeError(TimeoutException('Controlado'));
      await base.paso(t);
      await t.ensureVisible(find.text('Volver al viaje sin confirmar'));
      await t.tap(find.text('Volver al viaje sin confirmar'));
      await base.paso(t);
      expect(find.text('Finalizar viaje'), findsOneWidget);
      await base.volver(t);
      expect(find.text('Resultado propio'), findsOneWidget);
      await t.tap(find.text('Resultado propio'));
      await base.paso(t);
      expect(find.text('Recuperar resultado propio'), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.text('Resultado propio'), findsNothing);
      await base.volver(t);
      expect(find.text('Resultado propio'), findsOneWidget);
      expect(e.reportes.length, 1);
      expect(e.consultas, isEmpty);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'salida incierta devuelve acciones y conserva clave para recuperar',
    (t) async {
      final e = CircuitoAvisos()
        ..estado = 'en_curso'
        ..fallarConsultas = true;
      await e.montar(t);
      await base.ingresar(t);
      await base.detalle(t);
      await t.tap(find.text('Informar demora o problema'));
      await base.paso(t);
      await t.enterText(find.byType(TextField), 'Detalle privado');
      await t.tap(find.text('Registrar aviso'));
      await base.paso(t);
      final clave = e.guardado!['clave_solicitud'];
      for (var i = 0; i < 2; i++) {
        await t.ensureVisible(find.text('Consultar resultado'));
        await t.tap(find.text('Consultar resultado'));
        await base.paso(t);
      }
      await t.ensureVisible(find.text('Repetir el mismo reporte'));
      await t.tap(find.text('Repetir el mismo reporte'));
      await base.paso(t);
      expect(e.reportes.length, 2);
      expect(jsonDecode(e.reportes.last.body)['clave_solicitud'], clave);
      expect(
        find.textContaining('Salir no cancela ni rechaza'),
        findsOneWidget,
      );
      await t.ensureVisible(find.text('Volver al viaje sin confirmar'));
      await t.tap(find.text('Volver al viaje sin confirmar'));
      await base.paso(t);
      expect(find.text('Detalle del viaje'), findsOneWidget);
      expect(find.text('Finalizar viaje'), findsOneWidget);
      await base.volver(t);
      await t.tap(find.text('Resultado propio'));
      await base.paso(t);
      expect(
        find.text('Recuperar aviso sin confirmar del viaje 41'),
        findsOneWidget,
      );
      final antes = e.consultas.length;
      await t.tap(find.text('Recuperar aviso sin confirmar del viaje 41'));
      await base.paso(t);
      expect(e.consultas.length, antes);
      expect(
        t.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
        '41',
      );
      expect(
        t.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        clave,
      );
      e.fallarConsultas = false;
      await t.ensureVisible(find.text('Consultar resultado'));
      await t.tap(find.text('Consultar resultado'));
      await base.paso(t);
      expect(find.text('Aviso registrado (#51).'), findsOneWidget);
      expect(e.consultas.last.url.queryParameters['clave_solicitud'], clave);
      expect(e.reportes.length, 2);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final falla in [false, true]) {
    testWidgets(
      'recuperación tardía falla=$falla descarta datos al cambiar sesión',
      (t) async {
        final e = CircuitoAvisos()..estado = 'en_curso';
        await e.montar(t);
        await base.ingresar(t);
        await base.detalle(t);
        await t.tap(find.text('Informar demora o problema'));
        await base.paso(t);
        await t.enterText(find.byType(TextField), 'Privado de cuenta 1');
        await t.tap(find.text('Registrar aviso'));
        await base.paso(t);
        await t.ensureVisible(find.text('Volver al viaje sin confirmar'));
        await t.tap(find.text('Volver al viaje sin confirmar'));
        await base.paso(t);
        await base.volver(t);
        await t.tap(find.text('Resultado propio'));
        await base.paso(t);
        await t.tap(find.text('Recuperar aviso sin confirmar del viaje 41'));
        await base.paso(t);
        final pendiente = Completer<http.StreamedResponse>();
        e.consultaPendiente = pendiente;
        await t.ensureVisible(find.text('Consultar resultado'));
        await t.tap(find.text('Consultar resultado'));
        await base.paso(t);
        await base.nuevaCuenta(t);
        if (falla) {
          pendiente.completeError(TimeoutException('Tardía controlada'));
        } else {
          pendiente.complete(base.Escenario.json(200, e.guardado!));
        }
        await base.paso(t);
        expect(find.textContaining('Aviso registrado (#51)'), findsNothing);
        expect(find.textContaining('Resultado no disponible'), findsNothing);
        await t.tap(find.text('Resultado propio'));
        await base.paso(t);
        expect(
          find.text('Recuperar aviso sin confirmar del viaje 41'),
          findsNothing,
        );
        for (final campo in t.widgetList<TextField>(find.byType(TextField))) {
          expect(campo.controller!.text, isEmpty);
        }
        expect(e.reportes.length, 1);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('recuperación histórica se retira al cerrar y cambiar sesión', (
    t,
  ) async {
    final e = CircuitoAvisos()..estado = 'en_curso';
    e.guardado = {
      'id_viaje': 41,
      'id_evento_operativo': 51,
      'registro': 'confirmado',
      'clave_solicitud': '11111111-1111-4111-8111-111111111111',
    };
    await e.montar(t);
    await base.ingresar(t);
    await t.tap(find.text('Resultado propio'));
    await base.paso(t);
    await t.enterText(find.byType(TextField).at(0), '41');
    await t.enterText(
      find.byType(TextField).at(1),
      e.guardado!['clave_solicitud'] as String,
    );
    await t.tap(find.text('Consultar resultado'));
    await base.paso(t);
    expect(find.text('Aviso registrado (#51).'), findsOneWidget);
    await base.nuevaCuenta(t);
    await base.paso(t);
    expect(find.text('Aviso registrado (#51).'), findsNothing);
    expect(find.text('Recuperar resultado propio'), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets(
    'bootstrap sesión listado detalle reporte incierto y recuperación',
    (t) async {
      final e = CircuitoAvisos()..estado = 'en_curso';
      await e.montar(t);
      await base.ingresar(t);
      await base.detalle(t);
      await t.tap(find.text('Informar demora o problema'));
      await base.paso(t);
      await t.enterText(find.byType(TextField), 'Información interna');
      await t.tap(find.text('Registrar aviso'));
      await base.paso(t);
      expect(find.textContaining('No pudimos confirmar'), findsOneWidget);
      expect(e.reportes.length, 1);
      expect(e.reportes.single.headers['Authorization'], 'Bearer cuenta-1');
      await t.ensureVisible(find.text('Consultar resultado'));
      await t.tap(find.text('Consultar resultado'));
      await base.paso(t);
      expect(find.textContaining('Aviso registrado (#51)'), findsOneWidget);
      expect(e.reportes.length, 1);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    },
  );
}
