import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/pasajero/mensaje_demora.dart';

void main() {
  testWidgets('distingue carga, ausencia y error con reintento explícito', (
    t,
  ) async {
    final consulta = Completer<String?>();
    var llamadas = 0;
    var fallar = false;
    Future<String?> cargar(int _) {
      llamadas++;
      return fallar ? Future.error(Exception('Controlado')) : consulta.future;
    }

    Widget vista(int viaje) => MaterialApp(
      home: MensajeDemora(viaje: viaje, cargar: cargar),
    );
    await t.pumpWidget(vista(1));
    expect(find.text('Consultando reportes de demora…'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    consulta.complete(null);
    await t.pumpAndSettle();
    expect(
      find.text('No hay reportes de demora para mostrar.'),
      findsOneWidget,
    );
    expect(find.byType(TextButton), findsNothing);
    fallar = true;
    await t.pumpWidget(vista(2));
    await t.pumpAndSettle();
    expect(find.textContaining('No pudimos consultar'), findsOneWidget);
    expect(find.text('No hay reportes de demora para mostrar.'), findsNothing);
    expect(find.text('Actualizar reporte de demora'), findsNothing);
    final antes = llamadas;
    await t.tap(find.text('Reintentar consulta'));
    await t.pumpAndSettle();
    expect(llamadas, antes + 1);
    expect(find.textContaining('No pudimos consultar'), findsOneWidget);
  });

  testWidgets(
    'actualizar reporte borra contenido previo y distingue respuesta sin reporte',
    (t) async {
      var mensaje =
          'Reporte del 15/11/2026 a las 13:05; situación actual no confirmada.';
      Future<String?> cargar(int _) async => mensaje.isEmpty ? null : mensaje;
      await t.pumpWidget(
        MaterialApp(home: MensajeDemora(viaje: 1, cargar: cargar)),
      );
      await t.pumpAndSettle();
      expect(find.text(mensaje), findsOneWidget);
      expect(find.text('Actualizar reporte de demora'), findsOneWidget);
      expect(find.text('Actualizar información del viaje'), findsNothing);
      mensaje = '';
      await t.tap(find.text('Actualizar reporte de demora'));
      await t.pumpAndSettle();
      expect(find.textContaining('Reporte del 15/11'), findsNothing);
      expect(
        find.text('No hay reportes de demora para mostrar.'),
        findsOneWidget,
      );
      expect(find.byType(TextButton), findsNothing);
    },
  );

  testWidgets('muestra mensaje contextual sin listado; descarta otra cuenta', (
    t,
  ) async {
    final old = Completer<String?>();
    await t.pumpWidget(
      MaterialApp(
        home: MensajeDemora(
          key: const ValueKey('cuenta1'),
          viaje: 1,
          cargar: (_) => old.future,
        ),
      ),
    );
    await t.pumpWidget(
      MaterialApp(
        home: MensajeDemora(
          key: const ValueKey('cuenta2'),
          viaje: 2,
          cargar: (_) async => 'Reporte fechado',
        ),
      ),
    );
    await t.pumpAndSettle();
    old.complete('Dato de cuenta anterior');
    await t.pumpAndSettle();
    expect(find.text('Reporte fechado'), findsOneWidget);
    expect(find.text('Dato de cuenta anterior'), findsNothing);
  });
  testWidgets('sin mensaje o permiso no conserva contenido antiguo', (t) async {
    var allowed = true;
    await t.pumpWidget(
      MaterialApp(
        home: MensajeDemora(
          viaje: 1,
          cargar: (_) async {
            if (!allowed) {
              throw Exception('403');
            }
            return 'Reporte';
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Reporte'), findsOneWidget);
    allowed = false;
    await t.tap(find.text('Actualizar reporte de demora'));
    await t.pumpAndSettle();
    expect(find.text('Reporte'), findsNothing);
  });
}
