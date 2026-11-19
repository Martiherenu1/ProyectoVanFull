import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/widgets/admin/marco_admin.dart';

import '../../admin_menu_helpers.dart';

void main() {
  for (final ancho in [1440.0, 390.0]) {
    testWidgets('menú administrativo a ${ancho.toInt()} px', (tester) async {
      await tester.binding.setSurfaceSize(Size(ancho, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final eventos = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.admin,
          home: MarcoAdmin(
            activo: DestinoAdmin.viajes,
            acciones: {
              DestinoAdmin.viajes: () {},
              DestinoAdmin.vehiculos: () {},
              DestinoAdmin.registrarPago: () => eventos.add('registrar'),
              DestinoAdmin.pagosPendientes: () => eventos.add('pendientes'),
            },
            onSalir: () => eventos.add('salir'),
            child: const Center(child: Text('Viajes del día')),
          ),
        ),
      );
      await abrirMenuAdmin(tester);
      expect(find.text('Operación'), findsOneWidget);
      expect(find.text('Catálogos'), findsOneWidget);
      expect(find.text('Cobros'), findsOneWidget);
      expect(find.text('Tarifas'), findsNothing);
      expect(find.text('Administradores'), findsNothing);

      await tocarMenuAdmin(tester, DestinoAdmin.registrarPago.clave);
      await tester.pumpAndSettle();
      await tocarMenuAdmin(tester, DestinoAdmin.pagosPendientes.clave);
      await tester.pumpAndSettle();
      await tocarMenuAdmin(tester, const Key('admin-salir'));
      await tester.pumpAndSettle();

      expect(eventos, ['registrar', 'pendientes', 'salir']);
      expect(tester.takeException(), isNull);
    });
  }
}
