import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/gps/ubicacion_viaje.dart';
import 'package:frontend/models/gps/vigencia_ubicacion.dart';
import 'package:frontend/screens/gps/ubicacion_screen.dart';

final t0 = DateTime.utc(2026, 11, 16);
UbicacionViaje punto({
  int id = 1,
  int segundo = 0,
  double lat = 0,
  int edad = 29,
  bool referencia = true,
  bool? marcada,
}) => UbicacionViaje(
  id,
  lat,
  0,
  t0.add(Duration(seconds: segundo)),
  marcada ?? edad > 30,
  null,
  fechaEvaluacion: referencia
      ? t0.add(Duration(seconds: segundo + edad))
      : null,
  sinCache: true,
);

void main() {
  testWidgets('GET 29→31 muestra incertidumbre y envejece sin otro GET', (
    t,
  ) async {
    var ahora = Duration.zero;
    final respuesta = Completer<UbicacionViaje>();
    await t.pumpWidget(
      MaterialApp(
        home: UbicacionScreen(
          idViaje: 1,
          relojMonotono: () => ahora,
          consultar: (_) => respuesta.future,
        ),
      ),
    );
    ahora = const Duration(seconds: 2);
    respuesta.complete(punto());
    await t.pump();
    expect(find.text(VigenciaUbicacion.incierta), findsOneWidget);
    expect(find.text(VigenciaUbicacion.desactualizada), findsNothing);
    ahora = const Duration(seconds: 4);
    await t.pump(const Duration(seconds: 2));
    expect(find.text(VigenciaUbicacion.desactualizada), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('GET pendiente no congela el cruce >30 s ni oculta posición', (
    t,
  ) async {
    var ahora = Duration.zero;
    var llamadas = 0;
    final pendiente = Completer<UbicacionViaje>();
    await t.pumpWidget(
      MaterialApp(
        home: UbicacionScreen(
          idViaje: 1,
          relojMonotono: () => ahora,
          consultar: (_) {
            llamadas++;
            return llamadas == 1 ? Future.value(punto()) : pendiente.future;
          },
        ),
      ),
    );
    await t.pump();
    expect(find.text(VigenciaUbicacion.sinMarca), findsOneWidget);
    await t.tap(find.text('Actualizar ubicación'));
    await t.pump();
    ahora = const Duration(seconds: 1);
    await t.pump(const Duration(seconds: 1));
    expect(find.text(VigenciaUbicacion.sinMarca), findsOneWidget);
    ahora = const Duration(seconds: 2);
    await t.pump(const Duration(seconds: 1));
    expect(find.text(VigenciaUbicacion.desactualizada), findsOneWidget);
    expect(find.textContaining('Última posición:'), findsOneWidget);
    expect(find.text('Actualizando ubicación…'), findsOneWidget);
    expect(llamadas, 2);
    pendiente.complete(punto(referencia: false));
    await t.pump();
    expect(find.text(VigenciaUbicacion.desactualizada), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  for (final codigo in [401, 403, 404]) {
    testWidgets('$codigo retira referencia, coordenadas y advertencia', (
      t,
    ) async {
      var llamadas = 0;
      await t.pumpWidget(
        MaterialApp(
          home: UbicacionScreen(
            idViaje: 1,
            consultar: (_) async {
              if (++llamadas == 1) return punto(edad: 31);
              throw ApiException(
                statusCode: codigo,
                codigo: 'SIN_PERMISO',
                mensaje: '',
              );
            },
          ),
        ),
      );
      await t.pump();
      await t.tap(find.text('Actualizar ubicación'));
      await t.pump();
      expect(find.textContaining('Última posición:'), findsNothing);
      expect(find.text(VigenciaUbicacion.desactualizada), findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets('mismo T y otras coordenadas no reemplazan P ni marca', (
    t,
  ) async {
    var llamadas = 0;
    await t.pumpWidget(
      MaterialApp(
        home: UbicacionScreen(
          idViaje: 1,
          consultar: (_) async =>
              ++llamadas == 1 ? punto(edad: 31) : punto(lat: 2),
        ),
      ),
    );
    await t.pump();
    await t.tap(find.text('Actualizar ubicación'));
    await t.pump();
    expect(find.textContaining('Última posición: 0.0, 0.0'), findsOneWidget);
    expect(find.text(VigenciaUbicacion.desactualizada), findsOneWidget);
    expect(find.textContaining('No se pudo actualizar'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('cambio de viaje limpia marca y descarta respuesta tardía', (
    t,
  ) async {
    var llamadas = 0;
    final pendiente = Completer<UbicacionViaje>();
    Future<UbicacionViaje> leer(int id) {
      if (++llamadas == 1) return Future.value(punto(edad: 31));
      return id == 1 ? pendiente.future : Future.value(punto(id: id));
    }

    await t.pumpWidget(
      MaterialApp(home: UbicacionScreen(idViaje: 1, consultar: leer)),
    );
    await t.pump();
    await t.tap(find.text('Actualizar ubicación'));
    await t.pump();
    await t.pumpWidget(
      MaterialApp(home: UbicacionScreen(idViaje: 2, consultar: leer)),
    );
    pendiente.complete(punto(edad: 31));
    await t.pump();
    await t.pump();
    expect(find.text(VigenciaUbicacion.desactualizada), findsNothing);
    expect(find.textContaining('Última posición:'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('ciclo de vida invalida ancla y espera referencia nueva', (
    t,
  ) async {
    var ahora = Duration.zero;
    var llamadas = 0;
    final pendiente = Completer<UbicacionViaje>();
    await t.pumpWidget(
      MaterialApp(
        home: UbicacionScreen(
          idViaje: 1,
          relojMonotono: () => ahora,
          consultar: (_) =>
              ++llamadas == 1 ? Future.value(punto()) : pendiente.future,
        ),
      ),
    );
    await t.pump();
    expect(find.text(VigenciaUbicacion.sinMarca), findsOneWidget);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    ahora = const Duration(minutes: 5);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(find.text(VigenciaUbicacion.noVerificable), findsOneWidget);
    pendiente.complete(punto(edad: 0, segundo: 300));
    await t.pump();
    expect(find.text(VigenciaUbicacion.sinMarca), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
