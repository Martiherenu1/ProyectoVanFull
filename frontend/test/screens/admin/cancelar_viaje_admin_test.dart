import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/screens/admin/viajes_dia_admin_screen.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';

import 'viajes_dia_admin_screen_test.dart' as datos;

void main() {
  Future<void> abrir(
    WidgetTester tester,
    Future<ViajeResumen> Function(int) cancelar, {
    String estado = 'programado',
  }) async {
    var actual = datos.viaje(10, estado: estado);
    await tester.pumpWidget(
      MaterialApp(
        home: ViajesDiaAdminScreen(
          fecha: DateTime(2026, 10, 30),
          cargarViajes: (_) async => [actual],
          onViajeSeleccionado: (_) {},
          cancelarViaje: (id) async {
            final resultado = await cancelar(id);
            actual = resultado;
            return resultado;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('10').first);
    await tester.pumpAndSettle();
  }

  Future<void> confirmar(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('cancelar-viaje')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-cancelacion')));
    await tester.pumpAndSettle();
  }

  testWidgets('éxito actualiza detalle y listado', (tester) async {
    var llamadas = 0;
    await abrir(tester, (id) async {
      llamadas++;
      return datos.viaje(id, estado: 'cancelado');
    });
    await confirmar(tester);
    expect(llamadas, 1);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dato-viaje-Estado')),
        matching: find.text('Cancelado'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('cancelar-viaje')), findsNothing);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelado'), findsOneWidget);
  });
  testWidgets('volver no envía', (tester) async {
    var llamadas = 0;
    await abrir(tester, (id) async {
      llamadas++;
      return datos.viaje(id);
    });
    await tester.tap(find.byKey(const Key('cancelar-viaje')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(llamadas, 0);
  });
  for (final codigo in ['ESTADO_VIAJE_INVALIDO', 'VIAJE_CON_COMPROMISOS']) {
    testWidgets('muestra error $codigo', (tester) async {
      await abrir(
        tester,
        (_) async => throw ApiException(
          statusCode: 409,
          codigo: codigo,
          mensaje: codigo,
        ),
      );
      await confirmar(tester);
      expect(find.text(codigo), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('dato-viaje-Estado')),
          matching: find.text('Programado'),
        ),
        findsOneWidget,
      );
    });
  }
  testWidgets('oculta botón en cancelado', (tester) async {
    await abrir(tester, (id) async => datos.viaje(id), estado: 'cancelado');
    expect(find.byKey(const Key('cancelar-viaje')), findsNothing);
  });
  testWidgets('evita doble envío y refresca listado tras cerrar el detalle', (
    tester,
  ) async {
    final respuesta = Completer<ViajeResumen>();
    var llamadas = 0;
    await abrir(tester, (_) {
      llamadas++;
      return respuesta.future;
    });
    await confirmar(tester);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('cancelar-viaje')))
          .onPressed,
      isNull,
    );
    expect(llamadas, 1);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    respuesta.complete(datos.viaje(10, estado: 'cancelado'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Cancelado'), findsOneWidget);
    expect(find.byKey(const Key('detalle-viaje-10')), findsNothing);
  });

  testWidgets('no recarga si se desmontó la pantalla original', (tester) async {
    final respuesta = Completer<ViajeResumen>();
    var cargas = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ViajesDiaAdminScreen(
          fecha: DateTime(2026, 10, 30),
          cargarViajes: (_) async {
            cargas++;
            return [datos.viaje(10)];
          },
          onViajeSeleccionado: (_) {},
          cancelarViaje: (_) => respuesta.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('10').first);
    await tester.pumpAndSettle();
    await confirmar(tester);
    await tester.pumpWidget(const MaterialApp(home: Text('Otra pantalla')));
    await tester.pumpAndSettle();
    respuesta.complete(datos.viaje(10, estado: 'cancelado'));
    await tester.pumpAndSettle();
    expect(cargas, 1);
    expect(find.text('Otra pantalla'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
