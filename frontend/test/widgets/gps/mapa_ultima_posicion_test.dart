import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:frontend/core/maps/configuracion_mapa.dart';
import 'package:frontend/models/gps/ubicacion_viaje.dart';
import 'package:frontend/widgets/gps/mapa_ultima_posicion.dart';

const android = ConfiguracionMapa.android(clave: 'clave-de-prueba');
const web = ConfiguracionMapa.web(
  clave: 'clave-web-de-prueba',
  mapIdWeb: 'mapa-de-prueba',
);
Future<bool> disponible(ConfiguracionMapa _) async => true;
UbicacionViaje punto({int id = 1, double lat = 1, int segundo = 1}) =>
    UbicacionViaje(
      id,
      lat,
      2,
      DateTime.utc(2026, 10, 28, 12, 0, segundo),
      true,
      null,
    );

class ControlFalso implements ControlVisorMapa {
  ControlFalso(this.camara);
  (double, double) camara;
  double zoom = 14;
  int movimientos = 0, disposiciones = 0;
  Completer<void>? pendiente;
  @override
  Future<void> centrarEn(double latitud, double longitud) async {
    movimientos++;
    camara = (latitud, longitud);
    await pendiente?.future;
  }

  @override
  void dispose() {
    disposiciones++;
  }
}

class MotorFalso {
  int creados = 0, destruidos = 0;
  final controles = <ControlFalso>[];
  Widget crear({
    required Key key,
    required UbicacionViaje posicion,
    required ConfiguracionMapa configuracion,
    required ValueChanged<ControlVisorMapa> onCreado,
  }) =>
      VisorFalso(key: key, posicion: posicion, motor: this, onCreado: onCreado);
}

class VisorFalso extends StatefulWidget {
  const VisorFalso({
    required this.posicion,
    required this.motor,
    required this.onCreado,
    super.key,
  });
  final UbicacionViaje posicion;
  final MotorFalso motor;
  final ValueChanged<ControlVisorMapa> onCreado;
  @override
  State<VisorFalso> createState() => _VisorFalsoState();
}

class _VisorFalsoState extends State<VisorFalso> {
  @override
  void initState() {
    super.initState();
    widget.motor.creados++;
    final control = ControlFalso((
      widget.posicion.latitud,
      widget.posicion.longitud,
    ));
    widget.motor.controles.add(control);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.onCreado(control),
    );
  }

  @override
  void dispose() {
    widget.motor.destruidos++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text('Visor falso viaje ${widget.posicion.idViaje}');
}

void main() {
  for (final config in [android, web]) {
    test(
      'configuración Google por plataforma sin montar SDK: ${config.destino}',
      () {
        final map = crearVisorGoogle(
          key: const ValueKey(1),
          posicion: punto(),
          configuracion: config,
          onCreado: (_) {},
        ) as GoogleMap;
        expect(map.markers, hasLength(1));
        expect(map.markers.single.markerId.value, 'viaje-1');
        expect(map.initialCameraPosition.target, const LatLng(1, 2));
        expect(map.myLocationEnabled, false);
        expect(map.myLocationButtonEnabled, false);
        expect(map.polylines, isEmpty);
        if (config.destino == DestinoMapa.web) {
          expect(map.markers.single, isA<AdvancedMarker>());
          expect(map.markerType, GoogleMapMarkerType.advancedMarker);
          expect(map.mapId, config.mapIdWeb);
        } else {
          expect(map.markers.single, isNot(isA<AdvancedMarker>()));
          expect(map.markerType, GoogleMapMarkerType.marker);
          expect(map.mapId, isNull);
        }
      },
    );
  }

  testWidgets(
    'actualiza marcador, mantiene vista/cámara y recentra con zoom del usuario',
    (t) async {
      final motor = MotorFalso();
      Future<void> montar(UbicacionViaje p) async {
        await t.pumpWidget(
          MaterialApp(
            builder: (_, child) => Material(child: child),
            home: Scaffold(
              body: MapaUltimaPosicion(
                idViaje: 1,
                posicion: p,
                configuracion: android,
                preparar: disponible,
                crearVisor: motor.crear,
              ),
            ),
          ),
        );
        await t.pump();
      }

      await montar(punto());
      await t.pump();
      final state = t.state(find.byType(VisorFalso));
      final c = motor.controles.single;
      expect(c.camara, (1.0, 2.0));
      c.camara = (8, 9);
      c.zoom = 7;
      await montar(punto(lat: 3, segundo: 2));
      expect(motor.creados, 1);
      expect(identical(state, t.state(find.byType(VisorFalso))), true);
      expect(t.widget<VisorFalso>(find.byType(VisorFalso)).posicion.latitud, 3);
      expect(c.camara, (8.0, 9.0));
      expect(c.movimientos, 0);
      await t.tap(find.byKey(const Key('centrar-vehiculo')));
      await t.pump();
      expect(c.camara, (3.0, 2.0));
      expect(c.zoom, 7);
      expect(c.movimientos, 1);
      await montar(punto(lat: 6, segundo: 1));
      expect(t.widget<VisorFalso>(find.byType(VisorFalso)).posicion.latitud, 3);
      await t.pumpWidget(const SizedBox());
      expect(c.disposiciones, 1);
      expect(motor.destruidos, 1);
    },
  );

  testWidgets('sin configuración o posición no prepara ni construye mapa', (
    t,
  ) async {
    final motor = MotorFalso();
    var preparaciones = 0;
    Future<bool> preparar(ConfiguracionMapa _) async {
      preparaciones++;
      return true;
    }

    for (final config in [
      const ConfiguracionMapa(),
      const ConfiguracionMapa.web(clave: 'prueba'),
    ]) {
      await t.pumpWidget(
        MaterialApp(
          builder: (_, child) => Material(child: child),
          home: MapaUltimaPosicion(
            idViaje: 1,
            posicion: punto(),
            configuracion: config,
            preparar: preparar,
            crearVisor: motor.crear,
          ),
        ),
      );
      await t.pump();
      expect(find.text('Mapa no disponible.'), findsOneWidget);
    }
    await t.pumpWidget(
      MaterialApp(
        builder: (_, child) => Material(child: child),
        home: MapaUltimaPosicion(
          idViaje: 1,
          posicion: null,
          configuracion: android,
          preparar: preparar,
          crearVisor: motor.crear,
        ),
      ),
    );
    await t.pump();
    expect(preparaciones, 0);
    expect(motor.creados, 0);
    expect(find.byType(GoogleMap), findsNothing);
  });

  for (final falla in [false, true]) {
    testWidgets('loader fallido conserva modo textual (excepción: $falla)', (
      t,
    ) async {
      final motor = MotorFalso();
      await t.pumpWidget(
        MaterialApp(
          builder: (_, child) => Material(child: child),
          home: MapaUltimaPosicion(
            idViaje: 1,
            posicion: punto(),
            configuracion: android,
            crearVisor: motor.crear,
            preparar: (_) async {
              if (falla) throw StateError('fallo');
              return false;
            },
          ),
        ),
      );
      await t.pump();
      expect(find.text('Mapa no disponible.'), findsOneWidget);
      expect(motor.creados, 0);
    });
  }

  testWidgets('loader tardío de A no reinstala mapa en B o tras desmontar', (
    t,
  ) async {
    final primero = Completer<bool>(), segundo = Completer<bool>();
    final motor = MotorFalso();
    var llamadas = 0;
    Future<bool> cargar(ConfiguracionMapa _) =>
        (++llamadas == 1 ? primero : segundo).future;
    Future<void> montar(int id) => t.pumpWidget(
      MaterialApp(
        builder: (_, child) => Material(child: child),
        home: MapaUltimaPosicion(
          idViaje: id,
          posicion: punto(id: id),
          alcance: id,
          configuracion: android,
          preparar: cargar,
          crearVisor: motor.crear,
        ),
      ),
    );
    await montar(1);
    await montar(2);
    primero.complete(true);
    await t.pump();
    expect(motor.creados, 0);
    segundo.complete(true);
    await t.pump();
    await t.pump();
    expect(motor.creados, 1);
    expect(t.widget<VisorFalso>(find.byType(VisorFalso)).posicion.idViaje, 2);
    await t.pumpWidget(const SizedBox());
    expect(motor.controles.single.disposiciones, 1);
  });

  testWidgets(
    'onCreado atrasado se dispone sin habilitar cámara de otro alcance',
    (t) async {
      final callbacks = <ValueChanged<ControlVisorMapa>>[];
      Widget crear({
        required Key key,
        required UbicacionViaje posicion,
        required ConfiguracionMapa configuracion,
        required ValueChanged<ControlVisorMapa> onCreado,
      }) {
        callbacks.add(onCreado);
        return SizedBox(key: key);
      }

      Future<void> montar(int scope) async {
        await t.pumpWidget(
          MaterialApp(
            builder: (_, child) => Material(child: child),
            home: MapaUltimaPosicion(
              idViaje: 1,
              posicion: punto(),
              alcance: scope,
              configuracion: android,
              preparar: disponible,
              crearVisor: crear,
            ),
          ),
        );
        await t.pump();
      }

      await montar(1);
      final vieja = callbacks.last;
      await montar(2);
      final obsoleto = ControlFalso((1, 2));
      vieja(obsoleto);
      await t.pump();
      expect(obsoleto.disposiciones, 1);
      expect(
        t
            .widget<OutlinedButton>(find.byKey(const Key('centrar-vehiculo')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'retirar acceso durante recentrado ignora fallo tardío y bloquea doble pulsación',
    (t) async {
      final motor = MotorFalso();
      Future<void> montar(bool permitido) async {
        await t.pumpWidget(
          MaterialApp(
            builder: (_, child) => Material(child: child),
            home: MapaUltimaPosicion(
              idViaje: 1,
              posicion: punto(),
              permitido: permitido,
              configuracion: android,
              preparar: disponible,
              crearVisor: motor.crear,
            ),
          ),
        );
        await t.pump();
        await t.pump();
      }

      await montar(true);
      final c = motor.controles.single..pendiente = Completer<void>();
      await t.tap(find.byKey(const Key('centrar-vehiculo')));
      await t.pump();
      expect(
        t
            .widget<OutlinedButton>(find.byKey(const Key('centrar-vehiculo')))
            .onPressed,
        isNull,
      );
      expect(c.movimientos, 1);
      await montar(false);
      c.pendiente!.completeError(StateError('tardío'));
      await t.pump();
      expect(find.byType(VisorFalso), findsNothing);
      expect(find.text('No se pudo centrar el mapa.'), findsNothing);
      expect(c.disposiciones, 1);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('loader completado después del desmontaje no construye visor', (
    t,
  ) async {
    final listo = Completer<bool>();
    final motor = MotorFalso();
    await t.pumpWidget(
      MaterialApp(
        home: MapaUltimaPosicion(
          idViaje: 1,
          posicion: punto(),
          configuracion: android,
          preparar: (_) => listo.future,
          crearVisor: motor.crear,
        ),
      ),
    );
    await t.pumpWidget(const SizedBox());
    listo.complete(true);
    await t.pump();
    expect(motor.creados, 0);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'mapa acotado y recentrado legible con texto 3x y ancho reducido',
    (t) async {
      final motor = MotorFalso();
      await t.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(3)),
            child: Material(child: child),
          ),
          home: SizedBox(
            width: 230,
            child: MapaUltimaPosicion(
              idViaje: 1,
              posicion: punto(),
              configuracion: android,
              preparar: disponible,
              crearVisor: motor.crear,
            ),
          ),
        ),
      );
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('centrar-vehiculo')), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
