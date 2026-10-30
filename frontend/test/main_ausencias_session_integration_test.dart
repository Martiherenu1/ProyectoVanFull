import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/models/pasajero/deuda.dart';
import 'package:frontend/screens/pasajero/accion_informar_ausencia.dart';
import 'package:frontend/screens/pasajero/mis_reservas_screen.dart';
import 'package:frontend/screens/pasajero/pasajero_shell.dart';
import 'package:frontend/screens/pasajero/pago_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> reserva(int id, String estado) => {
  'id_reserva': id,
  'id_viaje': 11 + id,
  'id_pasajero': 7,
  'id_recorrido': 3,
  'orden_parada': 1,
  'fecha': '2026-10-30',
  'horario': '06:15',
  'sentido': 'IDA',
  'estado': estado,
};
http.Response json(Object cuerpo, [int status = 200]) => http.Response(
  jsonEncode(cuerpo),
  status,
  headers: {'content-type': 'application/json'},
);
http.Response rechazo(int status) => json({
  'error': {'codigo': 'RECHAZO', 'mensaje': 'Motivo contractual'},
}, status);

class Servidor {
  final pedidos = <http.Request>[];
  int logins = 0;
  int reservas = 0;
  int deudas = 0;
  int ausencias = 0;
  int pagos = 0;
  int checkouts = 0;
  int consultasPago = 0;
  Future<http.Response> Function()? ausencia;
  List<Map<String, Object?>> filas = [reserva(1, 'consolidada')];
  Map<String, Object?> get pago => {
    'id_pago': 5,
    'importe': 100,
    'medio_pago': 'MERCADO_PAGO',
    'estado': 'PENDIENTE',
  };
  late final cliente = MockClient((r) async {
    pedidos.add(r);
    switch (r.url.path) {
      case '/api/auth/login':
        return json({
          'access_token': 'token-${++logins}',
          'token_type': 'bearer',
          'roles': ['pasajero'],
        });
      case '/api/auth/logout':
        return http.Response('', 204);
      case '/api/servicios/disponibilidad':
        return json([]);
      case '/api/pasajeros/me/reservas':
        reservas++;
        return json(filas);
      case '/api/pasajeros/me/deuda':
        deudas++;
        return json({'saldo': 100, 'estado': 'con_deuda'});
      case '/api/pasajeros/me':
        return json({
          'id_persona': 7,
          'nombre': 'Ana',
          'apellido': 'Prueba',
          'dni': '30111222',
          'estado_habilitacion': 'habilitado',
        });
      case '/api/ausencias':
        expect(r.method, 'POST');
        expect(jsonDecode(r.body), {'id_viaje': 12});
        expect(r.headers['authorization'], 'Bearer token-$logins');
        ausencias++;
        return ausencia == null
            ? json({'id_ausencia': 1, 'id_pasajero': 7, 'id_viaje': 12}, 201)
            : await ausencia!();
      case '/api/pagos':
        pagos++;
        return json({...pago, 'medio_pago': 'EFECTIVO'}, 201);
      case '/api/pagos/mercadopago/checkout':
        checkouts++;
        return json({
          'pago': pago,
          'estado_checkout': 'LISTO',
          'checkout_url': 'https://sandbox.mercadopago.com.ar/checkout/v1/redirect?pref_id=falsa-5',
        });
      case '/api/pagos/5':
        consultasPago++;
        return json(pago);
    }
    throw StateError('HTTP inesperado ${r.method} ${r.url}');
  });
}

Future<void> login(WidgetTester t) async {
  await t.enterText(find.byType(TextField).at(0), 'pasajero@test');
  await t.enterText(find.byType(TextField).at(1), 'clave');
  await t.tap(find.text('Ingresar'));
  await t.pumpAndSettle();
}

Future<void> montar(
  WidgetTester t,
  Servidor s, {
  bool checkout = false,
  Future<bool> Function(Uri)? abrir,
}) async {
  t.view.physicalSize = const Size(900, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    VanFullBootstrap(
      apiBaseUrl: 'https://vanfull.test/api/',
      crearTransporte: () => s.cliente,
      checkoutEnabled: checkout,
      abrirCheckout: abrir,
    ),
  );
  await login(t);
  await t.tap(find.text('Mis reservas').last);
  await t.pumpAndSettle();
}

Future<void> abrir(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('reserva-1')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('informar-ausencia')));
  await t.pumpAndSettle();
}

Future<void> confirmar(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('confirmar-ausencia')));
  await t.pumpAndSettle();
}

MisReservasScreen pantalla(WidgetTester t) =>
    t.widget(find.byType(MisReservasScreen, skipOffstage: false));
PasajeroShell shell(WidgetTester t) =>
    t.widget(find.byType(PasajeroShell, skipOffstage: false));

void main() {
  testWidgets(
    'solo consolidada ofrece ausencia; cancelar confirmación no envía',
    (t) async {
      final s = Servidor()
        ..filas = [
          reserva(1, 'consolidada'),
          reserva(2, 'provisional'),
          reserva(3, 'cancelada'),
        ];
      await montar(t, s);
      for (final id in [2, 3]) {
        await t.tap(find.byKey(ValueKey('reserva-$id')));
        await t.pumpAndSettle();
        expect(find.byType(AccionInformarAusencia), findsNothing);
      }
      await abrir(t);
      await t.tap(find.byKey(const ValueKey('no-informar-ausencia')));
      await t.pumpAndSettle();
      expect(s.ausencias, 0);
    },
  );
  for (final status in [200, 201, 400, 401, 403, 404, 409, 500]) {
    testWidgets('composición HTTP $status y resultado transitorio', (t) async {
      final s = Servidor();
      s.ausencia = () async => status < 300
          ? json({'id_ausencia': 1, 'id_pasajero': 7, 'id_viaje': 12}, status)
          : rechazo(status);
      await montar(t, s);
      await abrir(t);
      await confirmar(t);
      expect(s.ausencias, 1);
      if (status == 401) {
        expect(find.text('Ingresar'), findsOneWidget);
        return;
      }
      expect(find.text('Ingresar'), findsNothing);
      if (status < 300) {
        expect(
          find.text('Tu aviso de ausencia está registrado.'),
          findsOneWidget,
        );
      } else if (status == 500) {
        expect(
          find.textContaining(
            'No pudimos confirmar si el aviso quedó registrado',
          ),
          findsOneWidget,
        );
      } else {
        expect(find.text('Motivo contractual'), findsOneWidget);
      }
      await t.pump(const Duration(seconds: 30));
      expect(s.ausencias, 1);
    });
  }
  testWidgets('cuerpo inválido y red: solo otra confirmación reintenta', (
    t,
  ) async {
    final s = Servidor();
    s.ausencia = () async {
      if (s.ausencias == 1) return json({});
      if (s.ausencias == 2) throw http.ClientException('red');
      return json({'id_ausencia': 1, 'id_pasajero': 7, 'id_viaje': 12});
    };
    await montar(t, s);
    await abrir(t);
    await confirmar(t);
    for (final n in [1, 2]) {
      expect(
        find.textContaining(
          'No pudimos confirmar si el aviso quedó registrado',
        ),
        findsOneWidget,
      );
      await t.pump(const Duration(seconds: 30));
      expect(s.ausencias, n);
      await t.tap(find.byKey(const ValueKey('informar-ausencia')));
      await t.pumpAndSettle();
      expect(s.ausencias, n);
      await confirmar(t);
    }
    expect(s.ausencias, 3);
    expect(find.text('Tu aviso de ausencia está registrado.'), findsOneWidget);
  });
  testWidgets(
    'salir de pestaña invalida confirmación conservando estado de Mis reservas',
    (t) async {
      final s = Servidor();
      await montar(t, s);
      await abrir(t);
      final estado = t.state(
        find.byType(MisReservasScreen, skipOffstage: false),
      );
      final listado = s.reservas;
      final saldo = s.deudas;
      final confirmarAnterior = t
          .widget<TextButton>(find.byKey(const ValueKey('confirmar-ausencia')))
          .onPressed!;
      t
          .widget<NavigationBar>(find.byType(NavigationBar))
          .onDestinationSelected!(0);
      confirmarAnterior(); // Antes del siguiente frame, la guardia ya debe invalidar.
      await t.pumpAndSettle();
      expect(s.ausencias, 0);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        identical(
          estado,
          t.state(find.byType(MisReservasScreen, skipOffstage: false)),
        ),
        isTrue,
      );
      expect(s.reservas, listado);
      expect(s.deudas, saldo);
      await t.tap(find.text('Mis reservas').last);
      await t.pumpAndSettle();
      expect(
        identical(estado, t.state(find.byType(MisReservasScreen))),
        isTrue,
      );
      expect(find.byKey(const ValueKey('resultado-ausencia')), findsNothing);
      expect(s.ausencias, 0);
    },
  );
  testWidgets(
    'abrir ruta Pago retira solo confirmación; volver no reconstruye aviso',
    (t) async {
      final s = Servidor();
      await montar(t, s);
      await abrir(t);
      final estado = t.state(
        find.byType(MisReservasScreen, skipOffstage: false),
      );
      final listado = s.reservas;
      pantalla(t).onRegistrarPago!(
        const Deuda(saldo: 100, estado: EstadoDeuda.conDeuda),
      );
      await t.pumpAndSettle();
      expect(find.byType(PagoScreen), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(s.ausencias, 0);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(
        identical(estado, t.state(find.byType(MisReservasScreen))),
        isTrue,
      );
      expect(s.reservas, listado);
      expect(find.byKey(const ValueKey('resultado-ausencia')), findsNothing);
      expect(find.byKey(const ValueKey('informar-ausencia')), findsOneWidget);
    },
  );
  for (final status in [200, 401, 403, 500]) {
    testWidgets('respuesta tardía $status de A no afecta B', (t) async {
      final s = Servidor();
      final pendiente = Completer<http.Response>();
      s.ausencia = () => pendiente.future;
      await montar(t, s);
      await abrir(t);
      final viejo = shell(t).informarAusencia!;
      await confirmar(t);
      shell(t).onSalir();
      await t.pumpAndSettle();
      await login(t);
      await t.tap(find.text('Mis reservas').last);
      await t.pumpAndSettle();
      pendiente.complete(
        status == 200
            ? json({'id_ausencia': 1, 'id_pasajero': 7, 'id_viaje': 12})
            : rechazo(status),
      );
      await t.pumpAndSettle();
      expect(s.logins, 2);
      expect(find.text('Ingresar'), findsNothing);
      expect(find.byKey(const ValueKey('resultado-ausencia')), findsNothing);
      await expectLater(viejo(12), throwsStateError);
      expect(s.ausencias, 1);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('cambio de cuenta con confirmación abierta no envía', (t) async {
    final s = Servidor();
    await montar(t, s);
    await abrir(t);
    shell(t).onSalir();
    await t.pumpAndSettle();
    await login(t);
    expect(find.byType(AlertDialog), findsNothing);
    expect(s.ausencias, 0);
  });
  testWidgets('respuesta tras salir de pestaña no reaparece al volver', (
    t,
  ) async {
    final s = Servidor();
    final c = Completer<http.Response>();
    s.ausencia = () => c.future;
    await montar(t, s);
    await abrir(t);
    await confirmar(t);
    await t.tap(find.text('Buscar').last);
    await t.pumpAndSettle();
    c.complete(json({'id_ausencia': 1, 'id_pasajero': 7, 'id_viaje': 12}));
    await t.pumpAndSettle();
    await t.tap(find.text('Mis reservas').last);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('resultado-ausencia')), findsNothing);
    expect(s.ausencias, 1);
  });
  for (final checkout in [false, true]) {
    testWidgets(
      'Checkout flag $checkout conserva pago, retorno y recarga simulados',
      (t) async {
        final s = Servidor();
        var aperturas = 0;
        await montar(
          t,
          s,
          checkout: checkout,
          abrir: (_) async {
            aperturas++;
            return true;
          },
        );
        final estado = t.state(find.byType(MisReservasScreen));
        final listado = s.reservas;
        final saldo = s.deudas;
        await t.tap(find.byKey(const ValueKey('ir-a-pago')));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('medio-MERCADO_PAGO')),
          checkout ? findsOneWidget : findsNothing,
        );
        if (checkout) {
          await t.tap(find.byKey(const ValueKey('medio-MERCADO_PAGO')));
          await t.pumpAndSettle();
          await t.tap(find.byKey(const ValueKey('registrar-pago')));
          await t.pumpAndSettle();
          expect(s.checkouts, 1);
          expect(s.pagos, 0);
          await t.tap(find.byKey(const Key('abrir-checkout')));
          await t.pumpAndSettle();
          expect(aperturas, 1);
          await t.tap(find.byKey(const Key('consultar-checkout')));
          await t.pumpAndSettle();
          expect(s.consultasPago, 1);
          await t.tap(find.byKey(const Key('volver-checkout')));
          await t.pumpAndSettle();
          await t.pageBack();
          await t.pumpAndSettle();
        } else {
          await t.tap(find.byKey(const ValueKey('medio-EFECTIVO')));
          await t.pumpAndSettle();
          await t.tap(find.byKey(const ValueKey('registrar-pago')));
          await t.pumpAndSettle();
          expect(s.pagos, 1);
          expect(s.checkouts, 0);
          await t.tap(find.byKey(const ValueKey('terminar-pago')));
          await t.pumpAndSettle();
        }
        expect(
          identical(estado, t.state(find.byType(MisReservasScreen))),
          isTrue,
        );
        expect(s.reservas, greaterThan(listado));
        expect(s.deudas, greaterThan(saldo));
        expect(s.ausencias, 0);
        expect(find.byType(PagoScreen), findsNothing);
      },
    );
  }
}
