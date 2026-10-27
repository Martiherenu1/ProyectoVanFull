import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/session/sesion_app.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/chofer/chofer_shell.dart';
import 'package:frontend/screens/chofer/detalle_viaje_chofer_screen.dart';
import 'package:http/http.dart' as http;

import '../../fixtures/chofer/operacion_asignada_fixture.dart';

const _listado = '/api/choferes/me/viajes';

// Todos los pedidos terminan aquí; no se abre ninguna conexión de red.
final class _Transporte extends http.BaseClient {
  final pedidos = <http.BaseRequest>[];
  int ingresos = 0;
  int cierres = 0;
  int estadoListado = 200;
  int estadoDetalle = 200;
  String? rutaPendiente;
  Completer<http.StreamedResponse>? pendiente;
  Completer<http.StreamedResponse>? logoutPendiente;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    pedidos.add(request);
    final ruta = request.url.path;
    if (ruta == '/api/auth/login') {
      return json(200, {
        'access_token': 'cuenta-${++ingresos}',
        'token_type': 'bearer',
        'roles': ['chofer'],
      });
    }
    if (ruta == '/api/auth/logout') {
      return logoutPendiente?.future ?? json(204, null);
    }
    if (ruta == rutaPendiente && pendiente != null) {
      final respuesta = pendiente!;
      pendiente = null;
      return respuesta.future;
    }
    final id = request.headers['authorization'] == 'Bearer cuenta-1' ? 41 : 52;
    if (ruta == _listado) {
      return estadoListado == 200
          ? json(200, [viaje(id)])
          : error(estadoListado);
    }
    if (ruta == '$_listado/$id') {
      return estadoDetalle == 200
          ? json(200, detalleJson(id: id))
          : error(estadoDetalle);
    }
    throw StateError('Pedido inesperado: ${request.method} $ruta');
  }

  Iterable<http.BaseRequest> get consultas =>
      pedidos.where((pedido) => pedido.method == 'GET');

  static Map<String, dynamic> viaje(int id) =>
      detalleJson(id: id)['viaje'] as Map<String, dynamic>;

  static http.StreamedResponse json(int estado, Object? cuerpo) =>
      http.StreamedResponse(
        cuerpo == null
            ? const Stream.empty()
            : Stream.value(utf8.encode(jsonEncode(cuerpo))),
        estado,
        headers: const {'content-type': 'application/json'},
      );

  static http.StreamedResponse error(int estado) => json(estado, {
    'error': {'codigo': 'ERROR_SIMULADO', 'mensaje': 'Respuesta simulada'},
  });

  @override
  void close() {
    cierres++;
    super.close();
  }
}

Future<void> _montar(WidgetTester tester, _Transporte transporte) async {
  await tester.pumpWidget(
    VanFullBootstrap(
      apiBaseUrl: 'https://vanfull.test/api/',
      crearTransporte: () => transporte,
    ),
  );
}

Future<void> _ingresar(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'chofer-simulado');
  await tester.enterText(find.byType(TextField).at(1), 'clave-simulada');
  await tester.tap(find.text('Ingresar'));
  // También sirve cuando queda una consulta pendiente con indicador animado.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _detalle(WidgetTester tester, {int id = 41}) async {
  await tester.tap(find.byKey(ValueKey('viaje-$id')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _salir(WidgetTester tester) async {
  await tester.tap(find.text('Cerrar sesión'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('fecha explícita, ID, token, retorno sin recarga y salida', (
    tester,
  ) async {
    final transporte = _Transporte();
    await _montar(tester, transporte);
    await _ingresar(tester);
    await tester.pumpAndSettle();
    final inicial = DateTime.parse(
      transporte.consultas.single.url.queryParameters['fecha']!,
    );
    final dia = inicial.day == 1 ? 2 : 1;
    await tester.tap(find.byKey(const ValueKey('seleccionar-fecha')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$dia'));
    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();
    final elegida = DateTime(inicial.year, inicial.month, dia);
    final fechaApi = elegida.toIso8601String().substring(0, 10);
    expect(transporte.consultas.last.url.queryParameters, {'fecha': fechaApi});

    await _detalle(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detalle-41')), findsOneWidget);
    expect(transporte.consultas.last.url.path, '$_listado/41');
    expect(transporte.consultas.last.url.queryParameters, isEmpty);
    expect(find.text('Iniciar viaje'), findsNothing);
    expect(find.text('Finalizar viaje'), findsOneWidget);
    final cantidad = transporte.consultas.length;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('viaje-41')), findsOneWidget);
    expect(
      find.text(
        'Fecha: ${dia.toString().padLeft(2, '0')}/'
        '${inicial.month.toString().padLeft(2, '0')}/${inicial.year}',
      ),
      findsOneWidget,
    );
    expect(transporte.consultas.length, cantidad);
    for (final pedido in transporte.consultas) {
      expect(pedido.method, 'GET');
      expect(pedido.headers['authorization'], 'Bearer cuenta-1');
    }
    expect(transporte.pedidos.first.headers['authorization'], isNull);
    await _salir(tester);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(transporte.pedidos.last.url.path, '/api/auth/logout');
    expect(transporte.pedidos.last.headers['authorization'], 'Bearer cuenta-1');
    expect(transporte.cierres, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(transporte.cierres, 1);
  });

  for (final enDetalle in [false, true]) {
    final lugar = enDetalle ? 'detalle' : 'listado';
    for (final estado in [401, 403, 404, 500]) {
      testWidgets('$estado en $lugar usa la política común', (tester) async {
        final transporte = _Transporte();
        if (enDetalle) {
          transporte.estadoDetalle = estado;
        } else {
          transporte.estadoListado = estado;
        }
        await _montar(tester, transporte);
        await _ingresar(tester);
        if (enDetalle) await _detalle(tester);
        await tester.pumpAndSettle();
        if (estado == 401) {
          expect(find.text('Ingresar'), findsOneWidget);
          expect(find.byType(ChoferShell), findsNothing);
        } else if (estado == 403) {
          expect(find.text('Acceso denegado.'), findsOneWidget);
          expect(find.byType(ChoferShell), findsNothing);
          expect(find.text('Ingresar'), findsNothing);
          await _salir(tester);
          expect(
            transporte.pedidos.last.headers['authorization'],
            'Bearer cuenta-1',
          );
        } else {
          expect(find.text('Ingresar'), findsNothing);
          if (enDetalle && estado == 404) {
            expect(find.text('Detalle no disponible.'), findsOneWidget);
          } else {
            final reintentar = enDetalle ? 'Actualizar detalle' : 'Reintentar';
            expect(find.text(reintentar), findsOneWidget);
            transporte.estadoListado = 200;
            transporte.estadoDetalle = 200;
            await tester.tap(find.text(reintentar));
            await tester.pumpAndSettle();
            expect(
              find.byKey(ValueKey(enDetalle ? 'detalle-41' : 'viaje-41')),
              findsOneWidget,
            );
          }
        }
        expect(transporte.cierres, 0);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(transporte.cierres, 1);
      });
    }

    for (final estado in [200, 401, 403, 404, 500]) {
      testWidgets('$estado tardío de $lugar de A no afecta a B', (
        tester,
      ) async {
        final anterior = Completer<http.StreamedResponse>();
        final transporte = _Transporte()
          ..rutaPendiente = enDetalle ? '$_listado/41' : _listado
          ..pendiente = anterior;
        await _montar(tester, transporte);
        await _ingresar(tester);
        if (enDetalle) await _detalle(tester);
        final estadoAnterior = tester.state(find.byType(ChoferShell));
        final controller = tester
            .widget<SesionApp>(find.byType(SesionApp))
            .controller;
        final generacion = controller.generacion;
        await _salir(tester);
        expect(estadoAnterior.mounted, isFalse);
        await _ingresar(tester);
        await tester.pumpAndSettle();
        expect(controller.generacion, greaterThan(generacion));
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is KeyedSubtree &&
                widget.key == ValueKey(controller.generacion),
          ),
          findsOneWidget,
        );
        expect(
          tester.state(find.byType(ChoferShell)),
          isNot(same(estadoAnterior)),
        );
        expect(find.byKey(const ValueKey('viaje-52')), findsOneWidget);
        if (estado == 200) {
          anterior.complete(
            _Transporte.json(
              200,
              enDetalle ? detalleJson() : [_Transporte.viaje(41)],
            ),
          );
        } else {
          anterior.complete(_Transporte.error(estado));
        }
        await tester.pumpAndSettle();
        expect(controller.token, 'cuenta-2');
        expect(find.byKey(const ValueKey('viaje-52')), findsOneWidget);
        expect(find.byKey(const ValueKey('viaje-41')), findsNothing);
        expect(find.byType(DetalleViajeChoferScreen), findsNothing);
        expect(find.text('Acceso denegado.'), findsNothing);
        expect(find.text('Ingresar'), findsNothing);
        expect(tester.takeException(), isNull);
        await _detalle(tester, id: 52);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('detalle-52')), findsOneWidget);
        expect(
          transporte.consultas.last.headers['authorization'],
          'Bearer cuenta-2',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('logout lento de A no bloquea ni invalida el ingreso de B', (
    tester,
  ) async {
    final pendiente = Completer<http.StreamedResponse>();
    final transporte = _Transporte()..logoutPendiente = pendiente;
    await _montar(tester, transporte);
    await _ingresar(tester);
    await _salir(tester);
    expect(transporte.pedidos.last.headers['authorization'], 'Bearer cuenta-1');
    await _ingresar(tester);
    pendiente.complete(_Transporte.error(401));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('viaje-52')), findsOneWidget);
    expect(find.text('Ingresar'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reconstruir la composición conserva callbacks y no recarga', (
    tester,
  ) async {
    final transporte = _Transporte();
    await _montar(tester, transporte);
    await _ingresar(tester);
    await _detalle(tester);
    await tester.pumpAndSettle();
    final anterior = tester.widget<ChoferShell>(find.byType(ChoferShell));
    final consultas = transporte.consultas.length;
    await _montar(tester, transporte);
    await tester.pumpAndSettle();
    final actual = tester.widget<ChoferShell>(find.byType(ChoferShell));
    expect(
      {
        'listadoEstable': actual.cargarViajes == anterior.cargarViajes,
        'detalleEstable': actual.cargarDetalle == anterior.cargarDetalle,
        'consultasAdicionales': transporte.consultas.length - consultas,
      },
      {
        'listadoEstable': true,
        'detalleEstable': true,
        'consultasAdicionales': 0,
      },
    );
  });
}
