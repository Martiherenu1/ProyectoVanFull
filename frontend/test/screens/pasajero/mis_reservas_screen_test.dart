import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/models/pasajero/deuda.dart';
import 'package:frontend/models/pasajero/reserva.dart';
import 'package:frontend/screens/pasajero/mis_reservas_screen.dart';

Reserva reserva(
  int id, {
  String estado = 'consolidada',
  String? horario = '06:15',
  String fecha = '2026-10-30',
  String sentido = 'IDA',
}) => Reserva.fromJson({
  'id_reserva': id,
  'id_pasajero': 7,
  'id_viaje': 100 + id,
  'id_recorrido': 3,
  'orden_parada': 2,
  'fecha': fecha,
  'horario': ?horario,
  'sentido': sentido,
  'estado': estado,
});

Deuda deuda({double saldo = 0, String estado = 'al_dia'}) =>
    Deuda.fromJson({'saldo': saldo, 'estado': estado});

ResultadoCancelacion cancelada(int id, {String motivo = 'Motivo.'}) =>
    ResultadoCancelacion(
      reserva: reserva(id, estado: 'cancelada'),
      cupoLiberado: true,
      penalidadAplicada: false,
      importePenalidad: 0,
      motivo: motivo,
    );

ReservaRechazada rechazo(String codigo, [String mensaje = 'Mensaje']) =>
    ReservaRechazada(codigo: codigo, mensaje: mensaje);

Future<void> mostrar(
  WidgetTester tester, {
  CargarReservas? reservas,
  CargarDeuda? saldo,
  CancelarReserva? cancelar,
  VoidCallback? buscar,
  ValueChanged<Deuda>? pagar,
}) => tester.pumpWidget(
  MaterialApp(
    home: MisReservasScreen(
      cargarReservas: reservas ?? () async => [reserva(1)],
      cargarDeuda: saldo ?? () async => deuda(),
      cancelarReserva: cancelar ?? (id) async => cancelada(id),
      onBuscarServicio: buscar ?? () {},
      onRegistrarPago: pagar,
    ),
  ),
);

String textoDe(WidgetTester tester, String clave) =>
    tester.widget<Text>(find.byKey(ValueKey(clave))).data!;

void main() {
  testWidgets(
    'muestra las reservas con su estado en el vocabulario del brief',
    (tester) async {
      await mostrar(
        tester,
        reservas: () async => [
          reserva(1),
          reserva(
            2,
            estado: 'provisional',
            horario: '07:30',
            sentido: 'VUELTA',
          ),
          reserva(3, estado: 'cancelada', horario: null),
        ],
      );
      await tester.pump();

      expect(find.text('06:15'), findsOneWidget);
      expect(find.text('Ida · 30/10/2026'), findsNWidgets(2));
      expect(find.text('Vuelta · 30/10/2026'), findsOneWidget);
      expect(find.text('Confirmada'), findsOneWidget);
      expect(find.text('Provisional'), findsOneWidget);
      expect(find.text('Cancelada'), findsOneWidget);
      expect(find.text('Sin horario'), findsOneWidget);
    },
  );

  testWidgets('mientras carga muestra un esqueleto y no un spinner', (
    tester,
  ) async {
    final reservas = Completer<List<Reserva>>();
    await mostrar(tester, reservas: () => reservas.future);

    expect(find.bySemanticsLabel('Cargando reservas'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    reservas.complete([reserva(1)]);
    await tester.pump();
    expect(find.bySemanticsLabel('Cargando reservas'), findsNothing);
  });

  testWidgets('sin reservas lo dice y lleva a Buscar servicio', (tester) async {
    var fue = false;
    await mostrar(
      tester,
      reservas: () async => const [],
      buscar: () => fue = true,
    );
    await tester.pump();

    expect(find.text('Todavía no tenés reservas.'), findsOneWidget);
    await tester.tap(find.text('Buscar servicio'));
    expect(fue, isTrue);
  });

  testWidgets('si falla la carga de reservas permite reintentar', (
    tester,
  ) async {
    var llamadas = 0;
    await mostrar(
      tester,
      reservas: () async {
        llamadas++;
        if (llamadas == 1) throw Exception('sin red');
        return [reserva(1)];
      },
    );
    await tester.pump();

    expect(
      find.text('No pudimos cargar tus reservas. Volvé a intentar.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();

    expect(find.text('06:15'), findsOneWidget);
  });

  group('saldo', () {
    testWidgets('al día', (tester) async {
      await mostrar(tester);
      await tester.pump();

      expect(textoDe(tester, 'saldo'), 'Al día');
    });

    testWidgets('con deuda muestra el importe con formato argentino', (
      tester,
    ) async {
      await mostrar(
        tester,
        saldo: () async => deuda(saldo: 11600, estado: 'con_deuda'),
      );
      await tester.pump();

      expect(textoDe(tester, 'saldo'), r'$ 11.600,00');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('saldo'))).style?.color,
        AppColors.alertDark,
      );
    });

    testWidgets('si falla, las reservas igual se ven y el saldo se reintenta', (
      tester,
    ) async {
      var llamadas = 0;
      await mostrar(
        tester,
        saldo: () async {
          llamadas++;
          if (llamadas == 1) throw Exception('sin red');
          return deuda();
        },
      );
      await tester.pump();

      expect(find.text('No pudimos cargar tu saldo.'), findsOneWidget);
      expect(find.text('06:15'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('reintentar-saldo')));
      await tester.pump();
      await tester.pump();
      expect(textoDe(tester, 'saldo'), 'Al día');
    });

    testWidgets('un estado desconocido es un error, no un saldo inventado', (
      tester,
    ) async {
      await mostrar(tester, saldo: () async => deuda(estado: 'moroso'));
      await tester.pump();

      expect(find.text('No pudimos cargar tu saldo.'), findsOneWidget);
    });
  });

  group('cancelar', () {
    Future<void> abrirYCancelar(WidgetTester tester, {int id = 1}) async {
      await tester.tap(find.byKey(ValueKey('reserva-$id')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('cancelar-$id')));
      await tester.pumpAndSettle();
    }

    testWidgets('pide confirmación y, si se conserva, no cancela', (
      tester,
    ) async {
      var pedidos = 0;
      await mostrar(
        tester,
        cancelar: (id) async {
          pedidos++;
          return cancelada(id);
        },
      );
      await tester.pump();
      await abrirYCancelar(tester);

      expect(find.text('¿Cancelar la reserva?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('conservar-reserva')));
      await tester.pumpAndSettle();

      expect(pedidos, 0);
      expect(find.text('Confirmada'), findsOneWidget);
    });

    testWidgets('confirmada: cancela esa reserva y muestra el motivo', (
      tester,
    ) async {
      int? cancelado;
      await mostrar(
        tester,
        reservas: () async => [reserva(1), reserva(2, horario: '07:30')],
        cancelar: (id) async {
          cancelado = id;
          return cancelada(id, motivo: 'Cancelación en término.');
        },
      );
      await tester.pump();
      await abrirYCancelar(tester, id: 2);
      await tester.tap(find.byKey(const ValueKey('confirmar-cancelacion')));
      await tester.pumpAndSettle();

      expect(cancelado, 2);
      expect(find.text('Cancelada'), findsOneWidget);
      expect(find.text('Confirmada'), findsOneWidget);
      expect(textoDe(tester, 'motivo-2'), 'Cancelación en término.');
      expect(find.byKey(const ValueKey('cancelar-2')), findsNothing);
    });

    testWidgets('una reserva cancelada no ofrece cancelar', (tester) async {
      await mostrar(
        tester,
        reservas: () async => [reserva(1, estado: 'cancelada')],
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reserva-1')));
      await tester.pump();

      expect(find.byKey(const ValueKey('cancelar-1')), findsNothing);
    });

    testWidgets('mientras cancela bloquea el botón', (tester) async {
      final respuesta = Completer<ResultadoCancelacion>();
      await mostrar(tester, cancelar: (_) => respuesta.future);
      await tester.pump();
      await abrirYCancelar(tester);
      await tester.tap(find.byKey(const ValueKey('confirmar-cancelacion')));
      await tester.pumpAndSettle();

      expect(find.text('Cancelando…'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('cancelar-1')))
            .onPressed,
        isNull,
      );

      respuesta.complete(cancelada(1));
      await tester.pumpAndSettle();
      expect(find.text('Cancelada'), findsOneWidget);
    });

    testWidgets('los 409 muestran su motivo y la reserva queda como estaba', (
      tester,
    ) async {
      await mostrar(
        tester,
        cancelar: (_) async => throw rechazo('VIAJE_NO_CANCELABLE'),
      );
      await tester.pump();
      await abrirYCancelar(tester);
      await tester.tap(find.byKey(const ValueKey('confirmar-cancelacion')));
      await tester.pumpAndSettle();

      expect(
        textoDe(tester, 'aviso-1'),
        'El viaje ya no está programado: no se puede cancelar.',
      );
      expect(find.text('Confirmada'), findsOneWidget);
    });

    testWidgets('una falla de red deja reintentar', (tester) async {
      await mostrar(tester, cancelar: (_) async => throw Exception('sin red'));
      await tester.pump();
      await abrirYCancelar(tester);
      await tester.tap(find.byKey(const ValueKey('confirmar-cancelacion')));
      await tester.pumpAndSettle();

      expect(
        textoDe(tester, 'aviso-1'),
        'No pudimos cancelar la reserva. Volvé a intentar.',
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('cancelar-1')))
            .onPressed,
        isNotNull,
      );
    });
  });

  testWidgets('con saldo cargado ofrece registrar un pago', (tester) async {
    Deuda? recibida;
    await mostrar(
      tester,
      saldo: () async => deuda(saldo: 11600, estado: 'con_deuda'),
      pagar: (d) => recibida = d,
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('ir-a-pago')));
    expect(recibida?.saldo, 11600);
  });

  testWidgets('sin callback o con el saldo en error no hay botón de pago', (
    tester,
  ) async {
    await mostrar(tester);
    await tester.pump();
    expect(find.byKey(const ValueKey('ir-a-pago')), findsNothing);

    await mostrar(
      tester,
      saldo: () async => throw Exception('caído'),
      pagar: (_) {},
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('ir-a-pago')), findsNothing);
  });
}
