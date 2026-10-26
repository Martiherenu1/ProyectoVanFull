import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/controllers/chofer/ejecucion_viaje_controller.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/models/chofer/operacion_asignada.dart';
import 'package:frontend/screens/chofer/acciones_viaje_chofer.dart';
import 'package:frontend/screens/chofer/chofer_shell.dart';
import 'package:frontend/screens/chofer/detalle_viaje_chofer_screen.dart';
import 'package:frontend/screens/chofer/viajes_chofer_screen.dart';
import 'package:frontend/services/chofer/detalle_viaje_chofer_api.dart';
import 'package:frontend/services/chofer/ejecucion_viaje_api.dart';
import 'package:frontend/services/chofer/viajes_chofer_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../fixtures/chofer/operacion_asignada_fixture.dart';

class Escenario {
  Escenario() {
    transporte = MockClient((r) async {
      solicitudes.add(r);
      if (r.method == 'POST') {
        if (rechazar) {
          return http.Response(
            jsonEncode({
              'error': {
                'codigo': 'ESTADO_INVALIDO',
                'mensaje': 'Rechazo simulado',
              },
            }),
            409,
          );
        }
        if (incierto) throw TimeoutException('Transporte simulado');
        final pendiente = operacionPendiente;
        if (pendiente != null) return pendiente.future;
        estado = r.url.path.endsWith('/inicio') ? 'en_curso' : 'finalizado';
        return http.Response(jsonEncode(viaje()), 200);
      }
      if (r.url.path.endsWith('/choferes/me/viajes')) {
        final fechaConsultada = r.url.queryParameters['fecha']!;
        fechas.add(fechaConsultada);
        if (fallarListado) throw http.ClientException('Fallo simulado');
        final pendiente = listadoPendiente;
        if (pendiente != null) return pendiente.future;
        fechaViaje = fechaConsultada;
        return http.Response(
          jsonEncode([viaje(), if (dosViajes) viaje(id: 52)]),
          200,
        );
      }
      if (fallarDetalle) throw http.ClientException('Detalle simulado fallido');
      final id = int.parse(r.url.pathSegments.last);
      final pendiente = detallesPendientes[id];
      if (pendiente != null) return pendiente.future;
      final detalle = detalleJson(id: id);
      detalle['viaje'] = viaje(id: id);
      return http.Response(jsonEncode(detalle), 200);
    });
    final cliente = HttpApiClient(
      baseUri: Uri.parse('https://vanfull.test/api/'),
      transport: transporte,
    );
    cargarViajes = ViajesChoferApi(cliente).cargarViajes;
    cargarDetalle = DetalleViajeChoferApi(cliente).cargarDetalle;
    final ejecucion = EjecucionViajeApi(cliente);
    acciones = AccionesEjecucionViaje(
      iniciar: ejecucion.iniciar,
      finalizar: ejecucion.finalizar,
    );
  }

  late final MockClient transporte;
  late final CargarViajesChofer cargarViajes;
  late final CargarDetalleViajeChofer cargarDetalle;
  late final AccionesEjecucionViaje acciones;
  final solicitudes = <http.Request>[];
  final fechas = <String>[];
  String estado = 'programado';
  String fechaViaje = '2026-10-30';
  bool incierto = false;
  bool rechazar = false;
  bool fallarListado = false;
  bool fallarDetalle = false;
  bool dosViajes = false;
  bool servicio = true;
  bool permiso = true;
  int comprobaciones = 0;
  Completer<http.Response>? operacionPendiente;
  Completer<http.Response>? listadoPendiente;
  Completer<CondicionesUbicacionInicio>? condicionesPendientes;
  final detallesPendientes = <int, Completer<http.Response>>{};

  Map<String, dynamic> viaje({int id = 41}) => {
    ...detalleJson(id: id)['viaje'] as Map<String, dynamic>,
    'estado': estado,
    'fecha': fechaViaje,
  };

  Future<CondicionesUbicacionInicio> comprobar() async {
    comprobaciones++;
    final pendiente = condicionesPendientes;
    if (pendiente != null) return pendiente.future;
    return CondicionesUbicacionInicio(
      servicioActivado: servicio,
      permisoConcedido: permiso,
    );
  }

  int get posts => solicitudes.where((r) => r.method == 'POST').length;

  Future<void> mostrar(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChoferShell(
          fechaInicial: DateTime(2026, 10, 30),
          cargarViajes: cargarViajes,
          cargarDetalle: cargarDetalle,
          acciones: acciones,
          comprobarUbicacionInicio: comprobar,
          onSalir: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

class ControladorObservable extends EjecucionViajeController {
  ControladorObservable(Escenario e)
    : super(
        idViaje: 41,
        cargarDetalle: e.cargarDetalle,
        acciones: e.acciones,
        comprobarUbicacionInicio: e.comprobar,
      );

  final escuchas = <VoidCallback>[];
  int disposiciones = 0;

  @override
  void addListener(VoidCallback listener) {
    escuchas.add(listener);
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    escuchas.remove(listener);
    super.removeListener(listener);
  }

  @override
  void dispose() {
    disposiciones++;
    escuchas.clear();
    super.dispose();
  }
}

Future<void> abrir(WidgetTester t, {int id = 41}) async {
  await t.tap(find.byKey(ValueKey('viaje-$id')));
  await t.pumpAndSettle();
}

EjecucionViajeController controladorVisible(WidgetTester t) =>
    t.widget<AccionesViajeChofer>(find.byType(AccionesViajeChofer)).controlador;

Future<void> volver(WidgetTester t) async {
  await t.tap(find.byTooltip('Back'));
  await t.pumpAndSettle();
}

void main() {
  late Escenario e;
  setUp(() => e = Escenario());
  tearDown(() => e.transporte.close());

  testWidgets(
    'propaga acciones y comprobador; inicia y recarga sin remontar ni perder fecha',
    (t) async {
      await e.mostrar(t);
      await t.tap(find.byKey(const ValueKey('seleccionar-fecha')));
      await t.pumpAndSettle();
      await t.tap(find.text('31'));
      await t.tap(find.text('Consultar'));
      await t.pumpAndSettle();
      final estadoListado = t.state(find.byType(ViajesChoferScreen));
      await abrir(t);
      expect(find.text('Fecha: 31/10/2026 · 07:30'), findsOneWidget);
      final detalle = t.widget<DetalleViajeChoferScreen>(
        find.byType(DetalleViajeChoferScreen),
      );
      expect(detalle.comprobarUbicacionInicio, e.comprobar);
      await t.tap(find.text('Iniciar viaje'));
      await t.pumpAndSettle();
      expect(e.posts, 1);
      expect(e.comprobaciones, 1);
      expect(
        t
            .widget<ViajesChoferScreen>(
              find.byType(ViajesChoferScreen, skipOffstage: false),
            )
            .invalidado,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('viaje-41'), skipOffstage: false),
        findsNothing,
      );
      expect(e.fechas, ['2026-10-30', '2026-10-31']);
      await volver(t);
      expect(
        identical(t.state(find.byType(ViajesChoferScreen)), estadoListado),
        isTrue,
      );
      expect(find.text('Fecha: 31/10/2026'), findsOneWidget);
      expect(e.fechas.last, '2026-10-31');
      expect(find.text('Viaje 41 · Ida · En curso'), findsOneWidget);
      final r = e.solicitudes.singleWhere((r) => r.method == 'POST');
      expect(r.url.path, '/api/viajes/41/inicio');
      expect(r.bodyBytes, isEmpty);
    },
  );

  for (final bloqueo in ['servicio', 'permiso', 'sin comprobador']) {
    testWidgets('bloqueo $bloqueo no envía ni invalida', (t) async {
      e.servicio = bloqueo != 'servicio';
      e.permiso = bloqueo != 'permiso';
      if (bloqueo == 'sin comprobador') {
        await t.pumpWidget(
          MaterialApp(
            home: ChoferShell(
              cargarViajes: e.cargarViajes,
              cargarDetalle: e.cargarDetalle,
              acciones: e.acciones,
              onSalir: () {},
            ),
          ),
        );
        await t.pumpAndSettle();
      } else {
        await e.mostrar(t);
      }
      await abrir(t);
      await t.tap(find.text('Iniciar viaje'));
      await t.pumpAndSettle();
      expect(e.posts, 0);
      expect(
        t
            .widget<ViajesChoferScreen>(
              find.byType(ViajesChoferScreen, skipOffstage: false),
            )
            .invalidado,
        isFalse,
      );
      await volver(t);
      expect(e.fechas, hasLength(1));
    });
  }

  testWidgets('cancelar diálogo no invalida; finalizar no consulta ubicación', (
    t,
  ) async {
    e.estado = 'en_curso';
    e.servicio = false;
    await e.mostrar(t);
    await abrir(t);
    await t.tap(find.text('Finalizar viaje'));
    await t.pumpAndSettle();
    await t.tap(find.text('Volver'));
    await t.pumpAndSettle();
    expect(e.posts, 0);
    expect(
      t
          .widget<ViajesChoferScreen>(
            find.byType(ViajesChoferScreen, skipOffstage: false),
          )
          .invalidado,
      isFalse,
    );
    await t.tap(find.text('Finalizar viaje'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ElevatedButton, 'Finalizar viaje').last);
    await t.pumpAndSettle();
    expect(e.posts, 1);
    expect(e.comprobaciones, 0);
    await volver(t);
    expect(find.text('Viaje 41 · Ida · Finalizado'), findsOneWidget);
    expect(e.fechas, hasLength(2));
  });

  testWidgets(
    'incierto invalida; consultar y rechazo posterior no lo resuelven',
    (t) async {
      e.incierto = true;
      await e.mostrar(t);
      await abrir(t);
      await t.tap(find.text('Iniciar viaje'));
      await t.pumpAndSettle();
      final c = t
          .widget<AccionesViajeChofer>(find.byType(AccionesViajeChofer))
          .controlador;
      expect(c.fase, FaseDetalleViaje.incierto);
      await t.tap(find.text('Consultar estado'));
      await t.pumpAndSettle();
      expect(c.fase, FaseDetalleViaje.incierto);
      e.rechazar = true;
      await t.tap(find.text('Reintentar inicio'));
      await t.pumpAndSettle();
      expect(c.fase, FaseDetalleViaje.incierto);
      expect(e.posts, 2);
      await volver(t);
      expect(e.fechas, hasLength(2));
    },
  );

  for (final finalizar in [false, true]) {
    testWidgets(
      '${finalizar ? 'finalización' : 'inicio'} incierto conserva protección al volver y reabrir',
      (t) async {
        e.estado = finalizar ? 'en_curso' : 'programado';
        e.incierto = true;
        await e.mostrar(t);
        await abrir(t);
        if (finalizar) {
          await t.tap(find.text('Finalizar viaje'));
          await t.pumpAndSettle();
          await t.tap(
            find.widgetWithText(ElevatedButton, 'Finalizar viaje').last,
          );
        } else {
          await t.tap(find.text('Iniciar viaje'));
        }
        await t.pumpAndSettle();
        expect(find.text('Consultar estado'), findsOneWidget);
        expect(e.posts, 1);
        await volver(t);
        expect(e.fechas, hasLength(2));
        await abrir(t);
        // Examinar el controlador y los controles actualmente montados,
        // no la instancia descartada al salir de la primera ruta.
        final reabierto = t
            .widget<AccionesViajeChofer>(find.byType(AccionesViajeChofer))
            .controlador;
        expect(e.posts, 1, reason: 'Reabrir no debe reenviar automáticamente.');
        expect(
          {
            'fase': reabierto.fase,
            'puedeIniciar': reabierto.puedeIniciar,
            'puedeFinalizar': reabierto.puedeFinalizar,
            'inicioVisible': find.text('Iniciar viaje').evaluate().length,
            'finalizacionVisible': find
                .text('Finalizar viaje')
                .evaluate()
                .length,
          },
          {
            'fase': FaseDetalleViaje.incierto,
            'puedeIniciar': false,
            'puedeFinalizar': false,
            'inicioVisible': 0,
            'finalizacionVisible': 0,
          },
        );
      },
    );
  }

  for (final reintento in [false, true]) {
    testWidgets(
      'control local tardío tras cerrar no envía ${reintento ? 'reintento' : 'inicio'}',
      (t) async {
        e.incierto = reintento;
        await e.mostrar(t);
        await abrir(t);
        final c = controladorVisible(t);
        if (reintento) {
          await t.tap(find.text('Iniciar viaje'));
          await t.pumpAndSettle();
          await t.tap(find.text('Consultar estado'));
          await t.pumpAndSettle();
        }
        final pendientes = c.operacionPendiente;
        final condiciones = Completer<CondicionesUbicacionInicio>();
        e.condicionesPendientes = condiciones;
        await t.tap(
          find.text(reintento ? 'Reintentar inicio' : 'Iniciar viaje'),
        );
        await t.pump();
        expect(c.comprobandoUbicacion, isTrue);
        await volver(t);
        final postsAntes = e.posts;
        condiciones.complete(
          const CondicionesUbicacionInicio(
            servicioActivado: true,
            permisoConcedido: true,
          ),
        );
        await t.pumpAndSettle();
        expect(e.posts, postsAntes);
        expect(c.comprobandoUbicacion, isFalse);
        await abrir(t);
        expect(controladorVisible(t), same(c));
        expect(c.operacionPendiente, pendientes);
        if (reintento) {
          expect(c.fase, FaseDetalleViaje.incierto);
          expect(c.puedeIniciar || c.puedeFinalizar, isFalse);
        }
        expect(e.posts, reintento ? 1 : 0);
      },
    );
  }

  testWidgets('reaperturas sucesivas conservan instancia y pendiente', (
    t,
  ) async {
    e.incierto = true;
    await e.mostrar(t);
    await abrir(t);
    await t.tap(find.text('Iniciar viaje'));
    await t.pumpAndSettle();
    final c = controladorVisible(t);
    final pendientes = c.operacionPendiente;
    for (var i = 0; i < 3; i++) {
      await volver(t);
      expect(ChangeNotifier.debugAssertNotDisposed(c), isTrue);
      final lecturas = e.solicitudes
          .where((r) => r.url.path.endsWith('/viajes/41'))
          .length;
      await abrir(t);
      expect(controladorVisible(t), same(c));
      expect(c.fase, FaseDetalleViaje.incierto);
      expect(c.operacionPendiente, pendientes);
      expect(c.puedeIniciar || c.puedeFinalizar, isFalse);
      expect(e.posts, 1);
      expect(
        e.solicitudes.where((r) => r.url.path.endsWith('/viajes/41')),
        hasLength(lecturas + 1),
      );
    }
    e.rechazar = true;
    await t.tap(find.text('Reintentar inicio'));
    await t.pumpAndSettle();
    expect(c.fase, FaseDetalleViaje.incierto);
    expect(c.operacionPendiente, pendientes);
    await volver(t);
    await abrir(t);
    expect(controladorVisible(t), same(c));
    expect(c.fase, FaseDetalleViaje.incierto);
    expect(c.operacionPendiente, pendientes);
    expect(e.posts, 2);
  });

  testWidgets('viajes distintos no comparten incertidumbre ni coordinador', (
    t,
  ) async {
    e.dosViajes = true;
    e.incierto = true;
    await e.mostrar(t);
    await abrir(t);
    await t.tap(find.text('Iniciar viaje'));
    await t.pumpAndSettle();
    final primero = controladorVisible(t);
    await volver(t);
    await abrir(t, id: 52);
    final segundo = controladorVisible(t);
    expect(segundo, isNot(same(primero)));
    expect(segundo.fase, FaseDetalleViaje.listo);
    expect(segundo.operacionPendiente, isNull);
    expect(segundo.puedeIniciar, isTrue);
    await volver(t);
    await abrir(t);
    expect(controladorVisible(t), same(primero));
    expect(primero.fase, FaseDetalleViaje.incierto);
    expect(e.posts, 1);
  });

  testWidgets('confirmación sin detalle se conserva al cerrar y reabrir', (
    t,
  ) async {
    await e.mostrar(t);
    await abrir(t);
    e.fallarDetalle = true;
    await t.tap(find.text('Iniciar viaje'));
    await t.pumpAndSettle();
    final c = controladorVisible(t);
    expect(c.fase, FaseDetalleViaje.confirmadoSinDetalle);
    expect(c.viajeConfirmado?.estado.valorApi, 'en_curso');
    await volver(t);
    await abrir(t);
    expect(controladorVisible(t), same(c));
    expect(c.fase, FaseDetalleViaje.confirmadoSinDetalle);
    expect(c.viajeConfirmado?.estado.valorApi, 'en_curso');
    expect(c.puedeIniciar || c.puedeFinalizar, isFalse);
    expect(find.text('Estado confirmado: En curso'), findsOneWidget);
    expect(find.byKey(const ValueKey('reserva-61')), findsNothing);
    expect(e.posts, 1);
    e.fallarDetalle = false;
    await t.tap(find.text('Actualizar detalle'));
    await t.pumpAndSettle();
    expect(c.fase, FaseDetalleViaje.listo);
    expect(e.posts, 1);
  });

  testWidgets(
    'shell dispone los coordinadores retenidos y la nueva instancia no los hereda',
    (t) async {
      e.dosViajes = true;
      e.incierto = true;
      await e.mostrar(t);
      await abrir(t);
      await t.tap(find.text('Iniciar viaje'));
      await t.pumpAndSettle();
      final primero = controladorVisible(t);
      await volver(t);
      await abrir(t, id: 52);
      final segundo = controladorVisible(t);
      await t.pumpWidget(const MaterialApp(home: SizedBox()));
      await t.pumpAndSettle();
      expect(() => primero.addListener(() {}), throwsFlutterError);
      expect(() => segundo.addListener(() {}), throwsFlutterError);
      await e.mostrar(t);
      await abrir(t);
      final nuevo = controladorVisible(t);
      expect(nuevo, isNot(same(primero)));
      expect(nuevo.operacionPendiente, isNull);
      expect(nuevo.fase, FaseDetalleViaje.listo);
      expect(e.posts, 1);
    },
  );

  testWidgets(
    'detalle prestado retira su listener sin disponer y no duplica al reconstruir',
    (t) async {
      final c = ControladorObservable(e);
      addTearDown(() {
        if (c.disposiciones == 0) c.dispose();
      });
      await c.consultar(); // El propietario inicia las consultas.
      Future<void> montar() => t.pumpWidget(
        MaterialApp(
          home: DetalleViajeChoferScreen(
            idViaje: 41,
            cargarDetalle: e.cargarDetalle,
            acciones: e.acciones,
            comprobarUbicacionInicio: e.comprobar,
            controlador: c,
          ),
        ),
      );
      await montar();
      await t.pumpAndSettle();
      expect(c.escuchas, hasLength(1));
      final peticiones = e.solicitudes.length;
      await montar();
      await t.pumpAndSettle();
      expect(c.escuchas, hasLength(1));
      await t.pumpWidget(const MaterialApp(home: SizedBox()));
      await t.pumpAndSettle();
      expect(c.escuchas, isEmpty);
      expect(c.disposiciones, 0);
      await montar();
      await t.pumpAndSettle();
      expect(c.escuchas, hasLength(1));
      expect(e.solicitudes, hasLength(peticiones));
      await t.pumpWidget(const MaterialApp(home: SizedBox()));
      await t.pumpAndSettle();
      expect(c.escuchas, isEmpty);
      expect(c.disposiciones, 0);
      c.dispose();
      expect(c.disposiciones, 1);
    },
  );

  testWidgets(
    'respuesta tardía de otro viaje no actualiza el detalle visible',
    (t) async {
      e.dosViajes = true;
      final pendiente = Completer<http.Response>();
      e.detallesPendientes[41] = pendiente;
      await e.mostrar(t);
      await t.tap(find.byKey(const ValueKey('viaje-41')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      await abrir(t, id: 52);
      final actual = controladorVisible(t);
      pendiente.complete(
        http.Response(jsonEncode({...detalleJson(), 'viaje': e.viaje()}), 200),
      );
      await t.pumpAndSettle();
      expect(controladorVisible(t), same(actual));
      expect(find.byKey(const ValueKey('detalle-52')), findsOneWidget);
      expect(find.byKey(const ValueKey('detalle-41')), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('reabrir con GET en vuelo no inicia una consulta duplicada', (
    t,
  ) async {
    final pendiente = Completer<http.Response>();
    e.detallesPendientes[41] = pendiente;
    await e.mostrar(t);
    await t.tap(find.byKey(const ValueKey('viaje-41')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    final c = t
        .widget<DetalleViajeChoferScreen>(find.byType(DetalleViajeChoferScreen))
        .controlador!;
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(ChangeNotifier.debugAssertNotDisposed(c), isTrue);
    await t.tap(find.byKey(const ValueKey('viaje-41')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(
      t
          .widget<DetalleViajeChoferScreen>(
            find.byType(DetalleViajeChoferScreen),
          )
          .controlador,
      same(c),
    );
    expect(
      e.solicitudes.where((r) => r.url.path.endsWith('/viajes/41')),
      hasLength(1),
    );
    pendiente.complete(
      http.Response(jsonEncode({...detalleJson(), 'viaje': e.viaje()}), 200),
    );
    await t.pumpAndSettle();
    expect(controladorVisible(t), same(c));
    expect(c.fase, FaseDetalleViaje.listo);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'fuente reemplazada fuera de la ruta descarta lectura anterior y consulta una vez',
    (t) async {
      final nueva = ValueNotifier(false);
      addTearDown(nueva.dispose);
      var lecturasNuevas = 0;
      Future<OperacionAsignada?> nuevaFuente(int _) async {
        lecturasNuevas++;
        return null;
      }

      final pendiente = Completer<http.Response>();
      e.detallesPendientes[41] = pendiente;
      await t.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: nueva,
            builder: (_, cambiar, _) => ChoferShell(
              cargarViajes: e.cargarViajes,
              cargarDetalle: cambiar ? nuevaFuente : e.cargarDetalle,
              acciones: e.acciones,
              comprobarUbicacionInicio: e.comprobar,
              onSalir: () {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('viaje-41')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      final c = t
          .widget<DetalleViajeChoferScreen>(
            find.byType(DetalleViajeChoferScreen),
          )
          .controlador!;
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      nueva.value = true;
      await t.pumpAndSettle();
      expect(
        lecturasNuevas,
        0,
        reason: 'Una ruta cerrada se sincroniza al reabrir.',
      );
      await abrir(t);
      expect(lecturasNuevas, 1);
      expect(controladorVisible(t), same(c));
      expect(c.fase, FaseDetalleViaje.noDisponible);
      pendiente.complete(
        http.Response(jsonEncode({...detalleJson(), 'viaje': e.viaje()}), 200),
      );
      await t.pumpAndSettle();
      expect(c.fase, FaseDetalleViaje.noDisponible);
      expect(lecturasNuevas, 1);
      expect(find.byKey(const ValueKey('reserva-61')), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'recarga fallida retira filas y permite reintentar la misma fecha',
    (t) async {
      await e.mostrar(t);
      await abrir(t);
      await t.tap(find.text('Iniciar viaje'));
      await t.pumpAndSettle();
      e.fallarListado = true;
      await volver(t);
      expect(
        find.text('No pudimos cargar los viajes. Volvé a intentar.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('viaje-41')), findsNothing);
      e.fallarListado = false;
      await t.tap(find.text('Reintentar'));
      await t.pumpAndSettle();
      expect(e.fechas, ['2026-10-30', '2026-10-30', '2026-10-30']);
      expect(find.text('Viaje 41 · Ida · En curso'), findsOneWidget);
    },
  );

  testWidgets('volver durante POST espera su final antes de recargar', (
    t,
  ) async {
    final pendiente = Completer<http.Response>();
    e.operacionPendiente = pendiente;
    await e.mostrar(t);
    await abrir(t);
    await t.tap(find.text('Iniciar viaje'));
    await t.pump();
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(find.text('El listado necesita actualizarse.'), findsOneWidget);
    expect(e.fechas, hasLength(1));
    e.estado = 'en_curso';
    pendiente.complete(http.Response(jsonEncode(e.viaje()), 200));
    await t.pumpAndSettle();
    expect(e.fechas, hasLength(2));
    expect(find.text('Viaje 41 · Ida · En curso'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'reconstrucción con dependencias estables no reinicia el detalle',
    (t) async {
      final reconstruir = ValueNotifier(0);
      addTearDown(reconstruir.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<int>(
            valueListenable: reconstruir,
            builder: (_, _, _) => ChoferShell(
              cargarViajes: e.cargarViajes,
              cargarDetalle: e.cargarDetalle,
              acciones: e.acciones,
              comprobarUbicacionInicio: e.comprobar,
              onSalir: () {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await abrir(t);
      final antes = t
          .widget<DetalleViajeChoferScreen>(
            find.byType(DetalleViajeChoferScreen),
          )
          .acciones;
      final peticiones = e.solicitudes.length;
      reconstruir.value++;
      await t.pumpAndSettle();
      expect(
        t
            .widget<DetalleViajeChoferScreen>(
              find.byType(DetalleViajeChoferScreen),
            )
            .acciones,
        same(antes),
      );
      expect(e.solicitudes, hasLength(peticiones));
    },
  );

  for (final errorTardio in [false, true]) {
    testWidgets(
      'invalidar descarta ${errorTardio ? 'error' : 'respuesta'} de listado anterior',
      (t) async {
        final senal = ValueNotifier((invalidado: false, revision: 0));
        addTearDown(senal.dispose);
        await t.pumpWidget(
          MaterialApp(
            home: ValueListenableBuilder<({bool invalidado, int revision})>(
              valueListenable: senal,
              builder: (_, valor, _) => ViajesChoferScreen(
                cargarViajes: e.cargarViajes,
                onViajeSeleccionado: (_) {},
                fechaInicial: DateTime(2026, 10, 30),
                invalidado: valor.invalidado,
                revisionRecarga: valor.revision,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final estadoListado = t.state(find.byType(ViajesChoferScreen));
        final anterior = Completer<http.Response>();
        e.listadoPendiente = anterior;
        senal.value = (invalidado: false, revision: 1);
        await t.pump();
        senal.value = (invalidado: true, revision: 1);
        await t.pump();
        expect(find.byType(ListTile), findsNothing);
        if (errorTardio) {
          anterior.completeError(
            http.ClientException('Respuesta tardía simulada'),
          );
        } else {
          anterior.complete(
            http.Response(
              jsonEncode([
                {...e.viaje(), 'id_viaje': 99},
              ]),
              200,
            ),
          );
        }
        await t.pumpAndSettle();
        expect(find.text('El listado necesita actualizarse.'), findsOneWidget);
        expect(find.byKey(const ValueKey('viaje-99')), findsNothing);
        e.listadoPendiente = null;
        e.estado = 'finalizado';
        senal.value = (invalidado: false, revision: 2);
        await t.pumpAndSettle();
        expect(t.state(find.byType(ViajesChoferScreen)), same(estadoListado));
        expect(find.text('Viaje 41 · Ida · Finalizado'), findsOneWidget);
        expect(find.byKey(const ValueKey('viaje-99')), findsNothing);
      },
    );
  }

  testWidgets(
    'terminar POST tras desmontar no recarga ni publica resultado tardío',
    (t) async {
      final pendiente = Completer<http.Response>();
      e.operacionPendiente = pendiente;
      await e.mostrar(t);
      await abrir(t);
      await t.tap(find.text('Iniciar viaje'));
      await t.pump();
      await t.pumpWidget(const MaterialApp(home: SizedBox()));
      await t.pumpAndSettle();
      e.estado = 'en_curso';
      pendiente.complete(http.Response(jsonEncode(e.viaje()), 200));
      await t.pumpAndSettle();
      expect(e.fechas, hasLength(1));
      expect(find.text('Detalle del viaje'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
}
