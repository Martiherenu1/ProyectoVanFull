import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pasajero/deuda.dart';
import 'package:frontend/widgets/admin/resumen_deuda_admin.dart';

void main() {
  Future<void> mostrar(WidgetTester tester, Deuda? deuda, {int cliente = 12}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResumenDeudaAdmin(idCliente: cliente, deuda: deuda),
          ),
        ),
      );

  testWidgets('presenta cliente y saldo suministrados sin acciones contables', (
    tester,
  ) async {
    await mostrar(
      tester,
      const Deuda(saldo: 1250.50, estado: EstadoDeuda.conDeuda),
    );
    expect(find.text('Cliente 12'), findsOneWidget);
    expect(find.text(r'Saldo deudor: $ 1.250,50'), findsOneWidget);
    expect(find.text('Situación: Con deuda'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ButtonStyleButton), findsNothing);
    expect(find.textContaining('suspendido'), findsNothing);
    expect(find.textContaining('habilitado'), findsNothing);
  });

  testWidgets('sin datos no inventa saldo cero ni situación al día', (
    tester,
  ) async {
    await mostrar(tester, null);
    expect(find.text('Sin información de deuda disponible.'), findsOneWidget);
    expect(find.textContaining('Saldo deudor:'), findsNothing);
    expect(find.text('Situación: Al día'), findsNothing);
  });

  testWidgets('actualiza presentación al recibir datos de otro cliente', (
    tester,
  ) async {
    await mostrar(
      tester,
      const Deuda(saldo: 1250, estado: EstadoDeuda.conDeuda),
    );
    await mostrar(
      tester,
      const Deuda(saldo: 0, estado: EstadoDeuda.alDia),
      cliente: 15,
    );
    expect(find.text('Cliente 12'), findsNothing);
    expect(find.text('Cliente 15'), findsOneWidget);
    expect(find.text('Situación: Con deuda'), findsNothing);
    expect(find.text('Situación: Al día'), findsOneWidget);
    expect(find.text(r'Saldo deudor: $ 0,00'), findsOneWidget);
  });
}
