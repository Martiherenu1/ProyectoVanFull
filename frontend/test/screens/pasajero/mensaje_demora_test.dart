import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/pasajero/mensaje_demora.dart';

void main() {
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
    await t.tap(find.text('Actualizar información del viaje'));
    await t.pumpAndSettle();
    expect(find.text('Reporte'), findsNothing);
  });
}
