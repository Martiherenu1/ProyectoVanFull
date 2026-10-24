import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:frontend/adapters/chofer/comprobador_ubicacion_android.dart';
import 'package:frontend/controllers/chofer/ejecucion_viaje_controller.dart';
import 'package:frontend/models/chofer/operacion_asignada.dart';

import '../../fixtures/chofer/operacion_asignada_fixture.dart';
import '../../fixtures/chofer/plataforma_ubicacion_fake.dart';

void main() {
  for (final permiso in LocationPermission.values) {
    for (final servicio in [false, true]) {
      test('${permiso.name}, servicio $servicio: solo dos consultas', () async {
        final plataforma = PlataformaUbicacionFake()
          ..permiso = permiso
          ..servicio = servicio;
        final resultado = await ComprobadorUbicacionAndroid(
          plataforma: plataforma,
        ).comprobar();
        expect(resultado.servicioActivado, servicio);
        expect(
          resultado.permisoConcedido,
          permiso == LocationPermission.whileInUse ||
              permiso == LocationPermission.always,
        );
        // Incluye aproximado: no se consulta precision ni se exige posicion.
        expect(plataforma.llamadas, ['servicio', 'permiso']);
      });
    }
  }

  test('consulta cada vez sin conservar un permiso anterior', () async {
    final plataforma = PlataformaUbicacionFake();
    final adaptador = ComprobadorUbicacionAndroid(plataforma: plataforma);
    expect((await adaptador.comprobar()).permisoConcedido, isTrue);
    plataforma.permiso = LocationPermission.denied;
    plataforma.servicio = false;
    final resultado = await adaptador.comprobar();
    expect(resultado.servicioActivado, isFalse);
    expect(resultado.permisoConcedido, isFalse);
    expect(plataforma.llamadas, ['servicio', 'permiso', 'servicio', 'permiso']);
  });

  for (final consulta in ['servicio', 'permiso']) {
    test(
      'error de $consulta se propaga para bloquear localmente, sin inicio',
      () async {
        final plataforma = PlataformaUbicacionFake();
        if (consulta == 'servicio') {
          plataforma.falloServicio = StateError('consulta fallida');
        } else {
          plataforma.falloPermiso = StateError('consulta fallida');
        }
        final adaptador = ComprobadorUbicacionAndroid(plataforma: plataforma);
        await expectLater(adaptador.comprobar(), throwsStateError);
        var inicios = 0;
        final json = detalleJson();
        (json['viaje'] as Map)['estado'] = 'programado';
        final detalle = OperacionAsignada.fromJson(json);
        final c = EjecucionViajeController(
          idViaje: 41,
          cargarDetalle: (_) async => detalle,
          acciones: AccionesEjecucionViaje(
            iniciar: (_) async {
              inicios++;
              return detalle.viaje;
            },
            finalizar: (_) async => detalle.viaje,
          ),
          comprobarUbicacionInicio: adaptador.comprobar,
        );
        addTearDown(c.dispose);
        await c.consultar();
        await c.iniciar();
        expect(inicios, 0);
        expect(c.operacionPendiente, isNull);
        expect(c.fase, FaseDetalleViaje.listo);
        expect(
          c.mensajeUbicacion,
          'No pudimos comprobar la ubicación. Volvé a intentarlo.',
        );
        expect(
          plataforma.llamadas.every((s) => s == 'servicio' || s == 'permiso'),
          isTrue,
        );
      },
    );
  }
}
