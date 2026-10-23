import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_spacing.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';
import 'package:frontend/screens/admin/viajes_dia_admin_screen.dart';

ViajeResumen viaje(
  int id, {
  int? idVehiculo = 8,
  int? idChofer = 12,
  String? horario = '07:30',
  String fecha = '2026-10-30',
  String sentido = 'IDA',
  String estado = 'programado',
}) => ViajeResumen.fromJson({
  'id_viaje': id,
  'id_servicio': 2,
  'id_recorrido': 3,
  'id_vehiculo': idVehiculo,
  'id_chofer': idChofer,
  'fecha': fecha,
  'horario': ?horario,
  'sentido': sentido,
  'estado': estado,
});

Future<void> mostrar(
  WidgetTester tester,
  CargarViajesDelDia cargar, {
  DateTime? fecha,
  ValueChanged<int>? seleccionar,
}) => tester.pumpWidget(
  MaterialApp(
    home: ViajesDiaAdminScreen(
      fecha: fecha ?? DateTime(2026, 10, 30, 18),
      cargarViajes: cargar,
      onViajeSeleccionado: seleccionar ?? (_) {},
    ),
  ),
);

void main() {
  testWidgets(
    'consulta la fecha explícita, muestra carga, vacío y tema admin',
    (tester) async {
      final pendiente = Completer<List<ViajeResumen>>();
      DateTime? consultada;
      await mostrar(tester, (fecha) {
        consultada = fecha;
        return pendiente.future;
      });

      expect(consultada, DateTime(2026, 10, 30));
      expect(find.text('Fecha: 30/10/2026'), findsOneWidget);
      final progreso = find.byType(CircularProgressIndicator);
      expect(progreso, findsOneWidget);
      expect(Theme.of(tester.element(progreso)).brightness, Brightness.light);

      pendiente.complete([]);
      await tester.pumpAndSettle();
      expect(
        find.text('No hay viajes registrados para esta fecha.'),
        findsOneWidget,
      );
      expect(find.byType(DataTable), findsNothing);
    },
  );

  testWidgets('muestra datos contratados y asignaciones pendientes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await mostrar(
        tester,
        (_) async => [
          viaje(41),
          viaje(42, idChofer: null, horario: null, sentido: 'VUELTA'),
          viaje(43, idVehiculo: null, idChofer: null),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('07:30'), findsNWidgets(2));
      expect(find.text('Sin horario'), findsOneWidget);
      expect(find.text('Ida'), findsNWidgets(2));
      expect(find.text('Vuelta'), findsOneWidget);
      expect(find.text('Programado'), findsNWidgets(3));
      expect(find.text('ID 2'), findsNWidgets(3));
      expect(find.text('ID 3'), findsNWidgets(3));
      expect(
        find.bySemanticsLabel(RegExp('Vehículo sin asignar')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Chofer sin asignar')),
        findsNWidgets(2),
      );

      final tabla = tester.widget<DataTable>(find.byType(DataTable));
      expect(tabla.headingRowHeight, AppSpacing.adminRowHeight);
      expect(tabla.dataRowMinHeight, AppSpacing.adminRowHeight);
      expect(tabla.dataRowMaxHeight, AppSpacing.adminRowHeight);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('selecciona el viaje por ID mediante el callback', (
    tester,
  ) async {
    int? seleccionado;
    await mostrar(
      tester,
      (_) async => [viaje(41), viaje(42)],
      seleccionar: (id) => seleccionado = id,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('42'));
    expect(seleccionado, 42);
  });

  testWidgets('error saneado y reintento conservan la fecha', (tester) async {
    final fechas = <DateTime>[];
    await mostrar(tester, (fecha) async {
      fechas.add(fecha);
      if (fechas.length == 1) throw Exception('Detalle interno privado');
      return [viaje(41)];
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('Detalle interno privado'), findsNothing);
    expect(
      find.text('No pudimos cargar los viajes. Volvé a intentar.'),
      findsOneWidget,
    );
    final reintentar = find.widgetWithText(ElevatedButton, 'Reintentar');
    expect(
      tester.getSize(reintentar).height,
      greaterThanOrEqualTo(AppSpacing.adminRowHeight),
    );
    await tester.tap(reintentar);
    await tester.pumpAndSettle();

    expect(fechas, [DateTime(2026, 10, 30), DateTime(2026, 10, 30)]);
    expect(find.text('41'), findsOneWidget);
  });

  testWidgets('cambiar fecha descarta el resultado anterior', (tester) async {
    final anterior = Completer<List<ViajeResumen>>();
    final fechas = <DateTime>[];
    Future<List<ViajeResumen>> cargar(DateTime fecha) {
      fechas.add(fecha);
      return fechas.length == 1
          ? anterior.future
          : Future.value([viaje(52, fecha: '2026-10-31')]);
    }

    await mostrar(tester, cargar);
    await mostrar(tester, cargar, fecha: DateTime(2026, 10, 31));
    await tester.pumpAndSettle();
    anterior.complete([viaje(51)]);
    await tester.pumpAndSettle();

    expect(fechas, [DateTime(2026, 10, 30), DateTime(2026, 10, 31)]);
    expect(find.text('Fecha: 31/10/2026'), findsOneWidget);
    expect(find.text('52'), findsOneWidget);
    expect(find.text('51'), findsNothing);
  });

  testWidgets('una respuesta tras desmontar no actualiza la pantalla', (
    tester,
  ) async {
    final pendiente = Completer<List<ViajeResumen>>();
    await mostrar(tester, (_) => pendiente.future);
    await tester.pumpWidget(const SizedBox());
    pendiente.complete([viaje(41)]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
