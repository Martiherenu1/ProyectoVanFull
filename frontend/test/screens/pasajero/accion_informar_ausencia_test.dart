import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/screens/pasajero/accion_informar_ausencia.dart';

void main() {
  final alcance = Object();
  Future<void> mostrar(
    WidgetTester t,
    InformarAusencia f, {
    Object? sesion,
    int idViaje = 12,
    bool Function()? vigente,
  }) => t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AccionInformarAusencia(
          idViaje: idViaje,
          alcance: sesion ?? alcance,
          contextoVigente: vigente ?? () => true,
          informar: f,
        ),
      ),
    ),
  );
  Future<void> abrir(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('informar-ausencia')));
    await t.pumpAndSettle();
  }

  Future<void> confirmar(WidgetTester t) async {
    await abrir(t);
    await t.tap(find.byKey(const ValueKey('confirmar-ausencia')));
    await t.pumpAndSettle();
  }

  testWidgets('cancelar confirmación no envía', (t) async {
    var n = 0;
    await mostrar(t, (_) async {
      n++;
    });
    await abrir(t);
    expect(find.textContaining('se libera tu lugar'), findsOneWidget);
    expect(
      find.textContaining('Recuperar el lugar no está incluido'),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('no-informar-ausencia')));
    await t.pumpAndSettle();
    expect(n, 0);
  });
  testWidgets('doble pulsación y envío bloqueados', (t) async {
    var n = 0;
    final c = Completer<void>();
    await mostrar(t, (id) {
      expect(id, 12);
      n++;
      return c.future;
    });
    await t.pumpAndSettle();
    final pulsar = t
        .widget<OutlinedButton>(find.byKey(const ValueKey('informar-ausencia')))
        .onPressed!;
    await t.tap(find.byKey(const ValueKey('informar-ausencia')));
    pulsar();
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('confirmar-ausencia')));
    await t.pumpAndSettle();
    expect(n, 1);
    expect(
      t
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('informar-ausencia')),
          )
          .onPressed,
      isNull,
    );
    c.complete();
    await t.pumpAndSettle();
    expect(find.text('Tu aviso de ausencia está registrado.'), findsOneWidget);
  });
  for (final status in [400, 401, 403, 404, 409]) {
    testWidgets('rechazo $status', (t) async {
      await mostrar(
        t,
        (_) async => throw ApiException(
          statusCode: status,
          codigo: 'RECHAZO',
          mensaje: 'Motivo contractual',
        ),
      );
      await confirmar(t);
      expect(find.text('Motivo contractual'), findsOneWidget);
    });
  }
  testWidgets('red incierta y reintento explícito', (t) async {
    var n = 0;
    await mostrar(t, (_) async {
      if (++n == 1) throw Exception('red');
    });
    await confirmar(t);
    expect(
      find.textContaining('No pudimos confirmar si el aviso quedó registrado'),
      findsOneWidget,
    );
    await t.pump(const Duration(seconds: 20));
    expect(n, 1);
    await confirmar(t);
    expect(n, 2);
    expect(find.text('Tu aviso de ausencia está registrado.'), findsOneWidget);
  });
  for (final falla in [false, true]) {
    testWidgets('cambio de sesión descarta respuesta, falla=$falla', (t) async {
      final c = Completer<void>();
      await mostrar(t, (_) => c.future);
      await confirmar(t);
      await mostrar(t, (_) async {}, sesion: Object());
      if (falla) {
        c.completeError(Exception('red'));
      } else {
        c.complete();
      }
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('resultado-ausencia')), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('invalida sesión durante confirmación', (t) async {
    var vigente = true;
    var n = 0;
    await mostrar(t, (_) async {
      n++;
    }, vigente: () => vigente);
    await abrir(t);
    vigente = false;
    await t.tap(find.byKey(const ValueKey('confirmar-ausencia')));
    await t.pumpAndSettle();
    expect(n, 0);
  });
  testWidgets('desmontaje descarta error tardío', (t) async {
    final c = Completer<void>();
    await mostrar(t, (_) => c.future);
    await confirmar(t);
    await t.pumpWidget(const SizedBox());
    c.completeError(Exception('red'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('reabrir no inventa persistencia', (t) async {
    await mostrar(t, (_) async {});
    await confirmar(t);
    await t.pumpWidget(const SizedBox());
    await mostrar(t, (_) async {});
    expect(find.byKey(const ValueKey('resultado-ausencia')), findsNothing);
  });
  testWidgets('cambio de viaje con confirmación abierta no envía el anterior', (
    t,
  ) async {
    final enviados = <int>[];
    Future<void> informar(int id) async {
      enviados.add(id);
    }

    await mostrar(t, informar);
    await abrir(t);
    await mostrar(t, informar, idViaje: 99);
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(enviados, isEmpty);
    expect(find.byKey(const ValueKey('resultado-ausencia')), findsNothing);
    await confirmar(t);
    expect(enviados, [99]);
  });
}
