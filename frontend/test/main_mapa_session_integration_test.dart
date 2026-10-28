import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/session/sesion_app.dart';
import 'package:frontend/core/session/sesion_controller.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/admin/viajes_dia_admin_screen.dart';
import 'package:frontend/screens/gps/ubicacion_screen.dart';
import 'package:frontend/widgets/gps/mapa_ultima_posicion.dart';
import 'package:http/http.dart' as http;

import 'widgets/gps/mapa_ultima_posicion_test.dart' as f;

class TransporteMapa extends http.BaseClient {
  int ingresos = 0, lecturas = 0;
  final pedidos = <http.BaseRequest>[];
  Future<http.StreamedResponse> Function(int)? responder;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    pedidos.add(request);
    if (request.url.path.endsWith('/auth/login')) {
      return json(200, {
        'access_token': 'sesion-falsa-${++ingresos}',
        'token_type': 'bearer',
        'roles': ['administrador'],
      });
    }
    if (request.url.path.endsWith('/auth/logout')) {
      return http.StreamedResponse(const Stream.empty(), 204);
    }
    if (request.url.path.endsWith('/ubicacion')) {
      final n = ++lecturas;
      return responder == null ? posicion(n) : responder!(n);
    }
    return json(200, []);
  }

  http.StreamedResponse json(int estado, Object body) => http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    estado,
    headers: {'content-type': 'application/json'},
  );
  http.StreamedResponse posicion(int n) => json(200, {
    'id_viaje': 41,
    'latitud': n.toDouble(),
    'longitud': 2.0,
    'fecha_hora_posicion': DateTime.utc(
      2026,
      10,
      28,
      12,
      0,
      n,
    ).toIso8601String(),
    'desactualizada': false,
    'eta_minutos': null,
  });
  http.StreamedResponse error(int status) => json(status, {
    'error': {'codigo': 'SIN_ACCESO', 'mensaje': 'Sin acceso'},
  });
}

SesionController sesion(WidgetTester t) =>
    t.widget<SesionApp>(find.byType(SesionApp)).controller;
Future<void> ingresar(WidgetTester t, SesionController s) async {
  await s.ingresar('cuenta-falsa', 'clave-falsa');
  await t.pumpAndSettle();
}

Future<void> abrir(WidgetTester t) async {
  t
      .widget<ViajesDiaAdminScreen>(find.byType(ViajesDiaAdminScreen))
      .onViajeSeleccionado(41);
  await t.pumpAndSettle();
}

Future<void> montar(
  WidgetTester t,
  TransporteMapa tx,
  f.MotorFalso motor, {
  PrepararMapa? loader,
}) async {
  await t.pumpWidget(
    VanFullBootstrap(
      apiBaseUrl: 'https://vanfull.test/api/',
      crearTransporte: () => tx,
      configuracionMapa: f.android,
      prepararMapa: loader ?? f.disponible,
      crearVisorMapa: motor.crear,
    ),
  );
  await ingresar(t, sesion(t));
  await abrir(t);
}

Future<void> limpiar(WidgetTester t) async => t.pumpWidget(const SizedBox());

void main() {
  testWidgets(
    'composición mantiene fuente y mapa estables entre consultas y reconstrucción de ruta',
    (t) async {
      final tx = TransporteMapa();
      final motor = f.MotorFalso();
      await montar(t, tx, motor);
      final pantalla = t.widget<UbicacionScreen>(find.byType(UbicacionScreen));
      expect(pantalla.alcance, isNotNull);
      expect(identical(pantalla.invalidaciones, sesion(t)), true);
      expect(pantalla.contextoVigente!(), true);
      final route = ModalRoute.of(t.element(find.byType(UbicacionScreen)))!;
      route.changedExternalState();
      await t.pumpAndSettle();
      expect(
        identical(
          pantalla.consultar,
          t.widget<UbicacionScreen>(find.byType(UbicacionScreen)).consultar,
        ),
        true,
      );
      await t.pump(const Duration(seconds: 10));
      await t.pumpAndSettle();
      expect(tx.lecturas, 2);
      expect(motor.creados, 1);
      expect(motor.controles.single.movimientos, 0);
      expect(
        tx.pedidos
            .where((p) => p.url.path.endsWith('/ubicacion'))
            .every((p) => p.method == 'GET'),
        true,
      );
      await limpiar(t);
    },
  );

  testWidgets(
    'salida retira datos y mapa; la fuente antigua no envía con la cuenta siguiente',
    (t) async {
      final tx = TransporteMapa();
      final motor = f.MotorFalso();
      await montar(t, tx, motor);
      final s = sesion(t);
      final vieja = t.widget<UbicacionScreen>(find.byType(UbicacionScreen));
      unawaited(s.salir());
      expect(vieja.contextoVigente!(), false);
      await t.pumpAndSettle();
      expect(find.byType(f.VisorFalso), findsNothing);
      expect(find.textContaining('Última posición:'), findsNothing);
      expect(motor.controles.single.disposiciones, 1);
      await t.pump(const Duration(seconds: 30));
      expect(tx.lecturas, 1);
      await ingresar(t, s);
      await abrir(t);
      final actual = t.widget<UbicacionScreen>(find.byType(UbicacionScreen));
      expect(identical(vieja.alcance, actual.alcance), false);
      await expectLater(
        Future.sync(() => vieja.consultar(41)),
        throwsA(anything),
      );
      expect(tx.lecturas, 2);
      expect(actual.contextoVigente!(), true);
      await limpiar(t);
    },
  );

  for (final status in [401, 403]) {
    testWidgets(
      'GET $status vigente reutiliza manejo común y retira mapa/datos',
      (t) async {
        final tx = TransporteMapa();
        final motor = f.MotorFalso();
        tx.responder = (n) async => n == 1 ? tx.posicion(n) : tx.error(status);
        await montar(t, tx, motor);
        final s = sesion(t);
        await t.pump(const Duration(seconds: 10));
        await t.pumpAndSettle();
        expect(find.byType(f.VisorFalso), findsNothing);
        expect(find.textContaining('Última posición:'), findsNothing);
        expect(motor.controles.single.disposiciones, 1);
        expect(s.sesion == null, status == 401);
        if (status == 403) {
          expect(find.text('Acceso denegado.'), findsOneWidget);
        }
        await t.pump(const Duration(seconds: 30));
        expect(tx.lecturas, 2);
        await limpiar(t);
      },
    );
  }

  for (final status in [200, 401, 403]) {
    testWidgets(
      'GET tardío $status de A no muestra datos ni invalida/deniega B',
      (t) async {
        final tx = TransporteMapa();
        final motor = f.MotorFalso();
        final espera = Completer<http.StreamedResponse>();
        tx.responder = (n) async => n == 2 ? espera.future : tx.posicion(n);
        await montar(t, tx, motor);
        final s = sesion(t);
        await t.pump(const Duration(seconds: 10));
        await t.pump();
        expect(tx.lecturas, 2);
        await s.salir();
        await t.pumpAndSettle();
        await ingresar(t, s);
        await abrir(t);
        final pantallaB = t.widget<UbicacionScreen>(
          find.byType(UbicacionScreen),
        );
        espera.complete(status == 200 ? tx.posicion(2) : tx.error(status));
        await t.pumpAndSettle();
        expect(s.sesion, isNotNull);
        expect(pantallaB.contextoVigente!(), true);
        expect(find.byType(f.VisorFalso), findsOneWidget);
        expect(
          t.widget<f.VisorFalso>(find.byType(f.VisorFalso)).posicion.latitud,
          3,
        );
        expect(find.text('Acceso denegado.'), findsNothing);
        await limpiar(t);
      },
    );
  }

  testWidgets('loader tardío de A no construye mapa tras cambiar a B', (
    t,
  ) async {
    final tx = TransporteMapa();
    final motor = f.MotorFalso();
    final espera = Completer<bool>();
    var cargas = 0;
    await montar(
      t,
      tx,
      motor,
      loader: (_) => ++cargas == 1 ? espera.future : Future.value(true),
    );
    final s = sesion(t);
    expect(motor.creados, 0);
    await s.salir();
    await t.pumpAndSettle();
    await ingresar(t, s);
    await abrir(t);
    expect(motor.creados, 1);
    espera.complete(true);
    await t.pumpAndSettle();
    expect(motor.creados, 1);
    expect(find.byType(f.VisorFalso), findsOneWidget);
    await limpiar(t);
  });

  testWidgets('onMapCreated tardío de A dispone su handle y no modifica B', (
    t,
  ) async {
    final tx = TransporteMapa();
    final motor = f.MotorFalso();
    await montar(t, tx, motor);
    final callback = t.widget<f.VisorFalso>(find.byType(f.VisorFalso)).onCreado;
    final s = sesion(t);
    await s.salir();
    await t.pumpAndSettle();
    await ingresar(t, s);
    await abrir(t);
    final viejo = f.ControlFalso((0, 0));
    callback(viejo);
    await t.pumpAndSettle();
    expect(viejo.disposiciones, 1);
    expect(motor.controles.last.disposiciones, 0);
    expect(find.byType(f.VisorFalso), findsOneWidget);
    await limpiar(t);
  });

  testWidgets('volver de ruta detiene polling y descarta GET pendiente', (
    t,
  ) async {
    final tx = TransporteMapa();
    final motor = f.MotorFalso();
    final espera = Completer<http.StreamedResponse>();
    tx.responder = (n) async => n == 2 ? espera.future : tx.posicion(n);
    await montar(t, tx, motor);
    await t.pump(const Duration(seconds: 10));
    await t.pump();
    await t.pageBack();
    await t.pumpAndSettle();
    espera.complete(tx.posicion(2));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 30));
    expect(tx.lecturas, 2);
    expect(find.byType(f.VisorFalso), findsNothing);
    expect(motor.controles.single.disposiciones, 1);
    await limpiar(t);
  });
}
