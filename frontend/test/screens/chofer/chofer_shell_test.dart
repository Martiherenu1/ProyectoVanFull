import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/chofer/operacion_asignada.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';
import 'package:frontend/screens/chofer/chofer_shell.dart';
import 'package:frontend/screens/chofer/viajes_chofer_screen.dart';

import '../../fixtures/chofer/operacion_asignada_fixture.dart';

void main() {
  testWidgets('conserva la fecha elegida al volver con el botón del sistema', (
    tester,
  ) async {
    final fechas = <DateTime>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ChoferShell(
          fechaInicial: DateTime(2026, 10, 30),
          cargarViajes: (fecha) async {
            fechas.add(fecha);
            return [
              ViajeResumen.fromJson(
                detalleJson()['viaje'] as Map<String, dynamic>,
              ),
            ];
          },
          cargarDetalle: (id) async =>
              OperacionAsignada.fromJson(detalleJson(id: id)),
          onSalir: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('seleccionar-fecha')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('31'));
    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('viaje-41')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Fecha: 31/10/2026'), findsOneWidget);
    expect(fechas, [DateTime(2026, 10, 30), DateTime(2026, 10, 31)]);
  });

  testWidgets('fuentes estables no recargan por reconstruir el contenedor', (
    tester,
  ) async {
    var listas = 0;
    var detalles = 0;
    final revision = ValueNotifier(0);
    addTearDown(revision.dispose);
    Future<List<ViajeResumen>> cargarLista(DateTime _) async {
      listas++;
      return [
        ViajeResumen.fromJson(detalleJson()['viaje'] as Map<String, dynamic>),
      ];
    }

    Future<OperacionAsignada?> cargarDetalle(int id) async {
      detalles++;
      return OperacionAsignada.fromJson(detalleJson(id: id));
    }

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: revision,
          builder: (_, _, _) => ChoferShell(
            cargarViajes: cargarLista,
            cargarDetalle: cargarDetalle,
            onSalir: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    revision.value++;
    await tester.pumpAndSettle();
    expect(listas, 1);
    // Dos selecciones antes del siguiente frame no apilan dos detalles.
    final seleccionar = tester
        .widget<ViajesChoferScreen>(find.byType(ViajesChoferScreen))
        .onViajeSeleccionado;
    seleccionar(41);
    seleccionar(41);
    await tester.pumpAndSettle();
    revision.value++;
    await tester.pumpAndSettle();
    expect(detalles, 1);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(listas, 1);
    expect(find.text('Mis viajes'), findsOneWidget);
  });

  testWidgets(
    'reemplaza fuentes con detalle abierto e invalida la respuesta anterior',
    (tester) async {
      final revision = ValueNotifier(false);
      addTearDown(revision.dispose);
      final anterior = Completer<OperacionAsignada?>();
      Future<List<ViajeResumen>> listaAnterior(DateTime _) async => [
        ViajeResumen.fromJson(detalleJson()['viaje'] as Map<String, dynamic>),
      ];
      Future<List<ViajeResumen>> listaNueva(DateTime _) async => [
        ViajeResumen.fromJson(
          detalleJson(id: 52)['viaje'] as Map<String, dynamic>,
        ),
      ];
      Future<OperacionAsignada?> detalleAnterior(int _) => anterior.future;
      Future<OperacionAsignada?> detalleNuevo(int _) async => null;
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: revision,
            builder: (_, nueva, _) => ChoferShell(
              cargarViajes: nueva ? listaNueva : listaAnterior,
              cargarDetalle: nueva ? detalleNuevo : detalleAnterior,
              onSalir: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('viaje-41')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      revision.value = true;
      await tester.pumpAndSettle();
      expect(find.text('Detalle no disponible.'), findsOneWidget);
      anterior.complete(OperacionAsignada.fromJson(detalleJson()));
      await tester.pumpAndSettle();
      expect(find.text('Detalle no disponible.'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('viaje-52')), findsOneWidget);
      expect(find.byKey(const ValueKey('viaje-41')), findsNothing);
    },
  );

  testWidgets(
    'detalle fallido permite reintentar y salir delega sin desmontar por su cuenta',
    (tester) async {
      var intentos = 0;
      var salidas = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ChoferShell(
            cargarViajes: (_) async => [
              ViajeResumen.fromJson(
                detalleJson(id: 52)['viaje'] as Map<String, dynamic>,
              ),
            ],
            cargarDetalle: (id) async {
              expect(id, 52);
              if (++intentos == 1) throw StateError('Error simulado');
              return OperacionAsignada.fromJson(detalleJson(id: id));
            },
            onSalir: () => salidas++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('viaje-52')));
      await tester.pumpAndSettle();
      expect(find.text('No pudimos cargar el detalle.'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('detalle-52')), findsOneWidget);
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pump();
      expect(salidas, 1);
      expect(find.text('Detalle del viaje'), findsOneWidget);
      expect(intentos, 2);
    },
  );

  testWidgets('abre el ID elegido y volver conserva fecha y listado', (
    tester,
  ) async {
    final fechas = <DateTime>[];
    final ids = <int>[];
    var salidas = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ChoferShell(
          fechaInicial: DateTime(2026, 10, 30),
          cargarViajes: (fecha) async {
            fechas.add(fecha);
            return [
              ViajeResumen.fromJson(
                detalleJson()['viaje'] as Map<String, dynamic>,
              ),
            ];
          },
          cargarDetalle: (id) async {
            ids.add(id);
            return OperacionAsignada.fromJson(detalleJson(id: id));
          },
          onSalir: () => salidas++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('viaje-41')));
    await tester.pumpAndSettle();
    expect(ids, [41]);
    expect(find.text('Detalle del viaje'), findsOneWidget);
    expect(find.text('Iniciar viaje'), findsNothing);
    expect(find.text('Finalizar viaje'), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Fecha: 30/10/2026'), findsOneWidget);
    expect(fechas, [DateTime(2026, 10, 30)]);
    await tester.tap(find.text('Cerrar sesión'));
    expect(salidas, 1);
  });

  testWidgets(
    'permite salir con detalle pendiente y descarta respuesta tardía',
    (tester) async {
      final pendiente = Completer<OperacionAsignada?>();
      final activa = ValueNotifier(true);
      addTearDown(activa.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: activa,
            builder: (_, valor, _) => valor
                ? ChoferShell(
                    cargarViajes: (_) async => [
                      ViajeResumen.fromJson(
                        detalleJson()['viaje'] as Map<String, dynamic>,
                      ),
                    ],
                    cargarDetalle: (_) => pendiente.future,
                    onSalir: () => activa.value = false,
                  )
                : const Text('Sesión cerrada'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('viaje-41')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      pendiente.complete(OperacionAsignada.fromJson(detalleJson()));
      await tester.pumpAndSettle();
      expect(find.text('Sesión cerrada'), findsOneWidget);
      expect(find.text('Detalle del viaje'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
