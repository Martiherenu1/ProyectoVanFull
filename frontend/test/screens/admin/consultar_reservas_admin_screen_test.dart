import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/pasajero/reserva.dart';
import 'package:frontend/models/admin/reserva_admin.dart';
import 'package:frontend/screens/admin/consultar_reservas_admin_screen.dart';
import 'package:frontend/services/admin/consulta_reservas_admin.dart';

/// Doble exclusivo del test: no demuestra permisos ni integración administrativa real.
final class ConsultaSimulada implements ConsultaReservasAdmin {
  ConsultaSimulada(this.responder);
  final Future<List<ReservaAdmin>> Function() responder;
  int llamadas = 0;
  @override
  Future<List<ReservaAdmin>> listar() {
    llamadas++;
    return responder();
  }
}

ReservaAdmin reserva(
  int id, {
  String estado = 'consolidada',
  String? horario = '07:30',
}) => ReservaAdmin.fromJson({
  'id_reserva': id,
  'id_pasajero': 5,
  'id_viaje': 41,
  'id_recorrido': 2,
  'orden_parada': 3,
  'fecha': '2026-10-30',
  'horario': horario,
  'sentido': 'IDA',
  'estado': estado,
});

void main() {
  testWidgets('volver conserva posición y permite seleccionar otra reserva', (
    tester,
  ) async {
    final consulta = ConsultaSimulada(
      () async => List.generate(50, (i) => reserva(i + 1)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ConsultarReservasAdminScreen(
          consulta: consulta,
          alcance: consulta,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('reserva-30')), 300);
    final antes = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .pixels;
    await tester.tap(find.byKey(const Key('reserva-30')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      antes,
    );
    await tester.tap(find.byKey(const Key('reserva-30')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detalle-reserva-30')), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(consulta.llamadas, 1);
  });

  testWidgets('cambio de sesión desde detalle elimina historial anterior', (
    tester,
  ) async {
    final consulta = ConsultaSimulada(() async => [reserva(7)]);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: ConsultarReservasAdminScreen(
          consulta: consulta,
          alcance: Object(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reserva-7')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: ConsultarReservasAdminScreen(
          consulta: consulta,
          alcance: Object(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detalle-reserva-7')), findsNothing);
    expect(
      ModalRoute.of(tester.element(find.byType(ConsultarReservasAdminScreen)))!
          .willHandlePopInternally,
      isFalse,
    );
    expect(find.byKey(const Key('reserva-7')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final flecha in [false, true]) {
    testWidgets(
      'volver al listado y luego salir (${flecha ? 'flecha' : 'sistema'})',
      (tester) async {
        final consulta = ConsultaSimulada(() async => [reserva(7), reserva(8)]);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ConsultarReservasAdminScreen(
                        consulta: consulta,
                        alcance: consulta,
                      ),
                    ),
                  ),
                  child: const Text('Administración'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Administración'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('reserva-7')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('detalle-reserva-7')), findsOneWidget);
        if (flecha) {
          await tester.tap(find.byType(BackButton));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('reserva-8')), findsOneWidget);
        expect(find.byKey(const Key('detalle-reserva-7')), findsNothing);
        expect(consulta.llamadas, 1);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Administración'), findsOneWidget);
        expect(find.byType(ConsultarReservasAdminScreen), findsNothing);
      },
    );
  }
  Future<void> mostrar(
    WidgetTester tester,
    ConsultaReservasAdmin consulta,
    Object alcance,
  ) => tester.pumpWidget(
    MaterialApp(
      home: ConsultarReservasAdminScreen(consulta: consulta, alcance: alcance),
    ),
  );
  testWidgets(
    'carga, localiza por ID en listado, selecciona y consulta sin acciones de escritura',
    (tester) async {
      final pendiente = Completer<List<ReservaAdmin>>();
      final consulta = ConsultaSimulada(() => pendiente.future);
      await mostrar(tester, consulta, Object());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final reservas = [
        reserva(7),
        reserva(8, estado: 'cancelada'),
        reserva(9, estado: 'provisional'),
      ];
      pendiente.complete(reservas);
      await tester.pumpAndSettle();
      expect(find.textContaining('Confirmada (consolidada)'), findsOneWidget);
      expect(find.textContaining('Cancelada (cancelada)'), findsOneWidget);
      expect(find.textContaining('Provisional (provisional)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('reserva-7')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detalle-reserva-7')), findsOneWidget);
      for (final dato in [
        'Reserva: 7',
        'Pasajero: 5',
        'Viaje: 41',
        'Recorrido: 2',
        'Orden de parada de ascenso: 3',
        'Fecha: 30/10/2026',
        'Horario: 07:30',
        'Sentido: Ida',
        'Estado: Confirmada (consolidada)',
      ]) {
        expect(find.text(dato), findsOneWidget);
      }
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reserva-8')), findsOneWidget);
      expect(consulta.llamadas, 1);
      expect(reservas.first.reserva.estado, EstadoReserva.consolidada);
    },
  );
  testWidgets('vacío y horario ausente no se inventan', (tester) async {
    await mostrar(tester, ConsultaSimulada(() async => []), Object());
    await tester.pumpAndSettle();
    expect(find.text('No hay reservas para mostrar.'), findsOneWidget);
    await mostrar(
      tester,
      ConsultaSimulada(() async => [reserva(7, horario: null)]),
      Object(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reserva-7')));
    await tester.pumpAndSettle();
    expect(find.text('Horario: Sin horario'), findsOneWidget);
  });
  for (final contractual in [true, false]) {
    testWidgets(
      'error ${contractual ? 'contractual' : 'saneado'} y reintento',
      (tester) async {
        var intento = 0;
        final consulta = ConsultaSimulada(() async {
          if (intento++ == 0) {
            if (contractual) {
              throw const ApiException(
                statusCode: 403,
                codigo: 'SIN_PERMISO',
                mensaje: 'Acceso denegado.',
              );
            }
            throw Exception('dato privado');
          }
          return [reserva(7)];
        });
        await mostrar(tester, consulta, Object());
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('error-consulta-reservas')),
          findsOneWidget,
        );
        expect(find.textContaining('dato privado'), findsNothing);
        if (contractual) expect(find.text('Acceso denegado.'), findsOneWidget);
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('reserva-7')), findsOneWidget);
        expect(consulta.llamadas, 2);
      },
    );
  }
  testWidgets('nueva sesión limpia detalle y descarta carga anterior', (
    tester,
  ) async {
    final vieja = Completer<List<ReservaAdmin>>();
    var intento = 0;
    final consulta = ConsultaSimulada(() async {
      if (intento++ == 0) return [reserva(7)];
      return vieja.future;
    });
    await mostrar(tester, consulta, Object());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reserva-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Actualizar reservas'));
    await tester.pump();
    await mostrar(tester, ConsultaSimulada(() async => [reserva(8)]), Object());
    await tester.pumpAndSettle();
    vieja.complete([reserva(99)]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detalle-reserva-7')), findsNothing);
    expect(find.byKey(const Key('reserva-8')), findsOneWidget);
    expect(find.byKey(const Key('reserva-99')), findsNothing);
  });
  testWidgets(
    'no recarga por reconstrucción con fuentes estables y sí al actualizar',
    (tester) async {
      final consulta = ConsultaSimulada(() async => [reserva(7)]);
      final alcance = Object();
      await mostrar(tester, consulta, alcance);
      await tester.pumpAndSettle();
      await mostrar(tester, consulta, alcance);
      await tester.pumpAndSettle();
      expect(consulta.llamadas, 1);
      await tester.tap(find.byTooltip('Actualizar reservas'));
      await tester.pumpAndSettle();
      expect(consulta.llamadas, 2);
    },
  );
  testWidgets('respuesta o error tardío tras desmontar se descarta', (
    tester,
  ) async {
    for (final error in [false, true]) {
      final pendiente = Completer<List<ReservaAdmin>>();
      await mostrar(tester, ConsultaSimulada(() => pendiente.future), Object());
      await tester.pump();
      await tester.pumpWidget(
        const MaterialApp(home: Text('Fuera de la consulta')),
      );
      await tester.pumpAndSettle();
      if (error) {
        pendiente.completeError(Exception('respuesta antigua'));
      } else {
        pendiente.complete([reserva(7)]);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('reserva-7')), findsNothing);
    }
  });
}
