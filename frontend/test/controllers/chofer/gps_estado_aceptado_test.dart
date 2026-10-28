import 'dart:async';

import 'package:frontend/models/chofer/operacion_asignada.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/controllers/chofer/ejecucion_viaje_controller.dart';

import 'control_ubicacion_inicio_test.dart' as f;

void main() {
  test('el consumidor no recibe lecturas de un contexto invalidado', () async {
    final vieja = Completer<OperacionAsignada?>();
    final aceptados = <int>[];
    final c = EjecucionViajeController(
      idViaje: 41,
      cargarDetalle: (_) => vieja.future,
      onViajeAceptado: (viaje, _) => aceptados.add(viaje.idViaje),
    );
    addTearDown(c.dispose);
    final lectura = c.consultar();
    c.actualizarContexto(
      idViaje: 42,
      cargarDetalle: (_) async => f.detalle('en_curso', id: 42),
    );
    await f.flush();
    vieja.complete(f.detalle('programado'));
    await lectura;
    expect(aceptados, [42]);
  });
  test(
    'una lectura programado no revierte en_curso ya confirmado y recargado',
    () async {
      final e = f.Escenario();
      final c = e.crear();
      addTearDown(c.dispose);
      await c.consultar();
      await c.iniciar(); // POST y recarga en_curso aceptados.
      e.estado = 'programado';
      await c.consultar();
      expect(c.fase, FaseDetalleViaje.confirmadoSinDetalle);
      expect(c.detalle, isNull);
      expect(c.viajeConfirmado?.estado.name, 'enCurso');
    },
  );
}
