import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_spacing.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';
import 'package:frontend/screens/chofer/viajes_chofer_screen.dart';

ViajeResumen viaje(
  int id, {
  String? horario = '07:30',
  String fecha = '2026-10-30',
}) => ViajeResumen.fromJson({
  'id_viaje': id,
  'id_servicio': 2,
  'id_recorrido': 3,
  'fecha': fecha,
  'horario': ?horario,
  'sentido': 'IDA',
  'estado': 'en_curso',
});

Future<void> mostrar(
  WidgetTester tester,
  CargarViajesChofer cargar, {
  ValueChanged<int>? seleccionar,
  DateTime? fechaInicial,
}) => tester.pumpWidget(
  MaterialApp(
    home: ViajesChoferScreen(
      fechaInicial: fechaInicial ?? DateTime(2026, 10, 30, 15),
      cargarViajes: cargar,
      onViajeSeleccionado: seleccionar ?? (_) {},
    ),
  ),
);

Future<void> elegir31(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('seleccionar-fecha')));
  // Puede haber una consulta pendiente y un spinner detrás del diálogo.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('31'));
  await tester.tap(find.text('Consultar'));
  // No esperar a que termine un Future controlado por el test.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('carga la fecha explícita, muestra vacío y usa tema de chofer', (
    tester,
  ) async {
    final pendiente = Completer<List<ViajeResumen>>();
    DateTime? consultada;
    await mostrar(
      tester,
      (fecha) {
        consultada = fecha;
        return pendiente.future;
      },
      // Fecha de calendario inyectada: no convertir este instante a hora local.
      fechaInicial: DateTime.utc(2026, 10, 30, 0, 15),
    );
    expect(consultada, DateTime(2026, 10, 30));
    expect(consultada?.isUtc, isFalse);
    expect(find.text('Fecha: 30/10/2026'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final control = find.byKey(const ValueKey('seleccionar-fecha'));
    expect(tester.getSize(control).height, greaterThanOrEqualTo(64));
    expect(Theme.of(tester.element(control)).brightness, Brightness.dark);
    pendiente.complete([]);
    await tester.pumpAndSettle();
    expect(
      find.text('No tenés viajes asignados para esta fecha.'),
      findsOneWidget,
    );
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('horario omitido, orden e ID correcto al seleccionar', (
    tester,
  ) async {
    int? elegido;
    await mostrar(
      tester,
      (_) async => [viaje(42), viaje(41, horario: null)],
      seleccionar: (id) => elegido = id,
    );
    await tester.pumpAndSettle();
    expect(find.text('07:30'), findsOneWidget);
    expect(find.text('Sin horario'), findsOneWidget);
    expect(find.text('Viaje 41 · Ida · En curso'), findsOneWidget);
    final filas = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(filas.map((fila) => fila.key), [
      const ValueKey('viaje-42'),
      const ValueKey('viaje-41'),
    ]);
    final fila = find.byKey(const ValueKey('viaje-41'));
    expect(
      tester.getSize(fila).height,
      greaterThanOrEqualTo(AppSpacing.driverRowHeight),
    );
    await tester.tap(fila);
    expect(elegido, 41);
  });

  testWidgets(
    'cambiar fecha no permite que un éxito anterior sustituya la nueva',
    (tester) async {
      final anterior = Completer<List<ViajeResumen>>();
      final nueva = Completer<List<ViajeResumen>>();
      final fechas = <DateTime>[];
      await mostrar(tester, (fecha) {
        fechas.add(fecha);
        return fechas.length == 1 ? anterior.future : nueva.future;
      });
      await elegir31(tester);
      expect(fechas, [DateTime(2026, 10, 30), DateTime(2026, 10, 31)]);
      nueva.complete([viaje(52, fecha: '2026-10-31')]);
      await tester.pumpAndSettle();
      anterior.complete([viaje(51)]);
      await tester.pumpAndSettle();
      expect(find.text('Fecha: 31/10/2026'), findsOneWidget);
      expect(find.byKey(const ValueKey('viaje-52')), findsOneWidget);
      expect(find.byKey(const ValueKey('viaje-51')), findsNothing);
    },
  );

  testWidgets('un error atrasado tampoco oculta el listado de la nueva fecha', (
    tester,
  ) async {
    final anterior = Completer<List<ViajeResumen>>();
    var llamadas = 0;
    await mostrar(tester, (_) {
      llamadas++;
      return llamadas == 1
          ? anterior.future
          : Future.value([viaje(52, fecha: '2026-10-31')]);
    });
    await elegir31(tester);
    await tester.pumpAndSettle();
    anterior.completeError(Exception('Fallo de la consulta vieja'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('viaje-52')), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets(
    'error y reintento conservan fecha y no exponen el error interno',
    (tester) async {
      final fechas = <DateTime>[];
      await mostrar(tester, (fecha) async {
        fechas.add(fecha);
        if (fechas.length == 1) throw Exception('Detalle interno privado');
        return [viaje(41)];
      });
      await tester.pumpAndSettle();
      expect(find.text('Detalle interno privado'), findsNothing);
      final reintentar = find.widgetWithText(ElevatedButton, 'Reintentar');
      expect(tester.getSize(reintentar).height, greaterThanOrEqualTo(64));
      await tester.tap(reintentar);
      await tester.pumpAndSettle();
      expect(fechas, [DateTime(2026, 10, 30), DateTime(2026, 10, 30)]);
      expect(find.byKey(const ValueKey('viaje-41')), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    },
  );

  testWidgets(
    'al cambiar fecha se retira el listado anterior durante la carga',
    (tester) async {
      final nueva = Completer<List<ViajeResumen>>();
      var llamadas = 0;
      await mostrar(tester, (_) {
        llamadas++;
        return llamadas == 1 ? Future.value([viaje(41)]) : nueva.future;
      });
      await tester.pumpAndSettle();
      await elegir31(tester);
      expect(find.byKey(const ValueKey('viaje-41')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      nueva.complete([]);
      await tester.pumpAndSettle();
      expect(
        find.text('No tenés viajes asignados para esta fecha.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'una respuesta después de desmontar la pantalla no produce errores',
    (tester) async {
      final pendiente = Completer<List<ViajeResumen>>();
      await mostrar(tester, (_) => pendiente.future);
      await tester.pumpWidget(const SizedBox());
      pendiente.complete([viaje(41)]);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('un error después de desmontar la pantalla no produce errores', (
    tester,
  ) async {
    final pendiente = Completer<List<ViajeResumen>>();
    await mostrar(tester, (_) => pendiente.future);
    await tester.pumpWidget(const SizedBox());
    pendiente.completeError(Exception('Consulta de una pantalla desmontada'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reemplazar la fuente invalida la consulta anterior', (
    tester,
  ) async {
    final anterior = Completer<List<ViajeResumen>>();
    await mostrar(tester, (_) => anterior.future);
    DateTime? consultada;
    await mostrar(tester, (fecha) async {
      consultada = fecha;
      return [viaje(42)];
    });
    await tester.pumpAndSettle();
    anterior.complete([viaje(41)]);
    await tester.pumpAndSettle();
    expect(consultada, DateTime(2026, 10, 30));
    expect(find.byKey(const ValueKey('viaje-42')), findsOneWidget);
    expect(find.byKey(const ValueKey('viaje-41')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
