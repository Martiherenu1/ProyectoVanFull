import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:frontend/controllers/chofer/seguimiento_gps_controller.dart';
import 'package:frontend/controllers/chofer/condiciones_ubicacion_inicio.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';

final punto = Position(
  longitude: 0,
  latitude: 0,
  timestamp: DateTime.utc(2026),
  accuracy: 1000,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);
ViajeResumen viaje(EstadoViaje estado, [int id = 1]) => ViajeResumen(
  idViaje: id,
  idServicio: 1,
  idRecorrido: 1,
  idVehiculo: 1,
  idChofer: 1,
  fecha: DateTime.utc(2026),
  sentido: SentidoViaje.ida,
  estado: estado,
);
Future<void> turno() => Future<void>.delayed(Duration.zero);
void main() {
  late StreamController<Position> fuente;
  late SeguimientoGpsController c;
  late int envios, capturas;
  late bool vigente;
  setUp(() {
    fuente = StreamController<Position>.broadcast();
    envios = 0;
    capturas = 0;
    vigente = true;
    c = SeguimientoGpsController(
      comprobar: () async => const CondicionesUbicacionInicio(
        servicioActivado: true,
        permisoConcedido: true,
      ),
      capturar: () {
        capturas++;
        return fuente.stream;
      },
      enviar: (_, _) async {
        envios++;
      },
      sesionVigente: () => vigente,
    );
  });
  tearDown(() async {
    c.dispose();
    await fuente.close();
  });
  test(
    'sin confirmación ni consulta en curso arranca automáticamente',
    () async {
      await c.reactivar();
      c.confirmar(viaje(EstadoViaje.programado), iniciar: true);
      c.confirmar(viaje(EstadoViaje.finalizado, 2), iniciar: true);
      c.confirmar(viaje(EstadoViaje.enCurso));
      await turno();
      expect(capturas, 0);
      await c.reactivar();
      fuente.add(punto);
      await turno();
      expect(envios, 1); // Aproximada/precisión baja no se rechazan.
    },
  );
  test(
    'una suscripción, sin esperar primera posición y cierre detiene',
    () async {
      c.confirmar(viaje(EstadoViaje.enCurso), iniciar: true);
      await c.reactivar();
      await turno();
      expect(capturas, 1);
      c.confirmar(viaje(EstadoViaje.finalizado));
      fuente.add(punto);
      await turno();
      expect(envios, 0);
      expect(c.activo, false);
    },
  );
  test(
    'sesión anterior nunca envía y resultados tardíos no actualizan estado',
    () async {
      c.confirmar(viaje(EstadoViaje.enCurso), iniciar: true);
      await turno();
      vigente = false;
      fuente.add(punto);
      await turno();
      expect(envios, 0);
    },
  );
  test('observar otro viaje conserva preparación de A', () async {
    final consulta = Completer<CondicionesUbicacionInicio>();
    c.dispose();
    c = SeguimientoGpsController(
      comprobar: () => consulta.future,
      capturar: () {
        capturas++;
        return fuente.stream;
      },
      enviar: (_, _) async {
        envios++;
      },
      sesionVigente: () => true,
    );
    c.confirmar(viaje(EstadoViaje.enCurso), iniciar: true);
    await turno();
    c.confirmar(viaje(EstadoViaje.enCurso, 2));
    consulta.complete(
      const CondicionesUbicacionInicio(
        servicioActivado: true,
        permisoConcedido: true,
      ),
    );
    await turno();
    expect(capturas, 1);
    expect(c.idViaje, 1);
    expect(c.preparando, false);
  });
  test('envíos serializados, sin cola ni replay tras error de red', () async {
    final enVuelo = Completer<void>();
    c.dispose();
    c = SeguimientoGpsController(
      comprobar: () async => const CondicionesUbicacionInicio(
        servicioActivado: true,
        permisoConcedido: true,
      ),
      capturar: () => fuente.stream,
      enviar: (_, _) async {
        envios++;
        await enVuelo.future;
      },
      sesionVigente: () => true,
    );
    c.confirmar(viaje(EstadoViaje.enCurso), iniciar: true);
    await turno();
    fuente.add(punto);
    await turno();
    fuente.add(punto);
    await turno();
    expect(envios, 1);
    enVuelo.completeError(Exception());
    await turno();
    expect(envios, 1);
    fuente.add(punto);
    await turno();
    expect(envios, 2);
  });
  for (final servicio in [true, false]) {
    test('permiso/servicio faltante no abre captura ($servicio)', () async {
      c.dispose();
      c = SeguimientoGpsController(
        comprobar: () async => CondicionesUbicacionInicio(
          servicioActivado: servicio,
          permisoConcedido: !servicio,
        ),
        capturar: () {
          capturas++;
          return fuente.stream;
        },
        enviar: (_, _) async {},
        sesionVigente: () => true,
      );
      c.confirmar(viaje(EstadoViaje.enCurso), iniciar: true);
      await turno();
      expect(capturas, 0);
      expect(c.activo, false);
    });
  }
  test('lectura regresiva no reactiva un viaje cerrado', () async {
    c.confirmar(viaje(EstadoViaje.enCurso), iniciar: true);
    await turno();
    c.confirmar(viaje(EstadoViaje.finalizado));
    c.confirmar(viaje(EstadoViaje.enCurso), iniciar: true);
    await turno();
    expect(capturas, 1);
    expect(c.puedeReactivar, false);
  });
  test('cambio explícito espera cancelación y no solapa envíos A/B', () async {
    c.dispose();
    final terminarA = Completer<void>();
    var suscripciones = 0;
    var maximo = 0;
    final ids = <int>[];
    c = SeguimientoGpsController(
      comprobar: () async => const CondicionesUbicacionInicio(
        servicioActivado: true,
        permisoConcedido: true,
      ),
      capturar: () => Stream<Position>.multi((sink) {
        suscripciones++;
        if (suscripciones > maximo) maximo = suscripciones;
        final sub = fuente.stream.listen(sink.add);
        sink.onCancel = () async {
          suscripciones--;
          await sub.cancel();
        };
      }),
      enviar: (id, _) async {
        ids.add(id);
        if (id == 1) await terminarA.future;
      },
      sesionVigente: () => vigente,
    );
    c.confirmar(viaje(EstadoViaje.enCurso), iniciar: true);
    await turno();
    fuente.add(punto);
    await turno();
    c.confirmar(viaje(EstadoViaje.enCurso, 2));
    expect(c.idViaje, 1);
    await c.reactivarViaje(2);
    fuente.add(punto);
    await turno();
    expect(ids, [1]); // A sigue en vuelo: no se encola ni se envía B.
    terminarA.complete();
    await turno();
    fuente.add(punto);
    await turno();
    expect(ids, [1, 2]);
    expect(maximo, 1);
  });
  for (final terminal in [EstadoViaje.finalizado, EstadoViaje.cancelado]) {
    test(
      'confirmación $terminal detiene A, sin seleccionar B observado',
      () async {
        c.confirmar(viaje(EstadoViaje.enCurso), iniciar: true);
        await turno();
        c.confirmar(viaje(EstadoViaje.enCurso, 2));
        c.confirmar(viaje(terminal));
        fuente.add(punto);
        await turno();
        expect(envios, 0);
        expect(c.activo, false);
        expect(c.idViaje, 1);
        expect(c.viajesReactivables.toList(), [2]);
      },
    );
  }
}
