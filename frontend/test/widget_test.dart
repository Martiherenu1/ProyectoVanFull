
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('VanFull inicia con el tema de administración', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VanFullApp());

    expect(find.text('VanFull — Administración'), findsOneWidget);
    expect(find.text('Viajes del día'), findsOneWidget);

    final materialApp = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );

    expect(materialApp.theme?.brightness, Brightness.light);
  });
}
