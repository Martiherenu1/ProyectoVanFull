import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/admin/pago_admin.dart';
import 'package:frontend/screens/admin/pagos_pendientes_screen.dart';
import 'package:frontend/services/admin/pagos_admin_api.dart';

import '../../services/admin/pagos_admin_api_test.dart' as datos;

void main() {
  Future<void> mostrar(
    WidgetTester tester,
    Future<List<PagoAdmin>> Function() cargar,
    Future<PagoAdmin> Function(int, DecisionPago) decidir,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PagosPendientesScreen(cargar: cargar, decidir: decidir),
      ),
    );
    await tester.pumpAndSettle();
  }

  PagoAdmin pago({String estado = 'PENDIENTE'}) =>
      PagoAdmin.fromJson(datos.pagoJson(estado: estado));
  Future<void> confirmar(WidgetTester tester, String accion) async {
    await tester.tap(find.byKey(ValueKey('$accion-pago-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-decision-pago')));
    await tester.pumpAndSettle();
  }

  for (final decision in DecisionPago.values) {
    testWidgets('${decision.valorApi} refresca listado', (tester) async {
      var decidido = false;
      var cargas = 0;
      await mostrar(
        tester,
        () async {
          cargas++;
          return decidido ? [] : [pago()];
        },
        (id, d) async {
          expect(id, 1);
          expect(d, decision);
          decidido = true;
          return pago(estado: d.valorApi);
        },
      );
      expect(find.textContaining('Cliente 2'), findsOneWidget);
      await confirmar(
        tester,
        decision == DecisionPago.confirmar ? 'confirmar' : 'rechazar',
      );
      expect(cargas, 2);
      expect(find.text('No hay pagos pendientes.'), findsOneWidget);
      expect(find.textContaining('Pago 1:'), findsOneWidget);
    });
  }
  testWidgets('volver no envía y error backend permite reintento', (
    tester,
  ) async {
    var llamadas = 0;
    await mostrar(tester, () async => [pago()], (_, _) async {
      llamadas++;
      throw const ApiException(
        statusCode: 404,
        codigo: 'PAGO_PENDIENTE_NO_ENCONTRADO',
        mensaje: 'El pago ya fue decidido.',
      );
    });
    await tester.tap(find.byKey(const Key('confirmar-pago-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(llamadas, 0);
    await confirmar(tester, 'rechazar');
    expect(llamadas, 1);
    expect(find.text('El pago ya fue decidido.'), findsOneWidget);
  });
  testWidgets('carga vacía, error y reintento', (tester) async {
    var cargas = 0;
    await mostrar(tester, () async {
      if (cargas++ == 0) throw Exception();
      return [];
    }, (_, _) async => pago());
    expect(find.byKey(const Key('error-pagos')), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('No hay pagos pendientes.'), findsOneWidget);
  });
  testWidgets(
    'evita doble envío y descarta respuesta con pantalla desmontada',
    (tester) async {
      final pendiente = Completer<PagoAdmin>();
      var llamadas = 0;
      var cargas = 0;
      await mostrar(
        tester,
        () async {
          cargas++;
          return [pago()];
        },
        (_, _) {
          llamadas++;
          return pendiente.future;
        },
      );
      await confirmar(tester, 'confirmar');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('confirmar-pago-1')))
            .onPressed,
        isNull,
      );
      expect(llamadas, 1);
      await tester.pumpWidget(const MaterialApp(home: Text('Otra sesión')));
      await tester.pumpAndSettle();
      pendiente.complete(pago(estado: 'CONFIRMADO'));
      await tester.pumpAndSettle();
      expect(cargas, 1);
      expect(tester.takeException(), isNull);
      expect(find.text('Otra sesión'), findsOneWidget);
    },
  );
}
