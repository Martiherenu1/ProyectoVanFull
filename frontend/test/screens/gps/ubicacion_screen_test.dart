import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/gps/eta_reserva.dart';
import 'package:frontend/models/gps/ubicacion_viaje.dart';
import 'package:frontend/screens/gps/ubicacion_screen.dart';

UbicacionViaje dato(int id) =>
    UbicacionViaje(id, 0, 0, DateTime.utc(2026), true, null);
void main() {
  testWidgets('un 404 de ETA previo a reanudar no retira el seguimiento', (
    t,
  ) async {
    const sinAcceso = ApiException(
      statusCode: 404,
      codigo: 'ETA_NO_DISPONIBLE',
      mensaje: '',
    );
    final etaAnterior = Completer<EtaReserva>();
    var consultasEta = 0;
    await t.pumpWidget(
      MaterialApp(
        home: UbicacionScreen(
          idViaje: 1,
          consultar: (id) async => dato(id),
          consultarEta: () async {
            consultasEta++;
            if (consultasEta == 1) return etaAnterior.future;
            if (consultasEta > 2) throw sinAcceso;
            return const EtaReserva(
              ascenso: 4,
              destino: null,
              ascensoPasado: false,
              destinoPasado: false,
              vigencia: Duration(seconds: 30),
            );
          },
        ),
      ),
    );
    await t.pump();
    expect(consultasEta, 1);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(consultasEta, 1);

    etaAnterior.completeError(sinAcceso);
    await t.pumpAndSettle();

    expect(consultasEta, 2);
    expect(find.text('ETA a tu parada: 4 min'), findsOneWidget);
    expect(find.textContaining('Última posición:'), findsOneWidget);

    await t.pump(const Duration(seconds: 10));
    await t.pump();
    expect(consultasEta, 3);
    expect(find.textContaining('Última posición:'), findsNothing);
    expect(
      find.text('Ubicación no disponible para esta sesión o viaje.'),
      findsOneWidget,
    );
  });

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
