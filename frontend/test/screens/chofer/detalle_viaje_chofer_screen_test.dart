import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_spacing.dart';
import 'package:frontend/models/chofer/operacion_asignada.dart';
import 'package:frontend/screens/chofer/detalle_viaje_chofer_screen.dart';

import '../../fixtures/chofer/operacion_asignada_fixture.dart';

OperacionAsignada detalle({int id = 41}) =>
    OperacionAsignada.fromJson(detalleJson(id: id));

Future<void> mostrar(
  WidgetTester tester,
  CargarDetalleViajeChofer cargar, {
  int id = 41,
}) => tester.pumpWidget(
  MaterialApp(
    home: DetalleViajeChoferScreen(idViaje: id, cargarDetalle: cargar),
  ),
);

void main() {
  testWidgets('los datos crecen con nombres largos y texto al 200 %', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final json = detalleJson();
    const nombre =
        'Parada ficticia de nombre muy extenso para comprobar '
        'que el texto ampliado se ajuste completo en varias líneas';
    (json['paradas'] as List).first['nombre_descripcion'] = nombre;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: DetalleViajeChoferScreen(
          idViaje: 41,
          cargarDetalle: (_) async => OperacionAsignada.fromJson(json),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('parada-11')),
      200,
    );
    final fila = find.byKey(const ValueKey('parada-11'));
    final texto = find.text('Parada 1: $nombre');
    expect(tester.getSize(fila).height, greaterThan(64));
    expect(
      tester.getRect(fila).contains(tester.getRect(texto).topLeft),
      isTrue,
    );
    expect(
      tester.getRect(fila).bottom,
      greaterThanOrEqualTo(tester.getRect(texto).bottom),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('integrante-71')),
      200,
    );
    expect(find.textContaining('Invitada Nómina'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  setUp(() {
    // El detalle largo cabe completo para comprobar secciones, sin scroll implícito.
  });

  testWidgets('carga el ID solicitado y aplica el tema del chofer', (
    tester,
  ) async {
    final pendiente = Completer<OperacionAsignada?>();
    int? consultado;
    await mostrar(tester, (id) {
      consultado = id;
      return pendiente.future;
    });
    expect(consultado, 41);
    final spinner = find.byType(CircularProgressIndicator);
    expect(spinner, findsOneWidget);
    expect(Theme.of(tester.element(spinner)).brightness, Brightness.dark);
    pendiente.complete(detalle());
    await tester.pumpAndSettle();
    expect(find.text('Viaje 41'), findsOneWidget);
    expect(find.text('Fecha: 30/10/2026 · 07:30'), findsOneWidget);
  });

  testWidgets('paradas en orden, listas separadas, cantidades y privacidad', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.binding.setSurfaceSize(const Size(1000, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final json = detalleJson();
      for (final p in json['pasajeros_con_reserva'] as List) {
        p['telefono'] = 'TEL-PRIVADO';
        p['email'] = 'CONTACTO-PRIVADO.test';
        p['direccion'] = 'DOMICILIO-PRIVADO';
      }
      final n = (json['integrantes_nomina'] as List).single;
      // Campos inesperados no se incorporan a la nómina ni se muestran.
      n['fotografia'] = 'foto-inventada';
      n['abordaje_registrado'] = true;
      n['id_reserva'] = 999;
      await mostrar(tester, (_) async => OperacionAsignada.fromJson(json));
      await tester.pumpAndSettle();
      final primera = find.byKey(const ValueKey('parada-11'));
      final segunda = find.byKey(const ValueKey('parada-12'));
      expect(
        tester.getTopLeft(primera).dy,
        lessThan(tester.getTopLeft(segunda).dy),
      );
      expect(
        tester.getSize(primera).height,
        closeTo(
          tester.getSize(find.text('Parada 1: Primera parada')).height + 8,
          0.01,
        ),
      );
      expect(find.text('Parada 1: Primera parada'), findsOneWidget);
      expect(find.text('Parada 2: Sin descripción'), findsOneWidget);
      expect(find.text('Pasajeros con reserva'), findsOneWidget);
      expect(find.text('Nómina independiente'), findsOneWidget);
      expect(find.text('Ana Prueba'), findsOneWidget);
      expect(find.textContaining('Invitada Nómina'), findsOneWidget);
      expect(find.text('DNI: 90000011'), findsOneWidget);
      expect(
        find.text('Reserva 61 · Consolidada · Parada reservada 1'),
        findsOneWidget,
      );
      expect(
        find.text('Reserva 62 · Provisional · Parada reservada 2'),
        findsOneWidget,
      );
      expect(find.text('Abordaje registrado'), findsOneWidget);
      expect(find.text('Sin abordaje registrado'), findsOneWidget);
      expect(find.text('Capacidad planificada: 18'), findsOneWidget);
      for (final texto in [
        'Reservas consolidadas: 1',
        'Reservas provisionales: 1',
        'Total de reservas: 2',
        'Integrantes de nómina: 1',
        'Abordajes registrados en reservas: 1',
      ]) {
        expect(find.text(texto), findsOneWidget);
      }
      for (final texto in [
        'TEL-PRIVADO',
        'CONTACTO-PRIVADO.test',
        'DOMICILIO-PRIVADO',
        'Ausente',
        'Disponibilidad',
        'Ocupación',
        'foto-inventada',
        'Reserva 999',
      ]) {
        expect(find.textContaining(texto), findsNothing);
      }
      final filaNomina = find.byKey(const ValueKey('integrante-71'));
      expect(
        find.descendant(of: filaNomina, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: filaNomina,
          matching: find.textContaining('abordaje'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: filaNomina,
          matching: find.textContaining('Reserva'),
        ),
        findsNothing,
      );
      expect(find.byType(Image), findsNothing);
      expect(find.bySemanticsLabel('Sin fotografía'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Fotografía referenciada, sin visualización'),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'horario omitido, capacidad null y listas vacías sin inferencias',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final json = detalleJson();
      (json['viaje'] as Map).remove('horario');
      json['capacidad_planificada'] = null;
      json['paradas'] = [];
      json['pasajeros_con_reserva'] = [];
      json['integrantes_nomina'] = [];
      json['cantidades'] = {
        'consolidadas': 0,
        'provisionales': 0,
        'total_reservas': 0,
        'total_nomina': 0,
        'abordajes_registrados': 0,
      };
      await mostrar(tester, (_) async => OperacionAsignada.fromJson(json));
      await tester.pumpAndSettle();
      expect(find.text('Fecha: 30/10/2026 · Sin horario'), findsOneWidget);
      expect(find.text('Capacidad planificada: Sin informar'), findsOneWidget);
      expect(find.text('No hay paradas informadas.'), findsOneWidget);
      expect(
        find.text('No hay pasajeros con reserva informados.'),
        findsOneWidget,
      );
      expect(
        find.text('No hay integrantes de nómina informados.'),
        findsOneWidget,
      );
      expect(find.text('Detalle no disponible.'), findsNothing);
    },
  );

  testWidgets('error saneado y reintento con el mismo ID', (tester) async {
    final ids = <int>[];
    await mostrar(tester, (id) async {
      ids.add(id);
      if (ids.length == 1) throw StateError('Error interno privado');
      return detalle(id: id);
    });
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar el detalle.'), findsOneWidget);
    expect(find.textContaining('Error interno privado'), findsNothing);
    final boton = find.widgetWithText(ElevatedButton, 'Reintentar');
    expect(
      tester.getSize(boton).height,
      greaterThanOrEqualTo(AppSpacing.driverTouchTarget),
    );
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(ids, [41, 41]);
    expect(find.text('Viaje 41'), findsOneWidget);
  });

  testWidgets(
    'null indica no disponible y permite reintentar sin revelar propiedad',
    (tester) async {
      var consultas = 0;
      await mostrar(tester, (_) async => ++consultas == 1 ? null : detalle());
      await tester.pumpAndSettle();
      expect(find.text('Detalle no disponible.'), findsOneWidget);
      expect(find.text('No pudimos cargar el detalle.'), findsNothing);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Viaje 41'), findsOneWidget);
    },
  );

  testWidgets('cambiar ID retira el contenido previo mientras carga', (
    tester,
  ) async {
    final siguiente = Completer<OperacionAsignada?>();
    Future<OperacionAsignada?> cargar(int id) =>
        id == 41 ? Future.value(detalle()) : siguiente.future;
    await mostrar(tester, cargar);
    await tester.pumpAndSettle();
    await mostrar(tester, cargar, id: 42);
    expect(find.text('Viaje 41'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    siguiente.complete(detalle(id: 42));
    await tester.pumpAndSettle();
    expect(find.text('Viaje 42'), findsOneWidget);
  });

  for (final cambio in ['id', 'fuente']) {
    for (final resultado in ['éxito', 'error', 'no disponible']) {
      testWidgets(
        'cambiar $cambio descarta $resultado de la consulta anterior',
        (tester) async {
          final anterior = Completer<OperacionAsignada?>();
          final ids = <int>[];
          Future<OperacionAsignada?> cargar(int id) {
            ids.add(id);
            return id == 41 ? anterior.future : Future.value(detalle(id: id));
          }

          await mostrar(tester, cargar);
          final idNuevo = cambio == 'id' ? 42 : 41;
          final jsonNuevo = detalleJson(id: idNuevo);
          (jsonNuevo['viaje'] as Map)['estado'] = 'finalizado';
          // En cambio de ID se mantiene la misma fuente; en cambio de fuente el ID es el mismo.
          if (cambio == 'id') {
            await mostrar(tester, cargar, id: idNuevo);
          } else {
            await mostrar(tester, (id) async {
              ids.add(id);
              return OperacionAsignada.fromJson(jsonNuevo);
            });
          }
          await tester.pumpAndSettle();
          if (resultado == 'error') {
            anterior.completeError(StateError('Fallo viejo'));
          } else {
            anterior.complete(resultado == 'éxito' ? detalle() : null);
          }
          await tester.pumpAndSettle();
          expect(ids, [41, idNuevo]);
          expect(find.byKey(ValueKey('detalle-$idNuevo')), findsOneWidget);
          if (cambio == 'fuente') {
            expect(find.text('Ida · Finalizado'), findsOneWidget);
          }
          expect(find.text('Reintentar'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final resultado in ['éxito', 'error', 'no disponible']) {
    testWidgets('$resultado después del desmontaje no actualiza la pantalla', (
      tester,
    ) async {
      final pendiente = Completer<OperacionAsignada?>();
      await mostrar(tester, (_) => pendiente.future);
      await tester.pumpWidget(const SizedBox());
      if (resultado == 'error') {
        pendiente.completeError(StateError('Fallo tras desmontaje'));
      } else {
        pendiente.complete(resultado == 'éxito' ? detalle() : null);
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('una fuente que devuelve otro viaje no expone su detalle', (
    tester,
  ) async {
    await mostrar(tester, (_) async => detalle(id: 99));
    await tester.pumpAndSettle();
    expect(find.text('Viaje 99'), findsNothing);
    expect(find.text('No pudimos cargar el detalle.'), findsOneWidget);
  });

  testWidgets('contenido largo puede desplazarse en una pantalla pequeña', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await mostrar(tester, (_) async => detalle());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('integrante-71')),
      300,
    );
    expect(find.textContaining('Invitada Nómina'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
