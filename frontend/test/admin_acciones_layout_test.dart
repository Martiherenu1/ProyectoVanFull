import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/admin/registrar_pago_admin_screen.dart';
import 'package:frontend/screens/admin/pagos_pendientes_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final ancho in [320.0, 1440.0]) {
    testWidgets('acciones administrativas sin desborde a $ancho', (
      tester,
    ) async {
      tester.view.physicalSize = Size(ancho, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final transporte = MockClient(
        (r) async => http.Response(
          r.url.path.endsWith('/auth/login')
              ? jsonEncode({
                  'access_token': 'token',
                  'token_type': 'bearer',
                  'roles': ['administrador'],
                })
              : '[]',
          200,
        ),
      );
      await tester.pumpWidget(
        VanFullBootstrap(
          apiBaseUrl: 'https://vanfull.test/api/',
          crearTransporte: () => transporte,
        ),
      );
      await tester.enterText(
        find.byType(TextField).at(0),
        'admin@vanfull.test',
      );
      await tester.enterText(find.byType(TextField).at(1), 'clave');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();
      for (final key in [
        'admin-consultar-deuda',
        'admin-salir',
        'admin-registrar-pago',
        'admin-pagos-pendientes',
        'admin-crear-viaje',
      ]) {
        final boton = find.byKey(Key(key));
        expect(boton, findsOneWidget);
        final rect = tester.getRect(boton);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(ancho));
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('admin-registrar-pago')));
      await tester.pumpAndSettle();
      expect(find.byType(RegistrarPagoAdminScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      final medio = find.byKey(const Key('pago-medio'));
      await tester.tap(medio);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transferencia').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin-pagos-pendientes')));
      await tester.pumpAndSettle();
      expect(find.byType(PagosPendientesScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
