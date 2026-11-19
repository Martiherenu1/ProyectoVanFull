import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> abrirMenuAdmin(WidgetTester tester) async {
  final abrir = find.byType(DrawerButton).hitTestable();
  if (abrir.evaluate().isEmpty) return;
  await tester.tap(abrir);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> tocarMenuAdmin(WidgetTester tester, Key clave) async {
  await abrirMenuAdmin(tester);
  final destino = find.byKey(clave);
  await tester.ensureVisible(destino);
  expect(destino.hitTestable(), findsOneWidget);
  await tester.tap(destino);
}
