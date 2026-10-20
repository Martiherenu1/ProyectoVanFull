import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('ThemePreview muestra los tres temas y botones activos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VanFullApp());

    expect(find.text('VanFull — Administración'), findsOneWidget);
    expect(find.text('ADMINISTRACIÓN'), findsOneWidget);
    expect(find.text('PASAJERO'), findsOneWidget);
    expect(find.text('CHOFER'), findsOneWidget);
    expect(find.text('Viajes del día'), findsNWidgets(3));

    final buttons = tester.widgetList<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(buttons, hasLength(3));
    expect(buttons.every((button) => button.onPressed != null), isTrue);
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  return (math.max(firstLuminance, secondLuminance) + 0.05) /
      (math.min(firstLuminance, secondLuminance) + 0.05);
}
