import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/pasajero/pago.dart';
import 'package:frontend/screens/pasajero/pago_screen.dart';

Pago pago({double importe = 5800, String estado = 'PENDIENTE'}) =>
    Pago.fromJson({
      'id_pago': 5,
      'id_cliente': 1,
      'importe': importe,
      'medio_pago': 'EFECTIVO',
      'estado': estado,
      'fecha_hora': '2026-10-24T18:00:00Z',
    });

ApiException error(int estado, String codigo) => ApiException(
  statusCode: estado,
  codigo: codigo,
  mensaje: 'Mensaje de $codigo',
);

Future<void> mostrar(
  WidgetTester tester, {
  RegistrarPago? registrar,
  ValueChanged<Pago>? terminar,
  double? saldo,
}) => tester.pumpWidget(
  MaterialApp(
    home: PagoScreen(
      saldo: saldo,
      registrarPago: registrar ?? (importe, medio) async => pago(),
      onTerminar: terminar ?? (_) {},
    ),
  ),
);

ElevatedButton boton(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byKey(const ValueKey('registrar-pago')));

String textoDe(WidgetTester tester, String clave) =>
    tester.widget<Text>(find.byKey(ValueKey(clave))).data!;

void main() {
  testWidgets('sugiere el saldo y no habilita sin medio de pago', (
    tester,
  ) async {
    await mostrar(tester, saldo: 11600.5);
    expect(find.text('11600,50'), findsOneWidget);
    expect(boton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('medio-EFECTIVO')));
    await tester.pump();
    expect(boton(tester).onPressed, isNotNull);
  });

  testWidgets('sin deuda el importe arranca vacío', (tester) async {
    await mostrar(tester, saldo: 0);
    final campo = tester.widget<TextField>(
      find.byKey(const ValueKey('importe-pago')),
    );
    expect(campo.controller!.text, isEmpty);
  });

  testWidgets('un importe inválido o cero no se puede registrar', (
    tester,
  ) async {
    await mostrar(tester);
    await tester.tap(find.byKey(const ValueKey('medio-EFECTIVO')));
    for (final texto in ['abc', '0', '10,555']) {
      await tester.enterText(find.byKey(const ValueKey('importe-pago')), texto);
      await tester.pump();
      expect(boton(tester).onPressed, isNull, reason: texto);
    }
    expect(find.textContaining('mayor a cero'), findsOneWidget);
  });

  testWidgets('registra importe y medio y muestra el pago pendiente', (
    tester,
  ) async {
    double? importeEnviado;
    MedioPago? medioEnviado;
    Pago? terminado;
    await mostrar(
      tester,
      registrar: (importe, medio) async {
        importeEnviado = importe;
        medioEnviado = medio;
        return pago(importe: importe);
      },
      terminar: (p) => terminado = p,
    );

    await tester.enterText(find.byKey(const ValueKey('importe-pago')), '5.800');
    await tester.tap(find.byKey(const ValueKey('medio-BILLETERA')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('registrar-pago')));
    await tester.pumpAndSettle();

    expect(importeEnviado, 5800);
    expect(medioEnviado, MedioPago.billetera);
    expect(textoDe(tester, 'importe-registrado'), r'$ 5.800,00');
    expect(textoDe(tester, 'estado-pago'), 'Pago pendiente');

    await tester.tap(find.byKey(const ValueKey('terminar-pago')));
    expect(terminado?.idPago, 5);
  });

  testWidgets('mientras registra no se puede volver a tocar', (tester) async {
    final respuesta = Completer<Pago>();
    var llamadas = 0;
    await mostrar(
      tester,
      saldo: 100,
      registrar: (_, _) {
        llamadas++;
        return respuesta.future;
      },
    );
    await tester.tap(find.byKey(const ValueKey('medio-EFECTIVO')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('registrar-pago')));
    await tester.pump();

    expect(find.text('Registrando…'), findsOneWidget);
    expect(boton(tester).onPressed, isNull);
    respuesta.complete(pago());
    await tester.pumpAndSettle();
    expect(llamadas, 1);
  });

  testWidgets('sin cuenta corriente el rechazo es definitivo', (tester) async {
    for (final codigo in [
      'CLIENTE_NO_ENCONTRADO',
      'CUENTA_CORRIENTE_NO_ENCONTRADA',
    ]) {
      await mostrar(
        tester,
        saldo: 100,
        registrar: (_, _) async => throw error(404, codigo),
      );
      await tester.tap(find.byKey(const ValueKey('medio-EFECTIVO')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('registrar-pago')));
      await tester.pumpAndSettle();

      expect(
        textoDe(tester, 'aviso-pago'),
        contains('todavía no admite pagos'),
      );
      expect(boton(tester).onPressed, isNull);
      // Recrea la pantalla para el siguiente código.
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('un 400 muestra el motivo; una falla de red permite reintentar', (
    tester,
  ) async {
    Object falla = error(400, 'VALIDACION');
    await mostrar(tester, saldo: 100, registrar: (_, _) async => throw falla);
    await tester.tap(find.byKey(const ValueKey('medio-EFECTIVO')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('registrar-pago')));
    await tester.pumpAndSettle();
    expect(textoDe(tester, 'aviso-pago'), 'Mensaje de VALIDACION');
    expect(boton(tester).onPressed, isNotNull);

    falla = Exception('sin red');
    await tester.tap(find.byKey(const ValueKey('registrar-pago')));
    await tester.pumpAndSettle();
    expect(textoDe(tester, 'aviso-pago'), contains('Volvé a intentar'));
    expect(boton(tester).onPressed, isNotNull);
  });
}
