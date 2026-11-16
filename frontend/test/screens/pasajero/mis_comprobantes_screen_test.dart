import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pasajero/comprobante_propio.dart';
import 'package:frontend/screens/pasajero/mis_comprobantes_screen.dart';

ComprobantePropio recibo(int id) => ComprobantePropio.fromJson({
  'id_comprobante': id,
  'tipo': 'RECIBO',
  'id_pago': 50 + id,
  'id_contratacion': null,
  'id_movimiento_cuenta': null,
  'fecha_hora': '2026-10-24T18:05:00',
  'importe': 11600,
  'medio_pago': 'TRANSFERENCIA',
});

ComprobantePropio factura(int id) => ComprobantePropio.fromJson({
  'id_comprobante': id,
  'tipo': 'FACTURA',
  'id_pago': null,
  'id_contratacion': 8,
  'id_movimiento_cuenta': null,
  'fecha_hora': null,
  'importe': null,
  'medio_pago': null,
});

Future<void> mostrar(
  WidgetTester tester, {
  CargarComprobantes? cargar,
  ValueChanged<ComprobantePropio>? abrir,
}) => tester.pumpWidget(
  MaterialApp(
    home: MisComprobantesScreen(
      cargarComprobantes: cargar ?? () async => [recibo(1)],
      onAbrir: abrir ?? (_) {},
    ),
  ),
);

void main() {
  testWidgets('muestra un esqueleto mientras carga', (tester) async {
    final espera = Completer<List<ComprobantePropio>>();
    await mostrar(tester, cargar: () => espera.future);

    expect(find.bySemanticsLabel('Cargando comprobantes'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    espera.complete([recibo(1)]);
    await tester.pump();
    expect(find.bySemanticsLabel('Cargando comprobantes'), findsNothing);
  });

  testWidgets('lista tipo, fecha, medio e importe; lo que falta se dice', (
    tester,
  ) async {
    await mostrar(tester, cargar: () async => [recibo(1), factura(2)]);
    await tester.pump();

    expect(find.text('Recibo'), findsOneWidget);
    expect(find.text('24/10/2026 18:05 · Transferencia'), findsOneWidget);
    expect(find.text(r'$ 11.600,00'), findsOneWidget);

    expect(find.text('Factura'), findsOneWidget);
    expect(find.text('Sin fecha'), findsOneWidget);
    expect(find.text('Sin importe'), findsOneWidget);
  });

  testWidgets('sin comprobantes lo dice y permite actualizar (A1)', (
    tester,
  ) async {
    var pedidos = 0;
    await mostrar(
      tester,
      cargar: () async {
        pedidos++;
        return pedidos == 1 ? <ComprobantePropio>[] : [recibo(1)];
      },
    );
    await tester.pump();

    expect(
      find.textContaining('Todavía no tenés comprobantes'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('accion-comprobantes')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('comprobante-1')), findsOneWidget);
  });

  testWidgets('ante un error ofrece reintentar y carga', (tester) async {
    var falla = true;
    await mostrar(
      tester,
      cargar: () async {
        if (falla) throw StateError('sin red');
        return [recibo(1)];
      },
    );
    await tester.pump();
    expect(find.textContaining('No pudimos cargar'), findsOneWidget);

    falla = false;
    await tester.tap(find.byKey(const ValueKey('accion-comprobantes')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('comprobante-1')), findsOneWidget);
  });

  testWidgets('tocar una fila pide abrir ese comprobante', (tester) async {
    final abiertos = <int>[];
    await mostrar(
      tester,
      cargar: () async => [recibo(1), factura(2)],
      abrir: (c) => abiertos.add(c.idComprobante),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('comprobante-2')));
    expect(abiertos, [2]);
  });

  testWidgets('una respuesta vieja no pisa a la más reciente', (tester) async {
    final primera = Completer<List<ComprobantePropio>>();
    final segunda = Completer<List<ComprobantePropio>>();

    await mostrar(tester, cargar: () => primera.future);
    // Cambia el adaptador: la pantalla vuelve a cargar con el nuevo.
    await mostrar(tester, cargar: () => segunda.future);

    segunda.complete([recibo(2)]);
    await tester.pump();
    primera.complete([recibo(1)]);
    await tester.pump();

    expect(find.byKey(const ValueKey('comprobante-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('comprobante-1')), findsNothing);
  });
}
