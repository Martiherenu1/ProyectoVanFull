import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_spacing.dart';
import 'package:frontend/screens/admin/crear_viaje_admin_screen.dart';

typedef DatosCreacion = ({
  int idServicio,
  int idRecorrido,
  int? idVehiculo,
  int? idChofer,
  DateTime fecha,
  String? horario,
  String sentido,
  int? capacidadPlanificada,
});

CrearViaje creadorSimulado(Future<void> Function(DatosCreacion) responder) =>
    ({
      required idServicio,
      required idRecorrido,
      required idVehiculo,
      required idChofer,
      required fecha,
      required horario,
      required sentido,
      required capacidadPlanificada,
    }) => responder((
      idServicio: idServicio,
      idRecorrido: idRecorrido,
      idVehiculo: idVehiculo,
      idChofer: idChofer,
      fecha: fecha,
      horario: horario,
      sentido: sentido,
      capacidadPlanificada: capacidadPlanificada,
    ));

Future<void> mostrar(WidgetTester tester, CrearViaje crearViaje) =>
    tester.pumpWidget(
      MaterialApp(home: CrearViajeAdminScreen(crearViaje: crearViaje)),
    );

Future<void> completarObligatorios(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('id-servicio')), '1');
  await tester.enterText(find.byKey(const Key('id-recorrido')), '2');
  await tester.enterText(find.byKey(const Key('fecha')), '2026-10-30');
  await tester.tap(find.byKey(const Key('sentido')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ida').last);
  await tester.pumpAndSettle();
}

Future<void> tocarCrear(WidgetTester tester) async {
  final boton = find.byKey(const Key('crear-viaje'));
  await tester.ensureVisible(boton);
  await tester.pump();
  await tester.tap(boton);
}

void main() {
  testWidgets('muestra solo los campos de ViajeCreate con tema admin', (
    tester,
  ) async {
    await mostrar(tester, creadorSimulado((_) async {}));

    expect(find.text('Crear viaje'), findsNWidgets(2));
    expect(find.text('Servicio (ID)'), findsOneWidget);
    expect(find.text('Recorrido (ID)'), findsOneWidget);
    expect(find.text('Vehículo (ID, opcional)'), findsOneWidget);
    expect(find.text('Chofer (ID, opcional)'), findsOneWidget);
    expect(find.text('Fecha (AAAA-MM-DD)'), findsOneWidget);
    expect(find.text('Horario (opcional)'), findsOneWidget);
    expect(find.text('Sentido'), findsOneWidget);
    expect(find.text('Capacidad planificada (opcional)'), findsOneWidget);

    final boton = find.byKey(const Key('crear-viaje'));
    expect(
      tester.getSize(boton).height,
      greaterThanOrEqualTo(AppSpacing.adminRowHeight),
    );
    expect(Theme.of(tester.element(boton)).brightness, Brightness.light);
  });

  testWidgets('valida solo tipos, requeridos y fecha del contrato', (
    tester,
  ) async {
    var llamadas = 0;
    await mostrar(
      tester,
      creadorSimulado((_) async {
        llamadas++;
      }),
    );

    await tester.enterText(find.byKey(const Key('id-servicio')), 'uno');
    await tester.enterText(find.byKey(const Key('fecha')), '30/10/2026');
    await tocarCrear(tester);
    await tester.pump();

    expect(find.text('Ingresá un número entero.'), findsOneWidget);
    expect(find.text('Campo obligatorio.'), findsOneWidget);
    expect(find.text('Usá el formato AAAA-MM-DD.'), findsOneWidget);
    expect(find.text('Seleccioná un sentido.'), findsOneWidget);
    expect(llamadas, 0);
  });

  testWidgets('entrega todos los campos mediante la función inyectada', (
    tester,
  ) async {
    final recibidos = <String, Object?>{};
    await mostrar(
      tester,
      creadorSimulado((datos) async {
        recibidos.addAll({
          'servicio': datos.idServicio,
          'recorrido': datos.idRecorrido,
          'vehiculo': datos.idVehiculo,
          'chofer': datos.idChofer,
          'fecha': datos.fecha,
          'horario': datos.horario,
          'sentido': datos.sentido,
          'capacidad': datos.capacidadPlanificada,
        });
      }),
    );
    await completarObligatorios(tester);
    await tester.enterText(find.byKey(const Key('id-vehiculo')), '3');
    await tester.enterText(find.byKey(const Key('id-chofer')), '4');
    await tester.enterText(find.byKey(const Key('horario')), '07:30');
    await tester.enterText(
      find.byKey(const Key('capacidad-planificada')),
      '18',
    );

    await tocarCrear(tester);
    await tester.pumpAndSettle();

    expect(recibidos, {
      'servicio': 1,
      'recorrido': 2,
      'vehiculo': 3,
      'chofer': 4,
      'fecha': DateTime(2026, 10, 30),
      'horario': '07:30',
      'sentido': 'IDA',
      'capacidad': 18,
    });
    expect(find.byKey(const Key('creacion-exitosa')), findsOneWidget);
  });

  testWidgets('ADJ-03 permite enviar chofer y vehículo pendientes', (
    tester,
  ) async {
    int? vehiculo = -1;
    int? chofer = -1;
    await mostrar(
      tester,
      creadorSimulado((datos) async {
        vehiculo = datos.idVehiculo;
        chofer = datos.idChofer;
      }),
    );
    await completarObligatorios(tester);
    await tocarCrear(tester);
    await tester.pumpAndSettle();

    expect(vehiculo, isNull);
    expect(chofer, isNull);
    expect(find.byKey(const Key('creacion-exitosa')), findsOneWidget);
  });

  testWidgets('bloquea envíos duplicados mientras espera', (tester) async {
    final pendiente = Completer<void>();
    var llamadas = 0;
    await mostrar(
      tester,
      creadorSimulado((_) {
        llamadas++;
        return pendiente.future;
      }),
    );
    await completarObligatorios(tester);

    await tocarCrear(tester);
    await tester.pump();
    await tocarCrear(tester);
    expect(llamadas, 1);
    expect(find.text('Creando viaje…'), findsOneWidget);

    pendiente.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('creacion-exitosa')), findsOneWidget);
  });

  testWidgets('muestra error saneado y permite reintentar', (tester) async {
    var llamadas = 0;
    await mostrar(
      tester,
      creadorSimulado((_) async {
        llamadas++;
        if (llamadas == 1) throw Exception('detalle interno privado');
      }),
    );
    await completarObligatorios(tester);

    await tocarCrear(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('creacion-error')), findsOneWidget);
    expect(find.textContaining('detalle interno privado'), findsNothing);

    await tocarCrear(tester);
    await tester.pumpAndSettle();
    expect(llamadas, 2);
    expect(find.byKey(const Key('creacion-exitosa')), findsOneWidget);
    expect(find.byKey(const Key('creacion-error')), findsNothing);
  });
}
