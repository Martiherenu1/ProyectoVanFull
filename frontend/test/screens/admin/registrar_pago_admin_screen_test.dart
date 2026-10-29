import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/pasajero/pago.dart';
import 'package:frontend/models/admin/borrador_imputacion_pago.dart';
import 'package:frontend/screens/admin/registrar_pago_admin_screen.dart';
import 'package:frontend/widgets/admin/borrador_imputacion_pago_form.dart';

const resultado = Pago(
  idPago: 5,
  importe: 1250.5,
  medioPago: 'TRANSFERENCIA',
  estado: EstadoPago.pendiente,
);
Future<void> completarRegistro(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('pago-id-cliente')), '12');
  await tester.enterText(find.byKey(const Key('pago-importe')), '1.250,50');
  await tester.tap(find.byKey(const Key('pago-medio')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Transferencia').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('registrar-pago-admin')));
  await tester.pumpAndSettle();
}

Future<void> confirmarRegistro(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('confirmar-registro-pago')));
  await tester.pumpAndSettle();
}

void main() {
  Future<void> mostrar(WidgetTester tester, RegistrarPagoAdmin registrar) =>
      tester.pumpWidget(
        MaterialApp(home: RegistrarPagoAdminScreen(registrar: registrar)),
      );
  testWidgets(
    'confirma destinatario y registra pendiente sin emitir comprobante',
    (tester) async {
      var llamadas = 0;
      await mostrar(tester, ({
        required idCliente,
        required importe,
        required medio,
      }) async {
        llamadas++;
        expect(idCliente, 12);
        expect(importe, 1250.5);
        expect(medio, MedioPago.transferencia);
        return resultado;
      });
      await completarRegistro(tester);
      expect(llamadas, 0);
      expect(find.textContaining('Cliente 12'), findsOneWidget);
      await confirmarRegistro(tester);
      expect(llamadas, 1);
      expect(find.text('Estado: Pendiente'), findsOneWidget);
      expect(
        find.text('Pago 5 registrado para el cliente 12.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('registrar-pago-admin')), findsNothing);
    },
  );
  testWidgets('volver no envía; datos inválidos no llaman al backend', (
    tester,
  ) async {
    var llamadas = 0;
    await mostrar(tester, ({
      required idCliente,
      required importe,
      required medio,
    }) async {
      llamadas++;
      return resultado;
    });
    await tester.tap(find.byKey(const Key('registrar-pago-admin')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('error-registro-pago')), findsOneWidget);
    expect(llamadas, 0);
    await completarRegistro(tester);
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(llamadas, 0);
  });
  testWidgets('error contractual no borra formulario y habilita corrección', (
    tester,
  ) async {
    await mostrar(
      tester,
      ({required idCliente, required importe, required medio}) async =>
          throw const ApiException(
            statusCode: 404,
            codigo: 'CUENTA_CORRIENTE_NO_ENCONTRADA',
            mensaje: 'El cliente no tiene cuenta corriente.',
          ),
    );
    await completarRegistro(tester);
    await confirmarRegistro(tester);
    expect(find.text('El cliente no tiene cuenta corriente.'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('registrar-pago-admin')))
          .onPressed,
      isNotNull,
    );
  });
  testWidgets('no permite doble envío y descarta respuesta tras desmontar', (
    tester,
  ) async {
    var llamadas = 0;
    final pendiente = Completer<Pago>();
    await mostrar(tester, ({
      required idCliente,
      required importe,
      required medio,
    }) {
      llamadas++;
      return pendiente.future;
    });
    await completarRegistro(tester);
    await confirmarRegistro(tester);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('registrar-pago-admin')))
          .onPressed,
      isNull,
    );
    expect(llamadas, 1);
    await tester.pumpWidget(const MaterialApp(home: Text('Otra pantalla')));
    await tester.pumpAndSettle();
    pendiente.complete(resultado);
    await tester.pumpAndSettle();
    expect(find.text('Estado: Pendiente'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'borrador conserva tipo y evidencia localmente sin acción de envío',
    (tester) async {
      BorradorImputacionPago? borrador;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BorradorImputacionPagoForm(
              onChanged: (valor) => borrador = valor,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(DropdownButtonFormField<TipoPagoBorrador>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seña').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'respaldo local');
      expect(borrador!.tipo, TipoPagoBorrador.senia);
      expect(borrador!.evidencia, 'respaldo local');
      expect(borrador!.tieneDatos, isTrue);
      expect(find.byType(FilledButton), findsNothing);
    },
  );
}
