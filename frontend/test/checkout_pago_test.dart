import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/adapters/abrir_checkout.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/models/pasajero/pago.dart';
import 'package:frontend/screens/pasajero/checkout_pago_screen.dart';
import 'package:frontend/screens/pasajero/pago_screen.dart';
import 'package:frontend/services/checkout_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:url_launcher/url_launcher.dart';

const enlace =
    'https://sandbox.mercadopago.com.ar/checkout/v1/redirect?pref_id=44-falsa';
const clave = 'b46decdc-5b93-4818-aa91-795b7a7de7c0';
Pago pago([EstadoPago estado = EstadoPago.pendiente]) =>
    Pago(idPago: 5, importe: 10000, medioPago: 'MERCADO_PAGO', estado: estado);
InicioCheckout inicio([String estado = 'LISTO']) => InicioCheckout(
  pago: pago(),
  estado: estado,
  url: estado == 'LISTO' ? Uri.parse(enlace) : null,
);

Future<void> mostrar(
  WidgetTester tester, {
  IniciarCheckout? iniciar,
  ConsultarPagoPropio? consultar,
  AbrirCheckout? abrir,
  bool Function()? vigente,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CheckoutPagoScreen(
        importe: 10000,
        clave: clave,
        iniciar: iniciar ?? (a, c) async => inicio(),
        consultar: consultar ?? (id) async => pago(),
        abrir: abrir ?? (_) async => true,
        contextoVigente: vigente ?? () => true,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test(
    'adaptador usa navegador externo y nueva pestaña Web, sin abrir nada real',
    () async {
      var llamadas = 0;
      expect(
        await abrirCheckoutExterno(
          Uri.parse(enlace),
          lanzar: (uri, modo, ventana) async {
            llamadas++;
            expect(modo, LaunchMode.externalApplication);
            expect(ventana, '_blank');
            return true;
          },
        ),
        isTrue,
      );
      expect(llamadas, 1);
    },
  );

  test('timeout HTTP no se interpreta como rechazo del pago', () async {
    final pendiente = Completer<http.Response>();
    final api = CheckoutApi(
      HttpApiClient(
        baseUri: Uri.parse('https://vanfull.test/api/'),
        transport: MockClient((_) => pendiente.future),
      ),
      timeout: const Duration(milliseconds: 5),
    );
    await expectLater(
      api.iniciar(10000, clave),
      throwsA(isA<TimeoutException>()),
    );
    pendiente.complete(http.Response('{}', 503));
  });

  test('adaptador HTTP reutiliza sesión, contrato y consulta propia', () async {
    final llamadas = <String>[];
    final api = CheckoutApi(
      HttpApiClient(
        baseUri: Uri.parse('https://vanfull.test/api/'),
        accessTokenProvider: () => 'token-falso',
        transport: MockClient((r) async {
          expect(r.headers['authorization'], 'Bearer token-falso');
          llamadas.add('${r.method} ${r.url.path}');
          final datosPago = {
            'id_pago': 5,
            'importe': 10000,
            'medio_pago': 'MERCADO_PAGO',
            'estado': 'PENDIENTE',
          };
          if (r.method == 'POST') {
            expect(jsonDecode(r.body), {
              'importe': 10000,
              'medio_pago': 'MERCADO_PAGO',
              'clave_solicitud': clave,
            });
            return http.Response(
              jsonEncode({
                'pago': datosPago,
                'estado_checkout': 'LISTO',
                'checkout_url': enlace,
              }),
              200,
            );
          }
          return http.Response(jsonEncode(datosPago), 200);
        }),
      ),
    );
    expect((await api.iniciar(10000, clave)).url.toString(), enlace);
    expect((await api.consultar(5)).idPago, 5);
    expect(llamadas, [
      'POST /api/pagos/mercadopago/checkout',
      'GET /api/pagos/5',
    ]);
    expect(MedioPago.billetera.valorApi, isNot(MedioPago.mercadoPago.valorApi));
    expect(
      nuevaClaveCheckout(),
      matches(
        RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ),
      ),
    );
  });

  for (final status in [401, 403, 409, 500, 503]) {
    test('propaga HTTP $status sin declarar acreditación', () async {
      final api = CheckoutApi(
        HttpApiClient(
          baseUri: Uri.parse('https://vanfull.test/api/'),
          accessTokenProvider: () => 'token-falso',
          transport: MockClient(
            (_) async => http.Response(
              '{"error":{"codigo":"ERROR","mensaje":"Fallo controlado"}}',
              status,
            ),
          ),
        ),
      );
      await expectLater(
        api.iniciar(10000, clave),
        throwsA(isA<ApiException>()),
      );
    });
  }

  for (final url in [
    'http://sandbox.mercadopago.com.ar/?pref_id=a',
    'https://www.mercadopago.com.ar/?pref_id=a',
    'https://sandbox.mercadopago.com.ar.evil.test/?pref_id=a',
    'https://user@sandbox.mercadopago.com.ar/?pref_id=a',
    'https://sandbox.mercadopago.com.ar/?pref_id=a&pref_id=b',
    'https://sandbox.mercadopago.com.ar/?pref_id=a#approved',
    'https://sandbox.mercadopago.com.ar:444/?pref_id=a',
  ]) {
    test(
      'rechaza URL no autorizada $url',
      () => expect(() => validarUrlCheckout(url), throwsFormatException),
    );
  }

  for (final ancho in [320.0, 1440.0]) {
    testWidgets('apertura explícita y consulta backend a $ancho px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(ancho, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var aperturas = 0;
      await mostrar(
        tester,
        abrir: (url) async {
          expect(url.toString(), enlace);
          aperturas++;
          return true;
        },
        consultar: (_) async => pago(EstadoPago.confirmado),
      );
      expect(aperturas, 0);
      await tester.tap(find.byKey(const Key('abrir-checkout')));
      await tester.pumpAndSettle();
      expect(aperturas, 1);
      expect(find.textContaining('backend confirmó'), findsNothing);
      await tester.tap(find.byKey(const Key('consultar-checkout')));
      await tester.pumpAndSettle();
      expect(find.textContaining('backend confirmó'), findsOneWidget);
      expect(find.byKey(const Key('abrir-checkout')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('doble envío bloqueado y timeout conserva la clave', (
    tester,
  ) async {
    final pendiente = Completer<InicioCheckout>();
    final claves = <String>[];
    await mostrar(
      tester,
      iniciar: (a, c) {
        claves.add(c);
        return pendiente.future;
      },
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('reintentar-checkout')))
          .onPressed,
      isNull,
    );
    pendiente.completeError(TimeoutException('simulado'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reintentar-checkout')));
    await tester.pump();
    expect(claves, [clave, clave]);
    expect(find.textContaining('no repitas el pago'), findsOneWidget);
  });

  testWidgets('abandono no confirma y retorno móvil consulta sin POST nuevo', (
    tester,
  ) async {
    var inicios = 0;
    var consultas = 0;
    await mostrar(
      tester,
      iniciar: (a, c) async {
        inicios++;
        return inicio();
      },
      consultar: (_) async {
        consultas++;
        return pago();
      },
    );
    await tester.tap(find.byKey(const Key('abrir-checkout')));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(inicios, 1);
    expect(consultas, 1);
    expect(find.textContaining('backend confirmó'), findsNothing);
  });

  for (final cerrar in [false, true]) {
    testWidgets(
      'descarta inicio tardío al ${cerrar ? 'cerrar pantalla' : 'cambiar sesión'}',
      (tester) async {
        final pendiente = Completer<InicioCheckout>();
        var vigente = true;
        await mostrar(
          tester,
          iniciar: (a, c) => pendiente.future,
          vigente: () => vigente,
        );
        if (cerrar) {
          await tester.pumpWidget(
            const MaterialApp(home: Text('Otra pantalla')),
          );
        } else {
          vigente = false;
        }
        pendiente.complete(inicio());
        await tester.pump();
        expect(find.byKey(const Key('abrir-checkout')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('descarta consulta tardía y no abre con sesión vencida', (
    tester,
  ) async {
    final pendiente = Completer<Pago>();
    var vigente = true;
    var aperturas = 0;
    await mostrar(
      tester,
      consultar: (_) => pendiente.future,
      vigente: () => vigente,
      abrir: (_) async {
        aperturas++;
        return true;
      },
    );
    await tester.tap(find.byKey(const Key('consultar-checkout')));
    await tester.pump();
    vigente = false;
    pendiente.complete(pago(EstadoPago.confirmado));
    await tester.pump();
    expect(find.textContaining('backend confirmó'), findsNothing);
    expect(aperturas, 0);
  });

  testWidgets('navegación de registro usa checkout y no registro manual', (
    tester,
  ) async {
    var manuales = 0;
    var inicios = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PagoScreen(
          saldo: 10000,
          registrarPago: (a, m) async {
            manuales++;
            return pago();
          },
          onTerminar: (_) {},
          iniciarCheckout: (a, c) async {
            inicios++;
            return inicio();
          },
          consultarPago: (_) async => pago(),
          abrirCheckout: (_) async => true,
          contextoVigente: () => true,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('medio-MERCADO_PAGO')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('registrar-pago')));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutPagoScreen), findsOneWidget);
    expect(inicios, 1);
    expect(manuales, 0);
  });

  testWidgets(
    'cerrar y reabrir conserva solicitud; popup fallido no genera otro inicio',
    (tester) async {
      final claves = <String>[];
      var aperturas = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PagoScreen(
            saldo: 10000,
            registrarPago: (a, m) async =>
                throw StateError('No registrar manualmente'),
            onTerminar: (_) {},
            iniciarCheckout: (a, c) async {
              claves.add(c);
              return inicio();
            },
            consultarPago: (_) async => pago(),
            abrirCheckout: (_) async {
              aperturas++;
              return false;
            },
            contextoVigente: () => true,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('medio-MERCADO_PAGO')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('registrar-pago')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('abrir-checkout')));
      await tester.pumpAndSettle();
      expect(find.textContaining('navegador no pudo abrir'), findsOneWidget);
      expect(claves, hasLength(1));
      expect(aperturas, 1);
      await tester.tap(find.byKey(const Key('volver-checkout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('registrar-pago')));
      await tester.pumpAndSettle();
      expect(claves, hasLength(2));
      expect(claves[0], claves[1]);
    },
  );
}
