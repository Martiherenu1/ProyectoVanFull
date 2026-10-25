import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/admin/crear_viaje_admin_screen.dart';
import 'package:frontend/screens/admin/viajes_dia_admin_screen.dart';
import 'package:frontend/screens/chofer/chofer_shell.dart';
import 'package:http/http.dart' as http;

final class _TransporteControlado extends http.BaseClient {
  _TransporteControlado({
    this.rol = 'administrador',
    this.estadoViajes = 200,
    this.estadoCreacion = 201,
    this.estadoViajesChofer = 200,
    this.estadoDetalleChofer = 200,
    this.incluirViajeChofer = false,
    this.primerListado,
  });

  final String rol;
  final int estadoViajes;
  final int estadoCreacion;
  final int estadoViajesChofer;
  final int estadoDetalleChofer;
  final bool incluirViajeChofer;
  final Completer<http.StreamedResponse>? primerListado;
  final List<http.BaseRequest> pedidos = [];
  int cierres = 0;
  int logins = 0;
  int listadosAdmin = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    pedidos.add(request);
    final path = request.url.path;
    if (path.endsWith('/auth/login')) {
      logins++;
      return _json(200, {
        'access_token': 'token-$logins',
        'token_type': 'bearer',
        'roles': [rol],
      });
    }
    if (path.endsWith('/auth/logout')) {
      return http.StreamedResponse(const Stream.empty(), 204);
    }
    if (path.endsWith('/choferes/me/viajes/41')) {
      if (estadoDetalleChofer == 403) return _sinPermiso();
      return _json(200, const {});
    }
    if (path.endsWith('/choferes/me/viajes')) {
      if (estadoViajesChofer == 403) return _sinPermiso();
      return _json(200, incluirViajeChofer ? [_viajeChofer] : const []);
    }
    if (path.endsWith('/viajes')) {
      if (request.method == 'POST') {
        if (estadoCreacion == 403) return _sinPermiso();
        return _json(201, const {});
      }
      listadosAdmin++;
      if (listadosAdmin == 1 && primerListado != null) {
        return primerListado!.future;
      }
      if (estadoViajes == 403) {
        return _sinPermiso();
      }
      return _json(200, const []);
    }
    return _json(404, {
      'error': {'codigo': 'NO_ENCONTRADO', 'mensaje': 'No encontrado'},
    });
  }

  http.StreamedResponse _json(int estado, Object cuerpo) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(cuerpo))),
        estado,
        headers: const {'content-type': 'application/json'},
      );

  http.StreamedResponse _sinPermiso() => _json(403, {
    'error': {'codigo': 'SIN_PERMISO', 'mensaje': 'Acceso denegado'},
  });

  static const _viajeChofer = {
    'id_viaje': 41,
    'id_servicio': 2,
    'id_recorrido': 3,
    'id_vehiculo': 4,
    'id_chofer': 5,
    'fecha': '2026-10-30',
    'horario': '07:30',
    'sentido': 'IDA',
    'estado': 'programado',
  };

  @override
  void close() {
    cierres++;
    super.close();
  }
}

Future<void> _login(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'admin@vanfull.test');
  await tester.enterText(find.byType(TextField).at(1), 'clave');
  await tester.tap(find.text('Ingresar'));
  await tester.pumpAndSettle();
}

Future<void> _completarCreacion(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('id-servicio')), '1');
  await tester.enterText(find.byKey(const Key('id-recorrido')), '2');
  await tester.enterText(find.byKey(const Key('fecha')), '2026-10-30');
  await tester.tap(find.byKey(const Key('sentido')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ida').last);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('crear-viaje')));
  await tester.tap(find.byKey(const Key('crear-viaje')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'administración reutiliza un transporte, permite cambiar de cuenta y lo cierra al desmontar',
    (tester) async {
      final transporte = _TransporteControlado();
      var creaciones = 0;
      await tester.pumpWidget(
        VanFullBootstrap(
          apiBaseUrl: 'https://vanfull.test/api/',
          crearTransporte: () {
            creaciones++;
            return transporte;
          },
        ),
      );

      await _login(tester);
      expect(find.byType(ViajesDiaAdminScreen), findsOneWidget);
      expect(find.byKey(const Key('admin-crear-viaje')), findsOneWidget);
      expect(
        transporte.pedidos
            .firstWhere((pedido) => pedido.url.path.endsWith('/auth/login'))
            .headers
            .containsKey('authorization'),
        isFalse,
      );
      expect(
        transporte.pedidos
            .singleWhere((pedido) => pedido.url.path.endsWith('/viajes'))
            .headers['authorization'],
        'Bearer token-1',
      );

      await tester.tap(find.byKey(const Key('admin-crear-viaje')));
      await tester.pumpAndSettle();
      expect(find.byType(CrearViajeAdminScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin-salir')));
      await tester.pumpAndSettle();
      expect(find.text('Ingresar'), findsOneWidget);
      expect(transporte.cierres, 0);
      expect(
        transporte.pedidos
            .singleWhere((pedido) => pedido.url.path.endsWith('/auth/logout'))
            .headers['authorization'],
        'Bearer token-1',
      );

      await _login(tester);
      expect(find.byType(ViajesDiaAdminScreen), findsOneWidget);
      expect(transporte.logins, 2);
      expect(creaciones, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(transporte.cierres, 1);
    },
  );

  testWidgets('el rol chofer recibe el shell existente mediante la sesión', (
    tester,
  ) async {
    final transporte = _TransporteControlado(rol: 'chofer');
    await tester.pumpWidget(
      VanFullBootstrap(
        apiBaseUrl: 'https://vanfull.test/api/',
        crearTransporte: () => transporte,
      ),
    );

    await _login(tester);

    expect(find.byType(ChoferShell), findsOneWidget);
    expect(
      transporte.pedidos.any(
        (pedido) => pedido.url.path.endsWith('/choferes/me/viajes'),
      ),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('403 muestra acceso denegado y conserva la sesión', (
    tester,
  ) async {
    final transporte = _TransporteControlado(estadoViajes: 403);
    await tester.pumpWidget(
      VanFullBootstrap(
        apiBaseUrl: 'https://vanfull.test/api/',
        crearTransporte: () => transporte,
      ),
    );

    await _login(tester);

    expect(find.byKey(const Key('admin-acceso-denegado')), findsOneWidget);
    expect(find.text('Acceso denegado.'), findsOneWidget);
    expect(find.text('Ingresar'), findsNothing);
    expect(find.byType(ViajesDiaAdminScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('403 al crear retira toda la entrada administrativa', (
    tester,
  ) async {
    final transporte = _TransporteControlado(estadoCreacion: 403);
    await tester.pumpWidget(
      VanFullBootstrap(
        apiBaseUrl: 'https://vanfull.test/api/',
        crearTransporte: () => transporte,
      ),
    );

    await _login(tester);
    await tester.tap(find.byKey(const Key('admin-crear-viaje')));
    await tester.pumpAndSettle();
    await _completarCreacion(tester);

    expect(find.byKey(const Key('admin-acceso-denegado')), findsOneWidget);
    expect(find.byType(CrearViajeAdminScreen), findsNothing);
    expect(find.byType(ViajesDiaAdminScreen), findsNothing);
    expect(find.text('Ingresar'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    '403 en listado de chofer retira el contenido y conserva sesión',
    (tester) async {
      final transporte = _TransporteControlado(
        rol: 'chofer',
        estadoViajesChofer: 403,
      );
      await tester.pumpWidget(
        VanFullBootstrap(
          apiBaseUrl: 'https://vanfull.test/api/',
          crearTransporte: () => transporte,
        ),
      );

      await _login(tester);

      expect(find.byKey(const Key('chofer-acceso-denegado')), findsOneWidget);
      expect(find.byType(ChoferShell), findsNothing);
      expect(find.text('Ingresar'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('403 en detalle de chofer retira listado y detalle', (
    tester,
  ) async {
    final transporte = _TransporteControlado(
      rol: 'chofer',
      incluirViajeChofer: true,
      estadoDetalleChofer: 403,
    );
    await tester.pumpWidget(
      VanFullBootstrap(
        apiBaseUrl: 'https://vanfull.test/api/',
        crearTransporte: () => transporte,
      ),
    );

    await _login(tester);
    await tester.tap(find.byKey(const Key('viaje-41')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chofer-acceso-denegado')), findsOneWidget);
    expect(find.byType(ChoferShell), findsNothing);
    expect(find.text('Detalle del viaje'), findsNothing);
    expect(find.text('Ingresar'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('una respuesta de la cuenta anterior no llega a la nueva', (
    tester,
  ) async {
    final listadoAnterior = Completer<http.StreamedResponse>();
    final transporte = _TransporteControlado(primerListado: listadoAnterior);
    await tester.pumpWidget(
      VanFullBootstrap(
        apiBaseUrl: 'https://vanfull.test/api/',
        crearTransporte: () => transporte,
      ),
    );

    await tester.enterText(
      find.byType(TextField).at(0),
      'primero@vanfull.test',
    );
    await tester.enterText(find.byType(TextField).at(1), 'clave');
    await tester.tap(find.text('Ingresar'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('admin-salir')), findsOneWidget);

    await tester.tap(find.byKey(const Key('admin-salir')));
    await tester.pumpAndSettle();
    await _login(tester);
    expect(
      find.text('No hay viajes registrados para esta fecha.'),
      findsOneWidget,
    );

    listadoAnterior.complete(
      transporte._json(200, [
        {
          'id_viaje': 99,
          'id_servicio': 1,
          'id_recorrido': 1,
          'fecha': '2026-10-30',
          'sentido': 'IDA',
          'estado': 'programado',
        },
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('99'), findsNothing);
    expect(
      find.text('No hay viajes registrados para esta fecha.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('un 403 tardío de la cuenta anterior no bloquea la nueva', (
    tester,
  ) async {
    final listadoAnterior = Completer<http.StreamedResponse>();
    final transporte = _TransporteControlado(primerListado: listadoAnterior);
    await tester.pumpWidget(
      VanFullBootstrap(
        apiBaseUrl: 'https://vanfull.test/api/',
        crearTransporte: () => transporte,
      ),
    );

    await tester.enterText(
      find.byType(TextField).at(0),
      'primero@vanfull.test',
    );
    await tester.enterText(find.byType(TextField).at(1), 'clave');
    await tester.tap(find.text('Ingresar'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('admin-salir')));
    await tester.pumpAndSettle();
    await _login(tester);

    listadoAnterior.complete(transporte._sinPermiso());
    await tester.pumpAndSettle();

    expect(find.byType(ViajesDiaAdminScreen), findsOneWidget);
    expect(find.byKey(const Key('admin-acceso-denegado')), findsNothing);
    expect(find.text('Ingresar'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
