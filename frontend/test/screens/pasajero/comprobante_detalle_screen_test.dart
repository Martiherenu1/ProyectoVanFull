import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/pasajero/comprobante_propio.dart';
import 'package:frontend/screens/pasajero/comprobante_detalle_screen.dart';

ComprobantePropio recibo() => ComprobantePropio.fromJson({
  'id_comprobante': 9,
  'tipo': 'RECIBO',
  'id_pago': 5,
  'id_contratacion': null,
  'id_movimiento_cuenta': null,
  'fecha_hora': '2026-10-24T18:05:00',
  'importe': 11600,
  'medio_pago': 'TRANSFERENCIA',
});

ComprobantePropio notaDeCredito() => ComprobantePropio.fromJson({
  'id_comprobante': 10,
  'tipo': 'NOTA_DE_CREDITO',
  'id_pago': null,
  'id_contratacion': null,
  'id_movimiento_cuenta': 3,
  'fecha_hora': '2026-10-25T09:00:00',
  'importe': 2900,
  'medio_pago': null,
});

ComprobantePropio facturaSinDatos() => ComprobantePropio.fromJson({
  'id_comprobante': 11,
  'tipo': 'FACTURA',
  'id_pago': null,
  'id_contratacion': 8,
  'id_movimiento_cuenta': null,
  'fecha_hora': null,
  'importe': null,
  'medio_pago': null,
});

Future<void> mostrar(WidgetTester tester, CargarComprobante cargar) =>
    tester.pumpWidget(
      MaterialApp(
        home: ComprobanteDetalleScreen(
          idComprobante: 9,
          cargarComprobante: cargar,
        ),
      ),
    );

String textoDe(WidgetTester tester, String clave) =>
    tester.widget<Text>(find.byKey(ValueKey(clave))).data!;

void main() {
  testWidgets('pide el comprobante por su id y muestra un esqueleto', (
    tester,
  ) async {
    final espera = Completer<ComprobantePropio>();
    final pedidos = <int>[];
    await mostrar(tester, (id) {
      pedidos.add(id);
      return espera.future;
    });

    expect(pedidos, [9]);
    expect(find.bySemanticsLabel('Cargando el comprobante'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('un recibo muestra importe, fecha, medio y el pago de origen', (
    tester,
  ) async {
    await mostrar(tester, (_) async => recibo());
    await tester.pump();

    expect(find.text('RECIBO'), findsOneWidget);
    expect(textoDe(tester, 'importe-comprobante'), r'$ 11.600,00');
    expect(textoDe(tester, 'fecha-comprobante'), '24/10/2026 18:05');
    expect(textoDe(tester, 'medio-comprobante'), 'Transferencia');
    expect(textoDe(tester, 'origen-comprobante'), 'Pago N.º 5');
    expect(textoDe(tester, 'referencia-comprobante'), '9');
  });

  testWidgets('una nota no muestra medio y su origen es el movimiento', (
    tester,
  ) async {
    await mostrar(tester, (_) async => notaDeCredito());
    await tester.pump();

    expect(find.text('NOTA DE CRÉDITO'), findsOneWidget);
    expect(find.byKey(const ValueKey('medio-comprobante')), findsNothing);
    expect(textoDe(tester, 'origen-comprobante'), 'Movimiento de cuenta N.º 3');
  });

  testWidgets('una factura sin fecha ni importe lo dice sin inventar', (
    tester,
  ) async {
    await mostrar(tester, (_) async => facturaSinDatos());
    await tester.pump();

    expect(textoDe(tester, 'importe-comprobante'), 'Sin importe');
    expect(textoDe(tester, 'fecha-comprobante'), 'Sin fecha');
    expect(textoDe(tester, 'origen-comprobante'), 'Contratación N.º 8');
  });

  testWidgets('el 404 COMPROBANTE_NO_ENCONTRADO no confirma si existe (A2)', (
    tester,
  ) async {
    await mostrar(
      tester,
      (_) async => throw const ApiException(
        statusCode: 404,
        codigo: 'COMPROBANTE_NO_ENCONTRADO',
        mensaje: 'x',
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('comprobante-no-disponible')),
      findsOneWidget,
    );
    expect(find.text('Este comprobante no está disponible.'), findsOneWidget);
    expect(find.byKey(const ValueKey('reintentar-comprobante')), findsNothing);
  });

  testWidgets('otro 404 o una falla de red ofrece reintentar', (tester) async {
    var falla = true;
    await mostrar(tester, (_) async {
      if (falla) {
        throw const ApiException(
          statusCode: 404,
          codigo: 'NO_ENCONTRADO',
          mensaje: 'x',
        );
      }
      return recibo();
    });
    await tester.pump();

    expect(
      find.byKey(const ValueKey('comprobante-no-disponible')),
      findsNothing,
    );
    expect(find.textContaining('No pudimos cargar'), findsOneWidget);

    falla = false;
    await tester.tap(find.byKey(const ValueKey('reintentar-comprobante')));
    await tester.pump();
    await tester.pump();
    expect(textoDe(tester, 'importe-comprobante'), r'$ 11.600,00');
  });
}
