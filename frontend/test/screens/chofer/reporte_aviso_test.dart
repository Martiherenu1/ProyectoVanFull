import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/chofer/reporte_aviso.dart';
import 'package:frontend/services/chofer/avisos_api.dart';

void main() {
  testWidgets('bloquea doble envío y confirma únicamente al responder', (
    t,
  ) async {
    final done = Completer<int>();
    var calls = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReporteAviso(
            viaje: 1,
            registrar: (_, _, _, _) {
              calls++;
              return done.future;
            },
            recuperar: (_, _) async => 1,
          ),
        ),
      ),
    );
    await t.enterText(find.byType(TextField), 'Interno');
    expect(
      t.getSize(find.widgetWithText(ElevatedButton, 'Registrar aviso')).height,
      greaterThanOrEqualTo(64),
    );
    await t.tap(find.text('Registrar aviso'));
    await t.pump();
    await t.tap(find.text('Registrar aviso'));
    await t.pump();
    expect(calls, 1);
    expect(find.textContaining('Aviso registrado (#'), findsNothing);
    done.complete(42);
    await t.pumpAndSettle();
    expect(find.textContaining('Aviso registrado (#42)'), findsOneWidget);
  });

  testWidgets('incertidumbre conserva clave, consulta y repetición exacta', (
    t,
  ) async {
    final claves = <String>[];
    var consultas = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReporteAviso(
            viaje: 1,
            registrar: (_, clave, _, _) async {
              claves.add(clave);
              throw Exception('red');
            },
            recuperar: (_, clave) async {
              expect(clave, claves.first);
              consultas++;
              throw Exception('404');
            },
          ),
        ),
      ),
    );
    await t.enterText(find.byType(TextField), 'Interno');
    await t.tap(find.text('Registrar aviso'));
    await t.pumpAndSettle();
    expect(find.textContaining('No pudimos confirmar'), findsOneWidget);
    await t.tap(find.text('Consultar resultado'));
    await t.pumpAndSettle();
    expect(consultas, 1);
    await t.tap(find.text('Repetir el mismo reporte'));
    await t.pumpAndSettle();
    expect(claves.length, 2);
    expect(claves.first, claves.last);
    expect(find.textContaining('Aviso registrado (#'), findsNothing);
  });

  testWidgets('rechazo conocido no anuncia registro', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReporteAviso(
            viaje: 1,
            registrar: (_, _, _, _) async => throw AvisoRechazado(),
            recuperar: (_, _) async => 1,
          ),
        ),
      ),
    );
    await t.enterText(find.byType(TextField), 'Interno');
    await t.tap(find.text('Registrar aviso'));
    await t.pumpAndSettle();
    expect(find.textContaining('registro fue rechazado'), findsOneWidget);
    expect(find.text('Consultar resultado'), findsNothing);
  });

  testWidgets('cambio de viaje descarta respuesta tardía', (t) async {
    final done = Completer<int>();
    Future<int> registrar(int _, String _, String _, String _) => done.future;
    Future<int> recuperar(int _, String _) async => 1;
    Widget vista(int v) => MaterialApp(
      home: Scaffold(
        body: ReporteAviso(
          viaje: v,
          registrar: registrar,
          recuperar: recuperar,
        ),
      ),
    );
    await t.pumpWidget(vista(1));
    await t.enterText(find.byType(TextField), 'Interno');
    await t.tap(find.text('Registrar aviso'));
    await t.pump();
    await t.pumpWidget(vista(2));
    done.complete(7);
    await t.pumpAndSettle();
    expect(find.textContaining('Aviso registrado (#7)'), findsNothing);
  });
}
