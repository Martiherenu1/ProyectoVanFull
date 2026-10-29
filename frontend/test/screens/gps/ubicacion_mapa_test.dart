import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/core/maps/configuracion_mapa.dart';
import 'package:frontend/models/gps/ubicacion_viaje.dart';
import 'package:frontend/screens/gps/ubicacion_screen.dart';

import '../../widgets/gps/mapa_ultima_posicion_test.dart' as f;

class InvalidacionesFalsas extends ValueNotifier<bool> {
  InvalidacionesFalsas() : super(true);
  bool get tieneOyentes => hasListeners;
}

Future<void> avanzar(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump();
  }
}

Future<void> actualizar(WidgetTester t) async {
  final boton = find.text('Actualizar ubicación');
  await t.ensureVisible(boton);
  await t.tap(boton);
  await avanzar(t);
}

const cierre = ApiException(
  statusCode: 404,
  codigo: 'VIAJE_NO_DISPONIBLE',
  mensaje: '',
);
void main() {
  testWidgets(
    'polling/actualizar conserva mapa y advertencias; cierre retira todo',
    (t) async {
      final motor = f.MotorFalso();
      var lecturas = 0;
      Future<UbicacionViaje> leer(int id) async {
        lecturas++;
        if (lecturas == 3) {
          throw const ApiException(
            statusCode: 500,
            codigo: 'ERROR',
            mensaje: '',
          );
        }
        if (lecturas == 4) throw cierre;
        return f.punto(id: id, lat: lecturas.toDouble(), segundo: lecturas);
      }

      await t.pumpWidget(
        MaterialApp(
          home: UbicacionScreen(
            idViaje: 1,
            consultar: leer,
            configuracionMapa: f.android,
            prepararMapa: f.disponible,
            crearVisorMapa: motor.crear,
          ),
        ),
      );
      await avanzar(t);
      expect(motor.creados, 1);
      expect(find.textContaining('Información desactualizada'), findsOneWidget);
      expect(find.textContaining('Fecha informada'), findsOneWidget);
      await actualizar(t);
      expect(motor.creados, 1);
      expect(
        t.widget<f.VisorFalso>(find.byType(f.VisorFalso)).posicion.latitud,
        2,
      );
      expect(motor.controles.single.movimientos, 0);
      await actualizar(t);
      expect(motor.creados, 1);
      expect(find.textContaining('Consulta interrumpida'), findsOneWidget);
      expect(find.byType(f.VisorFalso), findsOneWidget);
      await actualizar(t);
      expect(find.textContaining('Última posición:'), findsNothing);
      expect(find.byType(f.VisorFalso), findsNothing);
      expect(motor.controles.single.disposiciones, 1);
      await t.pump(const Duration(seconds: 20));
      expect(lecturas, 4);
      await t.pumpWidget(const SizedBox());
    },
  );

  for (final cambio in ['viaje', 'fuente', 'contexto']) {
    for (final error in [false, true]) {
      testWidgets(
        '$cambio invalida GET/errores anteriores y espera sin solaparlos ($error)',
        (t) async {
          final pendiente = Completer<UbicacionViaje>();
          final motor = f.MotorFalso();
          var llamadas = 0;
          Future<UbicacionViaje> primera(int id) {
            llamadas++;
            return llamadas == 1
                ? pendiente.future
                : Future.value(f.punto(id: id, lat: 5));
          }

          Future<UbicacionViaje> siguiente(int id) async {
            llamadas++;
            return f.punto(id: id, lat: 5);
          }

          final id = cambio == 'viaje' ? 2 : 1;
          final fuenteNueva = cambio == 'contexto' ? primera : siguiente;
          await t.pumpWidget(
            MaterialApp(
              home: UbicacionScreen(
                idViaje: 1,
                consultar: primera,
                alcance: 1,
                configuracionMapa: f.android,
                prepararMapa: f.disponible,
                crearVisorMapa: motor.crear,
              ),
            ),
          );
          await avanzar(t);
          await t.pumpWidget(
            MaterialApp(
              home: UbicacionScreen(
                idViaje: id,
                consultar: fuenteNueva,
                alcance: cambio == 'contexto' ? 2 : 1,
                configuracionMapa: f.android,
                prepararMapa: f.disponible,
                crearVisorMapa: motor.crear,
              ),
            ),
          );
          expect(
            llamadas,
            1,
          ); // No existe un segundo GET mientras el primero sigue en vuelo.
          if (error) {
            pendiente.completeError(
              const ApiException(
                statusCode: 403,
                codigo: 'SIN_PERMISO',
                mensaje: '',
              ),
            );
          } else {
            pendiente.complete(f.punto(id: 1));
          }
          await avanzar(t);
          expect(llamadas, 2);
          expect(find.textContaining('5.0, 2.0'), findsOneWidget);
          expect(
            t.widget<f.VisorFalso>(find.byType(f.VisorFalso)).posicion.idViaje,
            id,
          );
          expect(motor.creados, 1);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'interfaz opcional de sesión retira datos y descarta loader pendiente',
    (t) async {
      final invalidaciones = InvalidacionesFalsas();
      final listo = Completer<bool>();
      final motor = f.MotorFalso();
      var vigente = true, lecturas = 0;
      Future<UbicacionViaje> leer(int id) async {
        lecturas++;
        return f.punto(id: id);
      }

      await t.pumpWidget(
        MaterialApp(
          home: UbicacionScreen(
            idViaje: 1,
            consultar: leer,
            invalidaciones: invalidaciones,
            contextoVigente: () => vigente,
            configuracionMapa: f.android,
            prepararMapa: (_) => listo.future,
            crearVisorMapa: motor.crear,
          ),
        ),
      );
      await avanzar(t);
      expect(find.textContaining('Última posición:'), findsOneWidget);
      vigente = false;
      invalidaciones.value = false;
      await avanzar(t);
      expect(find.textContaining('Última posición:'), findsNothing);
      listo.complete(true);
      await avanzar(t);
      expect(motor.creados, 0);
      await t.pump(const Duration(seconds: 20));
      expect(lecturas, 1);
      await t.pumpWidget(const SizedBox());
      expect(invalidaciones.tieneOyentes, false);
      invalidaciones.dispose();
    },
  );

  testWidgets(
    'sin configuración conserva información textual y no llama al loader',
    (t) async {
      var preparaciones = 0;
      final motor = f.MotorFalso();
      await t.pumpWidget(
        MaterialApp(
          home: UbicacionScreen(
            idViaje: 1,
            consultar: (id) async => f.punto(id: id),
            configuracionMapa: const ConfiguracionMapa(),
            prepararMapa: (_) async {
              preparaciones++;
              return true;
            },
            crearVisorMapa: motor.crear,
          ),
        ),
      );
      await avanzar(t);
      expect(find.textContaining('Última posición:'), findsOneWidget);
      expect(find.text('Mapa no disponible.'), findsOneWidget);
      expect(find.text('Avisos y licencias'), findsOneWidget);
      expect(preparaciones, 0);
      expect(motor.creados, 0);
      await t.pumpWidget(const SizedBox());
    },
  );

  for (final invalida in [
    f.punto(id: 2),
    f.punto(lat: double.nan),
    f.punto(segundo: 0),
  ]) {
    testWidgets(
      'posición inválida/anterior no mueve marcador ni borra última válida ${invalida.idViaje}/${invalida.fecha.second}',
      (t) async {
        var lecturas = 0;
        final motor = f.MotorFalso();
        Future<UbicacionViaje> leer(int _) async =>
            ++lecturas == 1 ? f.punto() : invalida;
        await t.pumpWidget(
          MaterialApp(
            home: UbicacionScreen(
              idViaje: 1,
              consultar: leer,
              configuracionMapa: f.android,
              prepararMapa: f.disponible,
              crearVisorMapa: motor.crear,
            ),
          ),
        );
        await avanzar(t);
        await actualizar(t);
        expect(
          t.widget<f.VisorFalso>(find.byType(f.VisorFalso)).posicion.latitud,
          1,
        );
        expect(find.textContaining('Sin actualización'), findsOneWidget);
        expect(motor.creados, 1);
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('guarda inicial fallida no consulta ni muestra coordenadas', (
    t,
  ) async {
    var lecturas = 0;
    await t.pumpWidget(
      MaterialApp(
        home: UbicacionScreen(
          idViaje: 1,
          consultar: (id) async {
            lecturas++;
            return f.punto(id: id);
          },
          contextoVigente: () => throw StateError('fallo local'),
        ),
      ),
    );
    await avanzar(t);
    expect(lecturas, 0);
    expect(find.textContaining('Última posición:'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
}
