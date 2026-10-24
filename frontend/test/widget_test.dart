import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/navigation/app_role.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/main.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';
import 'package:frontend/screens/admin/viajes_dia_admin_screen.dart';

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

  testWidgets(
    'administrador integra consulta, estados y selección inyectados',
    (WidgetTester tester) async {
      final fechas = <DateTime>[];
      int? seleccionado;
      final viajeCompleto = ViajeResumen(
        idViaje: 42,
        idServicio: 1,
        idRecorrido: 1,
        idVehiculo: 1,
        idChofer: 3,
        fecha: DateTime(2026, 10, 30),
        horario: '07:30',
        sentido: SentidoViaje.ida,
        estado: EstadoViaje.programado,
      );
      final viajeIncompleto = ViajeResumen(
        idViaje: 43,
        idServicio: 1,
        idRecorrido: 1,
        fecha: DateTime(2026, 10, 30),
        horario: '09:30',
        sentido: SentidoViaje.vuelta,
        estado: EstadoViaje.programado,
      );

      await tester.pumpWidget(
        VanFullApp(
          roles: const ['administrador'],
          fechaAdmin: DateTime(2026, 10, 30, 18),
          cargarViajesAdmin: (fecha) async {
            fechas.add(fecha);
            if (fechas.length == 1) throw Exception('sin conexión');
            return [viajeCompleto, viajeIncompleto];
          },
          onViajeAdminSeleccionado: (id) => seleccionado = id,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ViajesDiaAdminScreen), findsOneWidget);
      expect(
        find.text('No pudimos cargar los viajes. Volvé a intentar.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(fechas, [DateTime(2026, 10, 30), DateTime(2026, 10, 30)]);
      expect(find.text('CU-018 · Entrada temporal'), findsNothing);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('43'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('viaje-43-vehículo-pendiente')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('viaje-43-chofer-pendiente')),
        findsOneWidget,
      );
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.light,
      );
      await tester.tap(find.text('42'));
      expect(seleccionado, 42);
    },
  );

  testWidgets('administrador sin servicio no usa datos simulados', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VanFullApp(roles: ['administrador']));
    await tester.pumpAndSettle();

    expect(find.byType(ViajesDiaAdminScreen), findsOneWidget);
    expect(
      find.text('No pudimos cargar los viajes. Volvé a intentar.'),
      findsOneWidget,
    );
  });

  testWidgets('sin rol espera la integración con autenticación', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VanFullApp());

    expect(find.text('Autenticación pendiente'), findsOneWidget);
    expect(find.byType(ViajesDiaAdminScreen), findsNothing);
    expect(find.text('Buscar servicio'), findsNothing);
    expect(find.text('Lista del viaje'), findsNothing);
    expect(find.text('Viajes del día'), findsNothing);
  });

  testWidgets('no elige entre múltiples roles', (WidgetTester tester) async {
    await tester.pumpWidget(
      const VanFullApp(roles: ['pasajero', 'administrador']),
    );

    expect(find.text('Selección de rol pendiente'), findsOneWidget);
    expect(find.byType(ViajesDiaAdminScreen), findsNothing);
    expect(find.text('Buscar servicio'), findsNothing);
    expect(find.text('Viajes del día'), findsNothing);
  });

  testWidgets('no enruta un rol desconocido', (WidgetTester tester) async {
    await tester.pumpWidget(const VanFullApp(roles: ['rol_inexistente']));

    expect(find.text('Rol no reconocido'), findsOneWidget);
    expect(find.byType(ViajesDiaAdminScreen), findsNothing);
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
