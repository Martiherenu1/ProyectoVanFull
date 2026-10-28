import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/core/theme/app_spacing.dart';
import 'package:frontend/models/admin/viaje_admin_resumen.dart';
import 'package:frontend/models/admin/viaje_update.dart';
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
  int? capacidad = 18,
}) => ViajeAdminResumen.fromJson({
  'id_viaje': id,
  'id_servicio': 2,
  'id_recorrido': 3,
  'id_vehiculo': idVehiculo,
  'id_chofer': idChofer,
  'fecha': fecha,
  'horario': ?horario,
  'sentido': sentido,
  'estado': estado,
  'capacidad_planificada': capacidad,
});

Future<void> mostrar(
  WidgetTester tester,
  CargarViajesDelDia cargar, {
  DateTime? fecha,
  ValueChanged<int>? seleccionar,
  ActualizarViaje? actualizar,
}) => tester.pumpWidget(
  MaterialApp(
    home: ViajesDiaAdminScreen(
      fecha: fecha ?? DateTime(2026, 10, 30, 18),
      cargarViajes: cargar,
      onViajeSeleccionado: seleccionar ?? (_) {},
      actualizarViaje: actualizar,
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

  testWidgets('selecciona por ID y muestra el detalle de solo lectura', (
    tester,
  ) async {
    int? seleccionado;
    await mostrar(
      tester,
      (_) async => [
        viaje(41),
        viaje(
          42,
          idVehiculo: null,
          idChofer: null,
          horario: null,
          sentido: 'VUELTA',
          estado: 'cancelado',
        ),
      ],
      seleccionar: (id) => seleccionado = id,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('42'));
    await tester.pumpAndSettle();

    expect(seleccionado, 42);
    final detalle = find.byKey(const ValueKey('detalle-viaje-42'));
    expect(detalle, findsOneWidget);
    expect(
      find.descendant(of: detalle, matching: find.text('Fecha: 30/10/2026')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detalle, matching: find.text('Horario: Sin horario')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detalle, matching: find.text('Estado: Cancelado')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detalle, matching: find.text('Sentido: Vuelta')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detalle, matching: find.text('Servicio: ID 2')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detalle, matching: find.text('Recorrido: ID 3')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: detalle,
        matching: find.text('Vehículo: Sin asignar'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detalle, matching: find.text('Chofer: Sin asignar')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
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

  testWidgets('el selector cambia la fecha y descarta el resultado anterior', (
    tester,
  ) async {
    final anterior = Completer<List<ViajeResumen>>();
    final fechas = <DateTime>[];
    Future<List<ViajeResumen>> cargar(DateTime fecha) {
      fechas.add(fecha);
      return fechas.length == 1
          ? anterior.future
          : Future.value([viaje(52, fecha: '2026-10-31')]);
    }

    await mostrar(tester, cargar);
    await tester.tap(find.byKey(const ValueKey('seleccionar-fecha-viajes')));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('31'));
    await tester.tap(find.widgetWithText(TextButton, 'OK'));
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

  testWidgets('edita un programado, quita opcionales y refresca el listado', (
    tester,
  ) async {
    var cargas = 0;
    ViajeUpdate? enviada;
    final actualizado = viaje(
      41,
      fecha: '2026-10-31',
      horario: null,
      sentido: 'VUELTA',
      idChofer: null,
      idVehiculo: null,
      capacidad: null,
    );
    await mostrar(
      tester,
      (_) async {
        cargas++;
        return [cargas == 1 ? viaje(41) : actualizado];
      },
      actualizar: (id, solicitud) async {
        expect(id, 41);
        enviada = solicitud;
        return actualizado;
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('41'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editar-viaje')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('editar-fecha')), '2026-10-31');
    await tester.enterText(find.byKey(const Key('editar-horario')), '');
    await tester.enterText(find.byKey(const Key('editar-capacidad')), '');
    await tester.enterText(find.byKey(const Key('editar-chofer')), '');
    await tester.enterText(find.byKey(const Key('editar-vehiculo')), '');
    final sentido = find.byKey(const Key('editar-sentido'));
    await tester.ensureVisible(sentido);
    await tester.pumpAndSettle();
    await tester.tap(sentido);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vuelta').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guardar-viaje')));
    await tester.pumpAndSettle();

    expect(enviada?.toJson(), {
      'fecha': '2026-10-31',
      'horario': null,
      'sentido': 'VUELTA',
      'capacidad_planificada': null,
      'id_chofer': null,
      'id_vehiculo': null,
    });
    expect(cargas, 2);
    expect(find.text('Fecha: 31/10/2026'), findsOneWidget);
    expect(find.text('Capacidad: Sin definir'), findsOneWidget);
  });

  testWidgets('muestra el mensaje contractual del backend al guardar', (
    tester,
  ) async {
    await mostrar(
      tester,
      (_) async => [viaje(41)],
      actualizar: (_, _) async => throw const ApiException(
        statusCode: 409,
        codigo: 'ESTADO_VIAJE_INVALIDO',
        mensaje: 'Solo se modifican viajes programados.',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('41'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editar-viaje')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guardar-viaje')));
    await tester.pumpAndSettle();

    expect(find.text('Solo se modifican viajes programados.'), findsOneWidget);
    expect(find.byKey(const Key('editar-fecha')), findsOneWidget);
  });

  testWidgets('no permite editar un viaje que no está programado', (
    tester,
  ) async {
    await mostrar(
      tester,
      (_) async => [viaje(41, estado: 'en_curso')],
      actualizar: (_, _) async => viaje(41),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('41'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('editar-viaje')), findsNothing);
  });
}
