import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/gps/ubicacion_viaje.dart';
import 'package:frontend/screens/gps/ubicacion_screen.dart';

UbicacionViaje dato(int id) =>
    UbicacionViaje(id, 0, 0, DateTime.utc(2026), true, null);
void main() {
  testWidgets(
    'polling espera primera posición y revocación borra coordenadas',
    (t) async {
      var consultas = 0;
      Future<UbicacionViaje> leer(int id) async {
        consultas++;
        if (consultas == 1) {
          throw const ApiException(
            statusCode: 404,
            codigo: 'UBICACION_NO_DISPONIBLE',
            mensaje: '',
          );
        }
        if (consultas == 3) {
          throw const ApiException(
            statusCode: 403,
            codigo: 'SIN_PERMISO',
            mensaje: '',
          );
        }
        return dato(id);
      }

      await t.pumpWidget(
        MaterialApp(home: UbicacionScreen(idViaje: 1, consultar: leer)),
      );
      await t.pump();
      expect(find.textContaining('Todavía no hay'), findsOneWidget);
      await t.pump(const Duration(seconds: 10));
      await t.pump();
      expect(find.textContaining('Última posición:'), findsOneWidget);
      expect(find.text('ETA no disponible.'), findsOneWidget);
      await t.pump(const Duration(seconds: 10));
      await t.pump();
      expect(find.textContaining('Última posición:'), findsNothing);
      await t.pump(const Duration(seconds: 20));
      expect(consultas, 3);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('desmontaje descarta una consulta pendiente', (t) async {
    final pendiente = Completer<UbicacionViaje>();
    await t.pumpWidget(
      MaterialApp(
        home: UbicacionScreen(idViaje: 1, consultar: (_) => pendiente.future),
      ),
    );
    await t.pumpWidget(const SizedBox());
    pendiente.complete(dato(1));
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
