import 'package:frontend/screens/chofer/viajes_chofer_screen.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/screens/chofer/chofer_shell.dart';
import 'package:frontend/screens/chofer/panel_gps.dart';

import '../../fixtures/chofer/operacion_asignada_fixture.dart';
import 'ejecucion_autenticada_chofer_test.dart' as f;

class Transporte extends f.Escenario {
  String? bloquear;
  Completer<http.StreamedResponse>? pendiente;
  bool dosViajes = false;
  final gpsIds = <int>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest r) async {
    final path = r.url.path;
    if (r.method == 'POST' && path.endsWith('/ubicacion')) {
      gpsIds.add(int.parse(r.url.pathSegments[2]));
      return f.Escenario.json(200, {
        'actualizada': true,
        'fecha_hora_posicion': '2026-10-27T12:00:00Z',
      });
    }
    if (r.method == 'GET' && path == bloquear) {
      bloquear = null;
      pendiente = Completer<http.StreamedResponse>();
      return pendiente!.future;
    }
    if (r.method == 'GET' &&
        path.endsWith('/choferes/me/viajes') &&
        dosViajes) {
      return f.Escenario.json(200, [
        viaje(),
        {...viaje(), 'id_viaje': 42},
      ]);
    }
    if (r.method == 'GET' && path.endsWith('/choferes/me/viajes/42')) {
      return f.Escenario.json(200, detalleJson(id: 42));
    }
    return super.send(r);
  }
}

class Plataforma extends GeolocatorPlatform {
  final fuente = StreamController<Position>.broadcast();
  int capturas = 0;
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    capturas++;
    return fuente.stream;
  }
}

final punto = Position(
  longitude: 0,
  latitude: 0,
  timestamp: DateTime.utc(2026),
  accuracy: 1,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);
void main() {
  late GeolocatorPlatform anterior;
  late Plataforma p;
  late bool fuentes;
  late AppLifecycleState? ciclo;
  setUp(() {
    anterior = GeolocatorPlatform.instance;
    p = Plataforma();
    GeolocatorPlatform.instance = p;
    fuentes = GoogleFonts.config.allowRuntimeFetching;
    GoogleFonts.config.allowRuntimeFetching = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    ciclo = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });
  tearDown(() async {
    GeolocatorPlatform.instance = anterior;
    debugDefaultTargetPlatformOverride = null;
    GoogleFonts.config.allowRuntimeFetching = fuentes;
    if (ciclo != null) {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(ciclo!);
    }
    await p.fuente.close();
  });
  Future<void> montar(WidgetTester t, Transporte e) async {
    await e.montar(t);
    await f.ingresar(t);
    await f.detalle(t);
  }

  for (final listado in [true, false]) {
    testWidgets(
      'GET viejo ${listado ? "listado" : "detalle"} programado no detiene captura posterior',
      (t) async {
        final e = Transporte();
        await montar(t, e);
        final shell = t.widget<ChoferShell>(find.byType(ChoferShell));
        e.bloquear = listado
            ? '/api/choferes/me/viajes'
            : '/api/choferes/me/viajes/41';
        final vieja = listado
            ? shell.cargarViajes(DateTime(2026, 10, 30))
            : shell.cargarDetalle(41);
        await f.paso(t);
        expect(e.pendiente, isNotNull);
        await t.tap(find.text('Iniciar viaje'));
        await f.paso(t);
        final gps = t.widget<PanelGps>(find.byType(PanelGps)).controller;
        expect(gps.activo, true);
        final dato = detalleJson();
        (dato['viaje'] as Map)['estado'] = 'programado';
        e.pendiente!.complete(
          f.Escenario.json(200, listado ? [dato['viaje']] : dato),
        );
        await vieja;
        await f.paso(t);
        expect(gps.activo, true);
        expect(gps.idViaje, 41);
        p.fuente.add(punto);
        await f.paso(t);
        expect(e.gpsIds, [41]);
        p.fuente.add(punto);
        await f.paso(t);
        expect(e.gpsIds.every((id) => id == 41), true);
        expect(e.gpsIds, isNotEmpty);
        expect(p.capturas, 1);
        await t.pumpWidget(const SizedBox());
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
  testWidgets('listado terminal revalida el detalle y detiene captura A', (
    t,
  ) async {
    final e = Transporte()..estado = 'en_curso';
    await montar(t, e);
    await t.tap(find.textContaining('Reactivar GPS del viaje').first);
    await f.paso(t);
    final gps = t.widget<PanelGps>(find.byType(PanelGps)).controller;
    expect(gps.activo, true);
    await t.binding.handlePopRoute();
    await f.paso(t);
    e.estado = 'finalizado';
    final listado = t.widget<ViajesChoferScreen>(
      find.byType(ViajesChoferScreen),
    );
    listado.onViajesAceptados!([ViajeResumen.fromJson(e.viaje())]);
    await f.paso(t);
    expect(gps.activo, false);
    p.fuente.add(punto);
    await f.paso(t);
    expect(e.gpsIds, isEmpty);
    await t.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('captura A continúa mientras se abre detalle B en_curso', (
    t,
  ) async {
    final e = Transporte()
      ..estado = 'en_curso'
      ..dosViajes = true;
    await montar(t, e);
    await t.tap(find.textContaining('Reactivar GPS del viaje').first);
    await f.paso(t);
    final gps = t.widget<PanelGps>(find.byType(PanelGps)).controller;
    expect(gps.activo, true);
    expect(gps.idViaje, 41);
    await t.binding.handlePopRoute();
    await f.paso(t);
    await t.tap(find.byKey(const ValueKey('viaje-42')));
    await f.paso(t);
    expect(gps.activo, true);
    expect(gps.idViaje, 41);
    p.fuente.add(punto);
    await f.paso(t);
    expect(e.gpsIds.every((id) => id == 41), true);
    expect(e.gpsIds, isNotEmpty);
    expect(p.capturas, 1);
    await t.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
