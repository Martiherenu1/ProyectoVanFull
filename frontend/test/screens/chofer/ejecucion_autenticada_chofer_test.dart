import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/controllers/chofer/ejecucion_viaje_controller.dart';
import 'package:frontend/core/session/sesion_app.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/chofer/chofer_shell.dart';
import 'package:http/http.dart' as http;

import '../../fixtures/chofer/operacion_asignada_fixture.dart';

const _ok = CondicionesUbicacionInicio(
  servicioActivado: true,
  permisoConcedido: true,
);

// Ningún pedido sale del proceso; se usan los adaptadores y HttpApiClient reales.
class Escenario extends http.BaseClient {
  final pedidos = <http.Request>[];
  String estado = 'programado';
  String fecha = '2026-10-30';
  int ingresos = 0;
  int cierres = 0;
  int comprobaciones = 0;
  int statusPost = 200;
  bool incierto = false;
  bool fallarListado = false;
  bool inicioFinalizado = false;
  String? rutaPendiente;
  Completer<http.StreamedResponse>? respuesta;
  Completer<CondicionesUbicacionInicio>? ubicacion;
  CondicionesUbicacionInicio condiciones = _ok;

  Map<String, dynamic> viaje() => {
    ...detalleJson(id: 41)['viaje'] as Map<String, dynamic>,
    'estado': estado,
    'fecha': fecha,
  };

  static http.StreamedResponse json(int status, Object cuerpo) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(cuerpo))),
        status,
        headers: {'content-type': 'application/json'},
      );
  static http.StreamedResponse error(int status) => json(status, {
    'error': {'codigo': 'RECHAZO_SIMULADO', 'mensaje': 'Simulado'},
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    pedidos.add(request as http.Request);
    final path = request.url.path;
    if (path.endsWith('/auth/login')) {
      return json(200, {
        'access_token': 'cuenta-${++ingresos}',
        'roles': ['chofer'],
      });
    }
    if (path.endsWith('/auth/logout')) {
      return http.StreamedResponse(const Stream.empty(), 204);
    }
    if (path == rutaPendiente && respuesta != null) {
      final pendiente = respuesta!;
      respuesta = null;
      return pendiente.future;
    }
    if (request.method == 'POST') {
      if (incierto) throw TimeoutException('Simulado');
      if (statusPost != 200) return error(statusPost);
      estado = path.endsWith('/inicio') && !inicioFinalizado
          ? 'en_curso'
          : 'finalizado';
      return json(200, viaje());
    }
    if (path.endsWith('/choferes/me/viajes')) {
      fecha = request.url.queryParameters['fecha']!;
      if (fallarListado) return error(500);
      return json(200, [viaje()]);
    }
    if (path.endsWith('/choferes/me/viajes/41')) {
      return json(200, {...detalleJson(id: 41), 'viaje': viaje()});
    }
    throw StateError('Ruta no prevista $path');
  }

  List<http.Request> get posts => pedidos
      .where((r) => r.url.path.startsWith('/api/viajes/') && r.method == 'POST')
      .toList();
  List<http.Request> get gets =>
      pedidos.where((r) => r.method == 'GET').toList();

  Future<CondicionesUbicacionInicio> comprobar() async {
    comprobaciones++;
    return ubicacion?.future ?? condiciones;
  }

  Future<void> montar(WidgetTester tester, {bool real = false}) async {
    await tester.pumpWidget(
      VanFullBootstrap(
        apiBaseUrl: 'https://vanfull.test/api/',
        crearTransporte: () => this,
        comprobarUbicacionInicio: real ? null : comprobar,
      ),
    );
  }

  @override
  void close() {
    cierres++;
    super.close();
  }
}

Future<void> ingresar(WidgetTester t) async {
  await t.enterText(find.byType(TextField).at(0), 'chofer');
  await t.enterText(find.byType(TextField).at(1), 'simulada');
  await t.tap(find.text('Ingresar'));
  await paso(t);
}

Future<void> paso(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> detalle(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('viaje-41')));
  await paso(t);
}

Future<void> volver(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await paso(t);
}

Future<void> nuevaCuenta(WidgetTester t) async {
  final controller = t.widget<SesionApp>(find.byType(SesionApp)).controller;
  await controller.salir();
  await paso(t);
  await ingresar(t);
}

Future<void> finalizar(WidgetTester t) async {
  await t.tap(find.text('Finalizar viaje'));
  await paso(t);
  await t.tap(find.text('Finalizar viaje').last);
  await paso(t);
}

void main() {
  testWidgets(
    'listado detalle inicio finalizacion retorno recarga con fecha y body vacío',
    (t) async {
      final e = Escenario();
      await e.montar(t);
      await ingresar(t);
      final fecha = e.fecha;
      await detalle(t);
      await t.tap(find.text('Iniciar viaje'));
      await t.pumpAndSettle();
      expect(e.estado, 'en_curso');
      await finalizar(t);
      await t.pumpAndSettle();
      expect(e.estado, 'finalizado');
      expect(e.comprobaciones, 1);
      await volver(t);
      await t.pumpAndSettle();
      expect(e.gets.last.url.queryParameters, {'fecha': fecha});
      expect(e.posts.map((p) => p.url.path), [
        '/api/viajes/41/inicio',
        '/api/viajes/41/finalizacion',
      ]);
      for (final p in e.posts) {
        expect(p.bodyBytes, isEmpty);
        expect(p.headers['content-type'], isNull);
        expect(p.headers['authorization'], 'Bearer cuenta-1');
      }
      expect(e.cierres, 0);
      await t.pumpWidget(const SizedBox.shrink());
      expect(e.cierres, 1);
    },
  );

  testWidgets(
    'reconstruccion conserva fuentes acciones y cero GET/POST extra',
    (t) async {
      final e = Escenario();
      await e.montar(t);
      await ingresar(t);
      await detalle(t);
      final shell = t.widget<ChoferShell>(find.byType(ChoferShell));
      final cantidad = e.pedidos.length;
      await e.montar(t);
      await t.pumpAndSettle();
      final nuevo = t.widget<ChoferShell>(find.byType(ChoferShell));
      expect(nuevo.acciones, same(shell.acciones));
      expect(nuevo.cargarViajes, shell.cargarViajes);
      expect(nuevo.comprobarUbicacionInicio, shell.comprobarUbicacionInicio);
      expect(e.pedidos.length, cantidad);
    },
  );

  for (final servicio in [false, true]) {
    testWidgets('bloqueo local servicio=$servicio no POST ni recarga', (
      t,
    ) async {
      final e = Escenario()
        ..condiciones = CondicionesUbicacionInicio(
          servicioActivado: servicio,
          permisoConcedido: false,
        );
      await e.montar(t);
      await ingresar(t);
      await detalle(t);
      final cantidad = e.gets.length;
      await t.tap(find.text('Iniciar viaje'));
      await t.pumpAndSettle();
      await volver(t);
      await t.pumpAndSettle();
      expect(e.posts, isEmpty);
      expect(e.gets.length, cantidad);
    });
  }

  testWidgets('plataforma no Android no omite control ni envía inicio', (
    t,
  ) async {
    final e = Escenario();
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await e.montar(t, real: true);
    await ingresar(t);
    await detalle(t);
    await t.tap(find.text('Iniciar viaje'));
    await t.pumpAndSettle();
    expect(e.posts, isEmpty);
    expect(find.textContaining('No pudimos comprobar'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('inicio devuelve finalizado como autoridad', (t) async {
    final e = Escenario()..inicioFinalizado = true;
    await e.montar(t);
    await ingresar(t);
    await detalle(t);
    await t.tap(find.text('Iniciar viaje'));
    await t.pumpAndSettle();
    expect(find.text('Finalizar viaje'), findsNothing);
    expect(find.text('Iniciar viaje'), findsNothing);
    expect(e.estado, 'finalizado');
    expect(e.posts.length, 1);
  });

  testWidgets('incertidumbre sobrevive retorno reapertura y estado previo', (
    t,
  ) async {
    final e = Escenario()..incierto = true;
    await e.montar(t);
    await ingresar(t);
    await detalle(t);
    await t.tap(find.text('Iniciar viaje'));
    await t.pumpAndSettle();
    await volver(t);
    await t.pumpAndSettle();
    await detalle(t);
    await t.pumpAndSettle();
    expect(
      find.textContaining('No pudimos confirmar el resultado'),
      findsOneWidget,
    );
    expect(find.text('Iniciar viaje'), findsNothing);
    expect(e.posts.length, 1);
    e.incierto = false;
    e.statusPost = 409;
    await t.tap(find.text('Reintentar inicio'));
    await t.pumpAndSettle();
    expect(
      find.textContaining('No pudimos confirmar el resultado'),
      findsOneWidget,
    );
    expect(e.comprobaciones, 2);
    expect(e.posts.length, 2);
  });

  testWidgets('fallo recarga no restaura filas antiguas', (t) async {
    final e = Escenario();
    await e.montar(t);
    await ingresar(t);
    await detalle(t);
    await t.tap(find.text('Iniciar viaje'));
    await t.pumpAndSettle();
    e.fallarListado = true;
    await volver(t);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('viaje-41')), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('sesion cambia durante ubicacion y callback anterior no envia', (
    t,
  ) async {
    final e = Escenario()..ubicacion = Completer<CondicionesUbicacionInicio>();
    await e.montar(t);
    await ingresar(t);
    await detalle(t);
    final anterior = t.widget<ChoferShell>(find.byType(ChoferShell)).acciones!;
    await t.tap(find.text('Iniciar viaje'));
    await paso(t);
    await nuevaCuenta(t);
    e.ubicacion!.complete(_ok);
    await t.pumpAndSettle();
    await expectLater(
      anterior.iniciar(41),
      throwsA(isA<RechazoOperacionViaje>()),
    );
    expect(e.posts, isEmpty);
    expect(find.byKey(const ValueKey('viaje-41')), findsOneWidget);
  });

  testWidgets('sesion cambia durante confirmacion no envia', (t) async {
    final e = Escenario()..estado = 'en_curso';
    await e.montar(t);
    await ingresar(t);
    await detalle(t);
    await t.tap(find.text('Finalizar viaje'));
    await paso(t);
    await nuevaCuenta(t);
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(e.posts, isEmpty);
  });

  testWidgets('cancelar confirmacion no consulta ubicacion ni recarga', (
    t,
  ) async {
    final e = Escenario()..estado = 'en_curso';
    await e.montar(t);
    await ingresar(t);
    await detalle(t);
    final cantidad = e.gets.length;
    await t.tap(find.text('Finalizar viaje'));
    await paso(t);
    await t.tap(find.text('Volver'));
    await paso(t);
    await volver(t);
    await t.pumpAndSettle();
    expect(e.posts, isEmpty);
    expect(e.comprobaciones, 0);
    expect(e.gets.length, cantidad);
  });

  testWidgets(
    'repetir finalizacion conserva confirmacion y no consulta ubicacion',
    (t) async {
      final e = Escenario()
        ..estado = 'en_curso'
        ..incierto = true;
      await e.montar(t);
      await ingresar(t);
      await detalle(t);
      await finalizar(t);
      await t.pumpAndSettle();
      await volver(t);
      await t.pumpAndSettle();
      await detalle(t);
      await t.pumpAndSettle();
      expect(find.text('Finalizar viaje'), findsNothing);
      await t.tap(find.text('Reintentar finalización'));
      await paso(t);
      expect(e.posts.length, 1);
      e.incierto = false;
      await t.tap(find.text('Finalizar viaje').last);
      await t.pumpAndSettle();
      expect(e.posts.length, 2);
      expect(e.comprobaciones, 0);
      expect(e.estado, 'finalizado');
    },
  );

  testWidgets('cerrar detalle durante ubicacion no envia ni invalida listado', (
    t,
  ) async {
    final e = Escenario()..ubicacion = Completer<CondicionesUbicacionInicio>();
    await e.montar(t);
    await ingresar(t);
    await detalle(t);
    final cantidad = e.gets.length;
    await t.tap(find.text('Iniciar viaje'));
    await paso(t);
    await volver(t);
    e.ubicacion!.complete(_ok);
    await t.pumpAndSettle();
    expect(e.posts, isEmpty);
    expect(e.gets.length, cantidad + 1);
  });

  testWidgets('POST pendiente bloquea duplicados y recarga hasta terminar', (
    t,
  ) async {
    final e = Escenario();
    await e.montar(t);
    await ingresar(t);
    await detalle(t);
    final respuesta = Completer<http.StreamedResponse>();
    e.rutaPendiente = '/api/viajes/41/inicio';
    e.respuesta = respuesta;
    await t.tap(find.text('Iniciar viaje'));
    await paso(t);
    expect(find.text('Iniciar viaje'), findsNothing);
    expect(e.posts.length, 1);
    final cantidad = e.gets.length;
    await volver(t);
    expect(e.gets.length, cantidad);
    e.estado = 'en_curso';
    respuesta.complete(Escenario.json(200, e.viaje()));
    await t.pumpAndSettle();
    expect(e.gets.length, cantidad + 2);
    expect(e.gets.where((r) => r.url.path.endsWith('/41')).length, 2);
    expect(e.gets.where((r) => r.url.path.endsWith('/viajes')).length, 2);
    expect(e.posts.length, 1);
  });

  testWidgets('exito tardio de A no confirma ni hereda operacion en B', (
    t,
  ) async {
    final e = Escenario();
    await e.montar(t);
    await ingresar(t);
    await detalle(t);
    final respuesta = Completer<http.StreamedResponse>();
    e.rutaPendiente = '/api/viajes/41/inicio';
    e.respuesta = respuesta;
    await t.tap(find.text('Iniciar viaje'));
    await paso(t);
    await nuevaCuenta(t);
    respuesta.complete(
      Escenario.json(200, {...e.viaje(), 'estado': 'en_curso'}),
    );
    await t.pumpAndSettle();
    await detalle(t);
    await t.pumpAndSettle();
    expect(find.text('Iniciar viaje'), findsOneWidget);
    expect(find.textContaining('Estado confirmado:'), findsNothing);
    expect(e.posts.length, 1);
  });

  for (final status in [401, 403]) {
    testWidgets('POST $status vigente usa tratamiento compartido', (t) async {
      final e = Escenario()..statusPost = status;
      await e.montar(t);
      await ingresar(t);
      await detalle(t);
      await t.tap(find.text('Iniciar viaje'));
      await t.pumpAndSettle();
      if (status == 401) {
        expect(find.text('Ingresar'), findsOneWidget);
      } else {
        expect(find.text('Acceso denegado.'), findsOneWidget);
        expect(
          t.widget<SesionApp>(find.byType(SesionApp)).controller.token,
          'cuenta-1',
        );
      }
    });

    for (final ruta in [
      '/api/viajes/41/inicio',
      '/api/choferes/me/viajes/41',
    ]) {
      testWidgets('$status tardio de A durante $ruta no afecta B', (t) async {
        final e = Escenario();
        await e.montar(t);
        await ingresar(t);
        final respuesta = Completer<http.StreamedResponse>();
        e.rutaPendiente = ruta;
        e.respuesta = respuesta;
        await detalle(t);
        if (ruta.contains('/inicio')) {
          await t.tap(find.text('Iniciar viaje'));
          await paso(t);
        }
        await nuevaCuenta(t);
        respuesta.complete(Escenario.error(status));
        await t.pumpAndSettle();
        expect(
          t.widget<SesionApp>(find.byType(SesionApp)).controller.token,
          'cuenta-2',
        );
        expect(find.text('Acceso denegado.'), findsNothing);
        expect(find.byKey(const ValueKey('viaje-41')), findsOneWidget);
        expect(e.posts.length, ruta.contains('/inicio') ? 1 : 0);
      });
    }
  }
}
