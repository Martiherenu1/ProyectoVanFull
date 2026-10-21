import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/navigation/app_role.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/main.dart';

void main() {
  test('los temas respetan rol, contraste y superficies planas', () {
    expect(AppTheme.admin.brightness, Brightness.light);
    expect(AppTheme.admin.colorScheme.primary, AppColors.goldText);
    expect(AppTheme.passenger.brightness, Brightness.dark);
    expect(AppTheme.driver.brightness, Brightness.dark);
    expect(AppTheme.passenger.colorScheme.primary, AppColors.gold);
    expect(AppTheme.admin.shadowColor, Colors.transparent);
    expect(AppTheme.admin.colorScheme.surfaceTint, Colors.transparent);
    expect(
      AppTheme.admin.textTheme.titleMedium?.fontFamily,
      contains('Archivo'),
    );

    for (final theme in [AppTheme.admin, AppTheme.passenger]) {
      expect(
        _contrastRatio(
          theme.colorScheme.secondary,
          theme.colorScheme.onSecondary,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(theme.colorScheme.error, theme.colorScheme.onError),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('reconoce solo los roles contemplados por la navegación', () {
    expect(AppRole.fromApiValue('pasajero'), AppRole.passenger);
    expect(AppRole.fromApiValue('chofer'), AppRole.driver);
    expect(AppRole.fromApiValue('administrador'), AppRole.admin);
    expect(AppRole.fromApiValue('rol_inexistente'), isNull);
  });

  for (final scenario in [
    (
      apiRole: 'pasajero',
      title: 'Buscar servicio',
      useCase: 'CU-002 · Entrada temporal',
      brightness: Brightness.dark,
      height: 48.0,
    ),
    (
      apiRole: 'chofer',
      title: 'Lista del viaje',
      useCase: 'CU-029 · Entrada temporal',
      brightness: Brightness.dark,
      height: 64.0,
    ),
    (
      apiRole: 'administrador',
      title: 'Viajes del día',
      useCase: 'CU-018 · Entrada temporal',
      brightness: Brightness.light,
      height: 36.0,
    ),
  ]) {
    testWidgets('abre la entrada temporal de ${scenario.apiRole}', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(VanFullApp(roles: [scenario.apiRole]));

      expect(find.text(scenario.title), findsOneWidget);
      expect(find.text(scenario.useCase), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        scenario.brightness,
      );
      expect(
        tester
            .getSize(
              find.byKey(ValueKey('role-touch-target-${scenario.apiRole}')),
            )
            .height,
        scenario.height,
      );
    });
  }

  testWidgets('sin rol espera la integración con autenticación', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VanFullApp());

    expect(find.text('Autenticación pendiente'), findsOneWidget);
    expect(find.text('Buscar servicio'), findsNothing);
    expect(find.text('Lista del viaje'), findsNothing);
    expect(find.text('Viajes del día'), findsNothing);
  });

  testWidgets('no elige entre múltiples roles', (WidgetTester tester) async {
    await tester.pumpWidget(
      const VanFullApp(roles: ['pasajero', 'administrador']),
    );

    expect(find.text('Selección de rol pendiente'), findsOneWidget);
    expect(find.text('Buscar servicio'), findsNothing);
    expect(find.text('Viajes del día'), findsNothing);
  });

  testWidgets('no enruta un rol desconocido', (WidgetTester tester) async {
    await tester.pumpWidget(const VanFullApp(roles: ['rol_inexistente']));

    expect(find.text('Rol no reconocido'), findsOneWidget);
    expect(find.text('Buscar servicio'), findsNothing);
    expect(find.text('Lista del viaje'), findsNothing);
    expect(find.text('Viajes del día'), findsNothing);
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  return (math.max(firstLuminance, secondLuminance) + 0.05) /
      (math.min(firstLuminance, secondLuminance) + 0.05);
}
