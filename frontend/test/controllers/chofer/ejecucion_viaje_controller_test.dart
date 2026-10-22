import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/controllers/chofer/ejecucion_viaje_controller.dart';
import 'package:frontend/models/chofer/operacion_asignada.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';

import '../../fixtures/chofer/operacion_asignada_fixture.dart';

OperacionAsignada snapshot(String estado, {int id = 41}) {
  final json = detalleJson(id: id);
  (json['viaje'] as Map)['estado'] = estado;
  return OperacionAsignada.fromJson(json);
}

AccionesEjecucionViaje fuentes({
  CambiarEstadoViajeChofer? inicio,
  CambiarEstadoViajeChofer? fin,
  void Function(RechazoOperacionViaje)? rechazo,
}) => AccionesEjecucionViaje(
  iniciar: inicio ?? (_) async => snapshot('en_curso').viaje,
  finalizar: fin ?? (_) async => snapshot('finalizado').viaje,
  onRechazo: rechazo,
);

void main() {
  for (final estado in ['programado', 'en_curso', 'finalizado', 'cancelado']) {
    test('habilita únicamente la acción de $estado', () async {
      final c = EjecucionViajeController(
        idViaje: 41,
        cargarDetalle: (_) async => snapshot(estado),
        acciones: fuentes(),
      );
      addTearDown(c.dispose);
      await c.consultar();
      expect(c.puedeIniciar, estado == 'programado');
      expect(c.puedeFinalizar, estado == 'en_curso');
      expect(c.puedeRepetir, isFalse);
    });
  }

  test(
    'no duplica operación ni habilita otra mientras opera y recarga',
    () async {
      final post = Completer<ViajeResumen>();
      final recarga = Completer<OperacionAsignada?>();
      var lecturas = 0;
      var inicios = 0;
      var fines = 0;
      final c = EjecucionViajeController(
        idViaje: 41,
        cargarDetalle: (_) => ++lecturas == 1
            ? Future.value(snapshot('programado'))
            : recarga.future,
        acciones: fuentes(
          inicio: (id) {
            expect(id, 41);
            inicios++;
            return post.future;
          },
          fin: (_) async {
            fines++;
            return snapshot('finalizado').viaje;
          },
        ),
      );
      addTearDown(c.dispose);
      await c.consultar();
      final operacion = c.iniciar();
      await c.iniciar();
      await c.finalizar();
      await c.consultar();
      expect(inicios, 1);
      expect(fines, 0);
      expect(c.detalle, isNull);
      post.complete(snapshot('en_curso').viaje);
      await Future<void>.delayed(Duration.zero);
      expect(c.fase, FaseDetalleViaje.recargando);
      expect(c.viajeConfirmado!.estado, EstadoViaje.enCurso);
      expect(c.detalle, isNull);
      await c.finalizar();
      expect(fines, 0);
      recarga.complete(snapshot('en_curso'));
      await operacion;
      expect(c.puedeFinalizar, isTrue);
      expect(lecturas, 2);
    },
  );

  test(
    'inicio 200 finalizado es autoritativo aunque falle la recarga',
    () async {
      var lecturas = 0;
      final c = EjecucionViajeController(
        idViaje: 41,
        cargarDetalle: (_) async {
          if (++lecturas > 1) throw StateError('lectura fallida');
          return snapshot('programado');
        },
        acciones: fuentes(inicio: (_) async => snapshot('finalizado').viaje),
      );
      addTearDown(c.dispose);
      await c.consultar();
      await c.iniciar();
      expect(c.fase, FaseDetalleViaje.confirmadoSinDetalle);
      expect(c.viajeConfirmado!.estado, EstadoViaje.finalizado);
      expect(c.detalle, isNull);
      expect(c.puedeIniciar || c.puedeFinalizar, isFalse);
    },
  );

  test(
    'no agrega condiciones locales de horario, asignación o fecha',
    () async {
      final json = detalleJson();
      final viaje = json['viaje'] as Map;
      viaje['estado'] = 'programado';
      viaje['fecha'] = '2020-01-01';
      viaje.remove('horario');
      viaje.remove('id_vehiculo');
      var llamados = 0;
      final c = EjecucionViajeController(
        idViaje: 41,
        cargarDetalle: (_) async => OperacionAsignada.fromJson(json),
        acciones: fuentes(
          inicio: (_) async {
            llamados++;
            throw const RechazoOperacionViaje(
              MotivoRechazoViaje.conflicto,
              codigo: 'VEHICULO_NO_ASIGNADO',
            );
          },
        ),
      );
      addTearDown(c.dispose);
      await c.consultar();
      await c.iniciar();
      expect(llamados, 1);
      expect(c.rechazo!.codigo, 'VEHICULO_NO_ASIGNADO');
    },
  );

  for (final motivo in MotivoRechazoViaje.values) {
    test(
      'rechazo conocido $motivo se informa al contenedor sin reenvío',
      () async {
        final avisos = <RechazoOperacionViaje>[];
        var lecturas = 0;
        final c = EjecucionViajeController(
          idViaje: 41,
          cargarDetalle: (_) async {
            lecturas++;
            return snapshot('programado');
          },
          acciones: fuentes(
            inicio: (_) async => throw RechazoOperacionViaje(motivo),
            rechazo: avisos.add,
          ),
        );
        addTearDown(c.dispose);
        await c.consultar();
        await c.iniciar();
        expect(c.fase, FaseDetalleViaje.error);
        expect(c.rechazo!.motivo, motivo);
        expect(avisos.single.motivo, motivo);
        expect(c.detalle, isNull);
        expect(lecturas, 1);
        expect(c.puedeIniciar || c.puedeFinalizar || c.puedeRepetir, isFalse);
      },
    );
  }

  for (final operacion in OperacionViaje.values) {
    test(
      'incertidumbre de $operacion exige consulta y repite solo esa operación',
      () async {
        final previo = operacion == OperacionViaje.inicio
            ? 'programado'
            : 'en_curso';
        final posterior = operacion == OperacionViaje.inicio
            ? 'en_curso'
            : 'finalizado';
        var inicios = 0;
        var fines = 0;
        var consultas = 0;
        var estado = previo;
        Future<ViajeResumen> ejecutar(OperacionViaje accion) async {
          final n = accion == OperacionViaje.inicio ? ++inicios : ++fines;
          if (n == 1) throw const ResultadoViajeIncierto();
          estado = posterior;
          return snapshot(posterior).viaje;
        }

        final c = EjecucionViajeController(
          idViaje: 41,
          cargarDetalle: (_) async {
            consultas++;
            return snapshot(estado);
          },
          acciones: fuentes(
            inicio: (_) => ejecutar(OperacionViaje.inicio),
            fin: (_) => ejecutar(OperacionViaje.finalizacion),
          ),
        );
        addTearDown(c.dispose);
        await c.consultar();
        if (operacion == OperacionViaje.inicio) {
          await c.iniciar();
        } else {
          await c.finalizar();
        }
        expect(c.fase, FaseDetalleViaje.incierto);
        expect(c.puedeRepetir, isFalse);
        expect(consultas, 1);
        await c.repetir();
        await c.iniciar();
        await c.finalizar();
        expect(inicios + fines, 1);
        await c.consultar();
        expect(c.fase, FaseDetalleViaje.incierto);
        expect(c.puedeRepetir, isTrue);
        expect(c.puedeIniciar || c.puedeFinalizar, isFalse);
        await c.repetir();
        expect(inicios + fines, 2);
        expect(c.fase, FaseDetalleViaje.listo);
        expect(c.detalle!.viaje.estado.valorApi, posterior);
      },
    );
  }

  test(
    'consulta fallida y rechazo posterior no resuelven el inicio incierto',
    () async {
      var n = 0;
      var fallarConsulta = false;
      final c = EjecucionViajeController(
        idViaje: 41,
        cargarDetalle: (_) async {
          if (fallarConsulta) throw StateError('red');
          return snapshot('programado');
        },
        acciones: fuentes(
          inicio: (_) async {
            if (++n == 1) throw StateError('sin respuesta concluyente');
            throw const RechazoOperacionViaje(MotivoRechazoViaje.conflicto);
          },
        ),
      );
      addTearDown(c.dispose);
      await c.consultar();
      await c.iniciar();
      fallarConsulta = true;
      await c.consultar();
      expect(c.fase, FaseDetalleViaje.incierto);
      expect(c.puedeRepetir, isFalse);
      fallarConsulta = false;
      await c.consultar();
      await c.repetir();
      expect(c.fase, FaseDetalleViaje.incierto);
      expect(c.operacionPendiente, OperacionViaje.inicio);
      expect(c.rechazo!.motivo, MotivoRechazoViaje.conflicto);
      expect(c.puedeRepetir, isFalse);
      expect(c.puedeIniciar || c.puedeFinalizar, isFalse);
    },
  );

  for (final estado in ['en_curso', 'finalizado', 'cancelado']) {
    test(
      'consulta $estado resuelve inicio incierto sin reenviar POST',
      () async {
        var actual = 'programado';
        var posts = 0;
        final c = EjecucionViajeController(
          idViaje: 41,
          cargarDetalle: (_) async => snapshot(actual),
          acciones: fuentes(
            inicio: (_) async {
              posts++;
              throw const ResultadoViajeIncierto();
            },
          ),
        );
        addTearDown(c.dispose);
        await c.consultar();
        await c.iniciar();
        actual = estado;
        await c.consultar();
        expect(c.fase, FaseDetalleViaje.listo);
        expect(c.operacionPendiente, isNull);
        expect(posts, 1);
      },
    );
  }

  test(
    'programado inesperado no habilita inicio tras finalización incierta',
    () async {
      var actual = 'en_curso';
      final c = EjecucionViajeController(
        idViaje: 41,
        cargarDetalle: (_) async => snapshot(actual),
        acciones: fuentes(
          fin: (_) async => throw const ResultadoViajeIncierto(),
        ),
      );
      addTearDown(c.dispose);
      await c.consultar();
      await c.finalizar();
      actual = 'programado';
      await c.consultar();
      expect(c.fase, FaseDetalleViaje.incierto);
      expect(c.puedeIniciar || c.puedeRepetir, isFalse);
    },
  );

  for (final fallo in ['null', 'id', 'red']) {
    test(
      'recarga $fallo conserva estado 200 y permite actualizar sin otro POST',
      () async {
        var consultas = 0;
        var posts = 0;
        final c = EjecucionViajeController(
          idViaje: 41,
          cargarDetalle: (_) async {
            consultas++;
            if (consultas == 1) return snapshot('en_curso');
            if (consultas == 2) {
              if (fallo == 'null') return null;
              if (fallo == 'id') return snapshot('finalizado', id: 99);
              throw StateError('red');
            }
            return snapshot('finalizado');
          },
          acciones: fuentes(
            fin: (_) async {
              posts++;
              return snapshot('finalizado').viaje;
            },
          ),
        );
        addTearDown(c.dispose);
        await c.consultar();
        await c.finalizar();
        expect(c.fase, FaseDetalleViaje.confirmadoSinDetalle);
        expect(c.viajeConfirmado!.estado, EstadoViaje.finalizado);
        expect(c.detalle, isNull);
        await c.consultar();
        expect(c.detalle!.viaje.estado, EstadoViaje.finalizado);
        expect(posts, 1);
      },
    );
  }

  test(
    'ID incorrecto en POST se considera incierto y no expone otro viaje',
    () async {
      final c = EjecucionViajeController(
        idViaje: 41,
        cargarDetalle: (_) async => snapshot('programado'),
        acciones: fuentes(
          inicio: (_) async => snapshot('en_curso', id: 99).viaje,
        ),
      );
      addTearDown(c.dispose);
      await c.consultar();
      await c.iniciar();
      expect(c.fase, FaseDetalleViaje.incierto);
      expect(c.viajeConfirmado, isNull);
      expect(c.detalle, isNull);
    },
  );

  for (final resultado in ['exito', 'rechazo', 'incierto']) {
    for (final mismoId in [true, false]) {
      test(
        'cambio de contexto mismoId=$mismoId descarta POST $resultado',
        () async {
          final post = Completer<ViajeResumen>();
          final c = EjecucionViajeController(
            idViaje: 41,
            cargarDetalle: (_) async => snapshot('programado'),
            acciones: fuentes(inicio: (_) => post.future),
          );
          addTearDown(c.dispose);
          await c.consultar();
          final operacion = c.iniciar();
          final id = mismoId ? 41 : 42;
          c.actualizarContexto(
            idViaje: id,
            cargarDetalle: (_) async => snapshot('programado', id: id),
            acciones: fuentes(),
          );
          await Future<void>.delayed(Duration.zero);
          if (resultado == 'exito') {
            post.complete(snapshot('finalizado').viaje);
          } else {
            post.completeError(
              resultado == 'rechazo'
                  ? const RechazoOperacionViaje(MotivoRechazoViaje.sinPermiso)
                  : const ResultadoViajeIncierto(),
            );
          }
          await operacion;
          if (mismoId) {
            expect(c.fase, FaseDetalleViaje.incierto);
            expect(c.operacionPendiente, OperacionViaje.inicio);
            expect(c.puedeRepetir, isTrue);
            expect(c.rechazo, isNull);
          } else {
            expect(c.detalle!.viaje.idViaje, 42);
            expect(c.puedeIniciar, isTrue);
          }
        },
      );
    }
  }

  for (final resultado in ['exito', 'error']) {
    test('dispose ignora POST $resultado sin notificar ni recargar', () async {
      final post = Completer<ViajeResumen>();
      var lecturas = 0;
      var notificaciones = 0;
      final c = EjecucionViajeController(
        idViaje: 41,
        cargarDetalle: (_) async {
          lecturas++;
          return snapshot('programado');
        },
        acciones: fuentes(inicio: (_) => post.future),
      )..addListener(() => notificaciones++);
      await c.consultar();
      final operacion = c.iniciar();
      c.dispose();
      final anteriores = notificaciones;
      if (resultado == 'exito') {
        post.complete(snapshot('en_curso').viaje);
      } else {
        post.completeError(StateError('red'));
      }
      await operacion;
      expect(notificaciones, anteriores);
      expect(lecturas, 1);
    });
  }

  test('lectura anterior no sobrescribe el viaje cambiado', () async {
    final anterior = Completer<OperacionAsignada?>();
    final c = EjecucionViajeController(
      idViaje: 41,
      cargarDetalle: (_) => anterior.future,
    );
    addTearDown(c.dispose);
    final lectura = c.consultar();
    c.actualizarContexto(
      idViaje: 42,
      cargarDetalle: (_) async => snapshot('finalizado', id: 42),
      acciones: fuentes(),
    );
    await Future<void>.delayed(Duration.zero);
    anterior.complete(snapshot('programado'));
    await lectura;
    expect(c.detalle!.viaje.idViaje, 42);
    expect(c.detalle!.viaje.estado, EstadoViaje.finalizado);
  });

  test('un coordinador desmontado no vuelve a enviar ni consultar', () async {
    var posts = 0;
    var lecturas = 0;
    final c = EjecucionViajeController(
      idViaje: 41,
      cargarDetalle: (_) async {
        lecturas++;
        return snapshot('programado');
      },
      acciones: fuentes(
        inicio: (_) async {
          posts++;
          return snapshot('en_curso').viaje;
        },
      ),
    );
    await c.consultar();
    c.dispose();
    await c.iniciar();
    await c.finalizar();
    await c.repetir();
    await c.consultar();
    c.actualizarContexto(
      idViaje: 42,
      cargarDetalle: (_) async {
        lecturas++;
        return snapshot('programado', id: 42);
      },
    );
    expect(posts, 0);
    expect(lecturas, 1);
  });

  for (final fallo in [false, true]) {
    test(
      'recarga anterior fallo=$fallo no sustituye el detalle nuevo',
      () async {
        final antigua = Completer<OperacionAsignada?>();
        var n = 0;
        final c = EjecucionViajeController(
          idViaje: 41,
          cargarDetalle: (_) =>
              ++n == 1 ? Future.value(snapshot('programado')) : antigua.future,
          acciones: fuentes(),
        );
        addTearDown(c.dispose);
        await c.consultar();
        final accion = c.iniciar();
        await Future<void>.delayed(Duration.zero);
        expect(c.fase, FaseDetalleViaje.recargando);
        c.actualizarContexto(
          idViaje: 41,
          cargarDetalle: (_) async => snapshot('finalizado'),
          acciones: fuentes(),
        );
        await Future<void>.delayed(Duration.zero);
        if (fallo) {
          antigua.completeError(StateError('lectura vieja'));
        } else {
          antigua.complete(snapshot('en_curso'));
        }
        await accion;
        expect(c.detalle!.viaje.estado, EstadoViaje.finalizado);
        expect(c.fase, FaseDetalleViaje.listo);
        expect(c.puedeFinalizar, isFalse);
      },
    );
  }

  for (final caso in [
    (
      operacion: OperacionViaje.inicio,
      previo: 'programado',
      confirmado: 'en_curso',
      consultado: 'programado',
    ),
    (
      operacion: OperacionViaje.finalizacion,
      previo: 'en_curso',
      confirmado: 'finalizado',
      consultado: 'en_curso',
    ),
    (
      operacion: OperacionViaje.finalizacion,
      previo: 'en_curso',
      confirmado: 'finalizado',
      consultado: 'programado',
    ),
    (
      operacion: OperacionViaje.inicio,
      previo: 'programado',
      confirmado: 'finalizado',
      consultado: 'en_curso',
    ),
  ]) {
    test(
      '${caso.operacion} confirma ${caso.confirmado}: rechaza detalle ${caso.consultado}',
      () async {
        var lecturas = 0;
        var posts = 0;
        final confirmado = snapshot(caso.confirmado).viaje;
        final contradictorio = snapshot(caso.consultado);
        final actualizado = snapshot(caso.confirmado);
        Future<ViajeResumen> ejecutar(int id) async {
          posts++;
          return confirmado;
        }

        final c = EjecucionViajeController(
          idViaje: 41,
          cargarDetalle: (_) async {
            lecturas++;
            if (lecturas == 1) return snapshot(caso.previo);
            return lecturas < 4 ? contradictorio : actualizado;
          },
          acciones: fuentes(inicio: ejecutar, fin: ejecutar),
        );
        addTearDown(c.dispose);
        await c.consultar();
        if (caso.operacion == OperacionViaje.inicio) {
          await c.iniciar();
        } else {
          await c.finalizar();
        }
        expect(c.fase, FaseDetalleViaje.confirmadoSinDetalle);
        expect(c.viajeConfirmado, same(confirmado));
        expect(c.detalle, isNull);
        expect(c.puedeIniciar || c.puedeFinalizar || c.puedeRepetir, isFalse);
        await c.iniciar();
        await c.finalizar();
        await c.repetir();
        expect(posts, 1);
        // Otra respuesta contradictoria tampoco borra la confirmación.
        await c.consultar();
        expect(c.fase, FaseDetalleViaje.confirmadoSinDetalle);
        expect(c.viajeConfirmado, same(confirmado));
        expect(c.detalle, isNull);
        await c.consultar();
        expect(c.fase, FaseDetalleViaje.listo);
        expect(c.detalle, same(actualizado));
        expect(c.viajeConfirmado, isNull);
        expect(posts, 1);
      },
    );
  }

  test('POST en_curso admite detalle que avanzó a finalizado', () async {
    var lecturas = 0;
    final actualizado = snapshot('finalizado');
    final c = EjecucionViajeController(
      idViaje: 41,
      cargarDetalle: (_) async =>
          ++lecturas == 1 ? snapshot('programado') : actualizado,
      acciones: fuentes(inicio: (_) async => snapshot('en_curso').viaje),
    );
    addTearDown(c.dispose);
    await c.consultar();
    await c.iniciar();
    expect(c.fase, FaseDetalleViaje.listo);
    expect(c.detalle, same(actualizado));
    expect(c.detalle!.viaje.estado, EstadoViaje.finalizado);
    expect(c.viajeConfirmado, isNull);
    expect(c.puedeIniciar || c.puedeFinalizar || c.puedeRepetir, isFalse);
  });
}
