import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/pasajero/deuda.dart';
import 'package:frontend/services/admin/consulta_deuda_admin.dart';
import 'package:frontend/screens/admin/consultar_deuda_admin_screen.dart';

final class ConsultaDeudaSimulada implements ConsultaDeudaAdmin {
  ConsultaDeudaSimulada(this.responder);
  final Future<Deuda?> Function(int) responder;
  final List<int> consultados = [];
  @override
  Future<Deuda?> consultar(int idCliente) {
    consultados.add(idCliente);
    return responder(idCliente);
  }
}

const deuda = Deuda(saldo: 1250.5, estado: EstadoDeuda.conDeuda);
void main() {
  Future<void> mostrar(
    WidgetTester tester,
    ConsultaDeudaAdmin consulta,
    Object alcance,
  ) => tester.pumpWidget(
    MaterialApp(
      home: ConsultarDeudaAdminScreen(consulta: consulta, alcance: alcance),
    ),
  );
  Future<void> consultar(WidgetTester tester, String id) async {
    await tester.enterText(find.byKey(const Key('deuda-id-cliente')), id);
    await tester.pump();
    await tester.tap(find.byKey(const Key('consultar-deuda-admin')));
    // Puede quedar una consulta pendiente con spinner animado.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'identifica cliente, consulta y muestra saldo sin inferir acciones',
    (tester) async {
      final consulta = ConsultaDeudaSimulada((_) async => deuda);
      await mostrar(tester, consulta, Object());
      expect(consulta.consultados, isEmpty);
      await consultar(tester, '12');
      expect(consulta.consultados, [12]);
      expect(find.text('Cliente 12'), findsOneWidget);
      expect(find.text(r'Saldo deudor: $ 1.250,50'), findsOneWidget);
      expect(find.text('Situación: Con deuda'), findsOneWidget);
      expect(find.textContaining('Suspender'), findsNothing);
      expect(find.textContaining('Habilitar'), findsNothing);
      expect(find.textContaining('límite'), findsNothing);
    },
  );
  testWidgets('valida identificador sin consultar ni inventar saldo', (
    tester,
  ) async {
    final consulta = ConsultaDeudaSimulada((_) async => deuda);
    await mostrar(tester, consulta, Object());
    await consultar(tester, 'abc');
    expect(consulta.consultados, isEmpty);
    expect(find.text('Indicá un ID de cliente válido.'), findsOneWidget);
    expect(find.textContaining('Saldo deudor:'), findsNothing);
  });
  testWidgets('null es sin datos y cero informado es al día', (tester) async {
    final consulta = ConsultaDeudaSimulada(
      (id) async =>
          id == 12 ? null : const Deuda(saldo: 0, estado: EstadoDeuda.alDia),
    );
    await mostrar(tester, consulta, Object());
    await consultar(tester, '12');
    expect(find.text('Sin información de deuda disponible.'), findsOneWidget);
    expect(find.text('Situación: Al día'), findsNothing);
    await consultar(tester, '15');
    expect(find.text('Cliente 15'), findsOneWidget);
    expect(find.text('Situación: Al día'), findsOneWidget);
  });
  for (final contractual in [true, false]) {
    testWidgets(
      'error ${contractual ? 'contractual' : 'saneado'} y reintento',
      (tester) async {
        var intentos = 0;
        final consulta = ConsultaDeudaSimulada((_) async {
          if (intentos++ == 0) {
            if (contractual) {
              throw const ApiException(
                statusCode: 403,
                codigo: 'SIN_PERMISO',
                mensaje: 'Acceso denegado.',
              );
            }
            throw Exception('dato privado');
          }
          return deuda;
        });
        await mostrar(tester, consulta, Object());
        await consultar(tester, '12');
        expect(find.byKey(const Key('error-consulta-deuda')), findsOneWidget);
        expect(find.textContaining('dato privado'), findsNothing);
        if (contractual) expect(find.text('Acceso denegado.'), findsOneWidget);
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(consulta.consultados, [12, 12]);
        expect(find.text('Situación: Con deuda'), findsOneWidget);
      },
    );
  }
  testWidgets(
    'carga bloquea duplicado y editar cliente descarta respuesta anterior',
    (tester) async {
      final pendiente = Completer<Deuda?>();
      final consulta = ConsultaDeudaSimulada(
        (id) => id == 12 ? pendiente.future : Future.value(null),
      );
      await mostrar(tester, consulta, Object());
      await consultar(tester, '12');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('consultar-deuda-admin')),
            )
            .onPressed,
        isNull,
      );
      await consultar(tester, '15');
      expect(find.text('Cliente 15'), findsOneWidget);
      pendiente.complete(deuda);
      await tester.pumpAndSettle();
      expect(consulta.consultados, [12, 15]);
      expect(find.text('Cliente 12'), findsNothing);
      expect(find.textContaining('1.250,50'), findsNothing);
    },
  );
  testWidgets(
    'cambiar alcance limpia cliente y resultado con mismo adaptador',
    (tester) async {
      final consulta = ConsultaDeudaSimulada((_) async => deuda);
      await mostrar(tester, consulta, Object());
      await consultar(tester, '12');
      await mostrar(tester, consulta, Object());
      await tester.pumpAndSettle();
      expect(find.text('Cliente 12'), findsNothing);
      expect(find.text('12'), findsNothing);
      expect(consulta.consultados, [12]);
    },
  );
  testWidgets(
    'reconstruir con alcance estable conserva resultado sin solicitudes extra',
    (tester) async {
      final consulta = ConsultaDeudaSimulada((_) async => deuda);
      final alcance = Object();
      await mostrar(tester, consulta, alcance);
      await consultar(tester, '12');
      await mostrar(tester, consulta, alcance);
      await tester.pumpAndSettle();
      expect(consulta.consultados, [12]);
      expect(find.text('Cliente 12'), findsOneWidget);
    },
  );
  testWidgets('respuesta y error después de desmontar no modifican la vista', (
    tester,
  ) async {
    for (final error in [false, true]) {
      final pendiente = Completer<Deuda?>();
      await mostrar(
        tester,
        ConsultaDeudaSimulada((_) => pendiente.future),
        Object(),
      );
      await consultar(tester, '12');
      await tester.pumpWidget(const MaterialApp(home: Text('Otra vista')));
      await tester.pumpAndSettle();
      if (error) {
        pendiente.completeError(Exception('dato viejo'));
      } else {
        pendiente.complete(deuda);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Cliente 12'), findsNothing);
    }
  });
}
