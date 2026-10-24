import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/controllers/chofer/ejecucion_viaje_controller.dart';
import 'package:frontend/models/chofer/operacion_asignada.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';

import '../../fixtures/chofer/operacion_asignada_fixture.dart';

const habilitada = CondicionesUbicacionInicio(
  servicioActivado: true,
  permisoConcedido: true,
);
Future<CondicionesUbicacionInicio> comprobarHabilitada() async => habilitada;
Future<void> flush() => Future<void>.delayed(Duration.zero);

OperacionAsignada detalle(String estado, {int id = 41}) {
  final json = detalleJson(id: id);
  (json['viaje'] as Map)['estado'] = estado;
  return OperacionAsignada.fromJson(json);
}

class Escenario {
  String estado = 'programado';
  int inicios = 0;
  int finales = 0;
  int lecturas = 0;
  Object? falloInicio;
  Object? falloFin;
  bool fallaLectura = false;
  Future<OperacionAsignada?> cargar(int id) async {
    lecturas++;
    if (fallaLectura) throw StateError('fallo lectura');
    return detalle(estado, id: id);
  }

  late final acciones = AccionesEjecucionViaje(
    iniciar: (id) async {
      inicios++;
      if (falloInicio != null) throw falloInicio!;
      estado = 'en_curso';
      return detalle(estado, id: id).viaje;
    },
    finalizar: (id) async {
      finales++;
      if (falloFin != null) throw falloFin!;
      estado = 'finalizado';
      return detalle(estado, id: id).viaje;
    },
  );

  EjecucionViajeController crear({
    ComprobarUbicacionInicio? comprobar = comprobarHabilitada,
  }) => EjecucionViajeController(
    idViaje: 41,
    cargarDetalle: cargar,
    acciones: acciones,
    comprobarUbicacionInicio: comprobar,
  );
}

void main() {
  test('habilitada sin posicion ni precision permite un inicio', () async {
    final e = Escenario();
    var consultas = 0;
    final c = e.crear(
      comprobar: () async {
        consultas++;
        // Este resultado tambien representa permiso aproximado: no hay campo de precision.
        return habilitada;
      },
    );
    addTearDown(c.dispose);
    await c.consultar();
    await c.iniciar();
    expect(consultas, 1);
    expect(e.inicios, 1);
    expect(c.detalle!.viaje.estado, EstadoViaje.enCurso);
    expect(c.mensajeUbicacion, isNull);
  });

  final bloqueos = <String, (ComprobarUbicacionInicio?, String)>{
    'servicio apagado': (
      () async => const CondicionesUbicacionInicio(
        servicioActivado: false,
        permisoConcedido: true,
      ),
      'Activá la ubicación del teléfono para iniciar el viaje.',
    ),
    'permiso denegado': (
      () async => const CondicionesUbicacionInicio(
        servicioActivado: true,
        permisoConcedido: false,
      ),
      'Permití que VanFull acceda a tu ubicación para iniciar el viaje.',
    ),
    'fallo de consulta': (
      () async => throw StateError('consulta fallida'),
      'No pudimos comprobar la ubicación. Volvé a intentarlo.',
    ),
    'sin comprobador': (null, 'No se pudo comprobar la ubicación'),
  };
  for (final entrada in bloqueos.entries) {
    test(
      '${entrada.key}: bloqueo local sin POST ni incertidumbre nueva',
      () async {
        final e = Escenario();
        final c = e.crear(comprobar: entrada.value.$1);
        addTearDown(c.dispose);
        await c.consultar();
        final previo = c.detalle;
        await c.iniciar();
        expect(e.inicios, 0);
        expect(c.detalle, same(previo));
        expect(c.fase, FaseDetalleViaje.listo);
        expect(c.operacionPendiente, isNull);
        expect(c.rechazo, isNull);
        expect(c.mensajeUbicacion, entrada.value.$2);
        // Cambiar callbacks no debe convertir la consulta local en un envio pendiente.
        c.actualizarContexto(
          idViaje: 41,
          cargarDetalle: e.cargar,
          acciones: e.acciones,
          comprobarUbicacionInicio: comprobarHabilitada,
        );
        await flush();
        expect(c.operacionPendiente, isNull);
        expect(e.inicios, 0);
      },
    );

    test('${entrada.key}: no resuelve un inicio anterior incierto', () async {
      final e = Escenario()..falloInicio = const ResultadoViajeIncierto();
      final c = e.crear();
      addTearDown(c.dispose);
      await c.consultar();
      await c.iniciar();
      c.actualizarContexto(
        idViaje: 41,
        cargarDetalle: e.cargar,
        acciones: e.acciones,
        comprobarUbicacionInicio: entrada.value.$1,
      );
      await flush();
      expect(c.puedeRepetir, isTrue);
      await c.repetir();
      expect(e.inicios, 1);
      expect(c.operacionPendiente, OperacionViaje.inicio);
      expect(c.fase, FaseDetalleViaje.incierto);
      expect(c.mensajeUbicacion, entrada.value.$2);
      await c.consultar(); // programado no resuelve la solicitud previa.
      expect(c.operacionPendiente, OperacionViaje.inicio);
      expect(e.inicios, 1);
    });
  }

  test(
    'bloquea doble pulsacion, lectura y repeticion antes del primer await',
    () async {
      final e = Escenario();
      final gate = Completer<CondicionesUbicacionInicio>();
      var consultas = 0;
      final c = e.crear(
        comprobar: () {
          consultas++;
          return gate.future;
        },
      );
      addTearDown(c.dispose);
      await c.consultar();
      final inicio = c.iniciar();
      expect(c.comprobandoUbicacion, isTrue);
      expect(c.ocupado, isTrue);
      expect(c.puedeIniciar, isFalse);
      expect(c.operacionPendiente, isNull);
      await c.iniciar();
      await c.repetir();
      await c.finalizar();
      await c.consultar();
      expect(consultas, 1);
      expect(e.inicios, 0);
      expect(e.lecturas, 1);
      gate.complete(habilitada);
      await inicio;
      expect(e.inicios, 1);
    },
  );

  for (final cambio in [
    'viaje',
    'comprobador',
    'fuente',
    'acciones',
    'retirar comprobador',
  ]) {
    for (final fallar in [false, true]) {
      test(
        '$cambio descarta consulta tardia (${fallar ? "error" : "exito"})',
        () async {
          final e = Escenario();
          final gate = Completer<CondicionesUbicacionInicio>();
          Future<CondicionesUbicacionInicio> original() => gate.future;
          final c = e.crear(comprobar: original);
          addTearDown(c.dispose);
          await c.consultar();
          final inicio = c.iniciar();
          c.actualizarContexto(
            idViaje: cambio == 'viaje' ? 42 : 41,
            cargarDetalle: cambio == 'fuente' ? (id) => e.cargar(id) : e.cargar,
            acciones: cambio == 'acciones'
                ? AccionesEjecucionViaje(
                    iniciar: e.acciones.iniciar,
                    finalizar: e.acciones.finalizar,
                  )
                : e.acciones,
            comprobarUbicacionInicio: cambio == 'retirar comprobador'
                ? null
                : cambio == 'comprobador'
                ? comprobarHabilitada
                : original,
          );
          await flush();
          if (fallar) {
            gate.completeError(StateError('tardio'));
          } else {
            gate.complete(habilitada);
          }
          await inicio;
          expect(e.inicios, 0);
          expect(c.operacionPendiente, isNull);
          expect(c.comprobandoUbicacion, isFalse);
          expect(c.mensajeUbicacion, isNull);
          expect(c.detalle!.viaje.idViaje, cambio == 'viaje' ? 42 : 41);
        },
      );
    }
  }

  for (final fallar in [false, true]) {
    test(
      'desmontaje descarta consulta tardia ${fallar ? "fallida" : "habilitada"}',
      () async {
        final e = Escenario();
        final gate = Completer<CondicionesUbicacionInicio>();
        final c = e.crear(comprobar: () => gate.future);
        var notificaciones = 0;
        c.addListener(() => notificaciones++);
        await c.consultar();
        final inicio = c.iniciar();
        c.dispose();
        final antes = notificaciones;
        if (fallar) {
          gate.completeError(StateError('tardio'));
        } else {
          gate.complete(habilitada);
        }
        await inicio;
        expect(e.inicios, 0);
        expect(notificaciones, antes);
      },
    );
  }

  test(
    'respuesta vieja no libera el bloqueo de la comprobacion nueva',
    () async {
      final e = Escenario();
      final vieja = Completer<CondicionesUbicacionInicio>();
      final nueva = Completer<CondicionesUbicacionInicio>();
      final c = e.crear(comprobar: () => vieja.future);
      addTearDown(c.dispose);
      await c.consultar();
      final anterior = c.iniciar();
      c.actualizarContexto(
        idViaje: 41,
        cargarDetalle: e.cargar,
        acciones: e.acciones,
        comprobarUbicacionInicio: () => nueva.future,
      );
      await flush();
      final actual = c.iniciar();
      vieja.complete(habilitada);
      await anterior;
      expect(c.comprobandoUbicacion, isTrue);
      expect(e.inicios, 0);
      nueva.complete(habilitada);
      await actual;
      expect(e.inicios, 1);
    },
  );

  test('habilitar condiciones no inicia hasta una pulsacion nueva', () async {
    final e = Escenario();
    var permitido = false;
    final c = e.crear(
      comprobar: () async => CondicionesUbicacionInicio(
        servicioActivado: true,
        permisoConcedido: permitido,
      ),
    );
    addTearDown(c.dispose);
    await c.consultar();
    await c.iniciar();
    permitido = true;
    await c.consultar();
    expect(e.inicios, 0);
    await c.iniciar();
    expect(e.inicios, 1);
  });

  test(
    'reintento habilitado consulta de nuevo; rechazo no resuelve POST previo',
    () async {
      final e = Escenario()..falloInicio = const ResultadoViajeIncierto();
      var consultas = 0;
      final c = e.crear(
        comprobar: () async {
          consultas++;
          return habilitada;
        },
      );
      addTearDown(c.dispose);
      await c.consultar();
      await c.iniciar();
      await c.consultar();
      e.falloInicio = const RechazoOperacionViaje(MotivoRechazoViaje.conflicto);
      await c.repetir();
      expect(consultas, 2);
      expect(e.inicios, 2);
      expect(c.operacionPendiente, OperacionViaje.inicio);
      expect(c.fase, FaseDetalleViaje.incierto);
    },
  );

  for (final comprobar in <ComprobarUbicacionInicio?>[
    null,
    () async => throw StateError('GPS no debe consultarse'),
    () async => const CondicionesUbicacionInicio(
      servicioActivado: false,
      permisoConcedido: false,
    ),
  ]) {
    test('finalizar y repetir finalizacion no consultan GPS', () async {
      final e = Escenario()
        ..estado = 'en_curso'
        ..falloFin = const ResultadoViajeIncierto();
      final c = e.crear(comprobar: comprobar);
      addTearDown(c.dispose);
      await c.consultar();
      await c.finalizar();
      expect(e.finales, 1);
      expect(c.operacionPendiente, OperacionViaje.finalizacion);
      await c.consultar();
      e.falloFin = null;
      await c.repetir();
      expect(e.finales, 2);
      expect(c.detalle!.viaje.estado, EstadoViaje.finalizado);
      expect(c.mensajeUbicacion, isNull);
    });
  }

  test('cambiar comprobador conserva confirmacion del servidor ante recarga fallida', () async {
    final e = Escenario();
    final acciones = AccionesEjecucionViaje(
      iniciar: (id) async {
        e.inicios++;
        e.fallaLectura = true;
        return detalle('en_curso', id: id).viaje;
      },
      finalizar: e.acciones.finalizar,
    );
    final c = EjecucionViajeController(
      idViaje: 41,
      cargarDetalle: e.cargar,
      acciones: acciones,
      comprobarUbicacionInicio: comprobarHabilitada,
    );
    addTearDown(c.dispose);
    await c.consultar();
    await c.iniciar();
    final confirmado = c.viajeConfirmado;
    expect(confirmado!.estado, EstadoViaje.enCurso);
    c.actualizarContexto(
      idViaje: 41,
      cargarDetalle: e.cargar,
      acciones: acciones,
      comprobarUbicacionInicio: () async => throw StateError('no consultar'),
    );
    await flush();
    expect(c.viajeConfirmado, same(confirmado));
    expect(c.fase, FaseDetalleViaje.confirmadoSinDetalle);
    expect(e.inicios, 1);
  });
}
