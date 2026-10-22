import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pasajero/disponibilidad_viaje.dart';
import 'package:frontend/models/pasajero/parada.dart';
import 'package:frontend/models/pasajero/reserva.dart';
import 'package:frontend/screens/pasajero/buscar_servicio_screen.dart';
import 'package:frontend/screens/pasajero/confirmar_reserva_screen.dart';

DisponibilidadViaje viaje({String? horario = '06:15'}) =>
    DisponibilidadViaje.fromJson({
      'id_viaje': 12,
      'id_servicio': 2,
      'id_recorrido': 3,
      'fecha': '2026-10-30',
      'horario': ?horario,
      'sentido': 'IDA',
      'cupo_disponible': 14,
    });

Parada parada(int orden, String nombre) => Parada.fromJson({
  'id_parada': orden * 10,
  'orden': orden,
  'nombre_descripcion': nombre,
  'comprometida': true,
});

Reserva reserva({String estado = 'consolidada', int orden = 2}) =>
    Reserva.fromJson({
      'id_reserva': 41,
      'id_pasajero': 7,
      'id_viaje': 12,
      'id_recorrido': 3,
      'orden_parada': orden,
      'fecha': '2026-10-30',
      'horario': '06:15',
      'sentido': 'IDA',
      'estado': estado,
    });

ReservaRechazada rechazo(String codigo, [String mensaje = 'Mensaje']) =>
    ReservaRechazada(codigo: codigo, mensaje: mensaje);

final paradasDelRecorrido = [
  parada(1, 'Av. San Martín 1240'),
  parada(2, 'Plaza Belgrano'),
  parada(3, 'Terminal de Ómnibus'),
];

Future<void> mostrar(
  WidgetTester tester, {
  DisponibilidadViaje? elegido,
  CargarParadas? paradas,
  required CrearReserva crear,
  ValueChanged<Reserva>? terminar,
}) => tester.pumpWidget(
  MaterialApp(
    home: ConfirmarReservaScreen(
      viaje: elegido ?? viaje(),
      cargarParadas: paradas ?? (_) async => paradasDelRecorrido,
      crearReserva: crear,
      onTerminar: terminar ?? (_) {},
    ),
  ),
);

ElevatedButton botonConfirmar(WidgetTester tester) => tester
    .widget<ElevatedButton>(find.byKey(const ValueKey('confirmar-reserva')));

void main() {
  testWidgets('muestra el viaje y pide las paradas de su recorrido', (
    tester,
  ) async {
    int? recorrido;
    await mostrar(
      tester,
      paradas: (id) async {
        recorrido = id;
        return paradasDelRecorrido;
      },
      crear: (_, _) async => reserva(),
    );
    await tester.pump();

    expect(recorrido, 3);
    expect(find.text('06:15'), findsOneWidget);
    expect(find.text('IDA · 30/10/2026'), findsOneWidget);
    expect(find.text('Plaza Belgrano'), findsOneWidget);
  });

  testWidgets('no se puede confirmar sin elegir una parada', (tester) async {
    await mostrar(tester, crear: (_, _) async => reserva());
    await tester.pump();

    expect(botonConfirmar(tester).onPressed, isNull);
    expect(find.text('Elegí dónde subís'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('parada-2')));
    await tester.pump();

    expect(botonConfirmar(tester).onPressed, isNotNull);
    expect(find.text('Confirmar reserva'), findsNWidgets(2));
  });

  testWidgets('crea la reserva con el viaje y el orden de la parada', (
    tester,
  ) async {
    int? idViaje;
    int? orden;
    await mostrar(
      tester,
      crear: (v, o) async {
        idViaje = v;
        orden = o;
        return reserva();
      },
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('parada-2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirmar-reserva')));
    await tester.pump();

    expect(idViaje, 12);
    expect(orden, 2);
  });

  testWidgets('con la reserva creada muestra su estado y la parada', (
    tester,
  ) async {
    Reserva? entregada;
    await mostrar(
      tester,
      crear: (_, _) async => reserva(),
      terminar: (r) => entregada = r,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('parada-2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirmar-reserva')));
    await tester.pump();

    expect(find.text('Reserva confirmada'), findsOneWidget);
    expect(find.text('Subís en Plaza Belgrano.'), findsOneWidget);
    expect(find.byKey(const ValueKey('confirmar-reserva')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('terminar-reserva')));
    expect(entregada?.idReserva, 41);
  });

  testWidgets('una reserva provisional no se muestra como confirmada', (
    tester,
  ) async {
    await mostrar(
      tester,
      crear: (_, _) async => reserva(estado: 'provisional'),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('parada-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirmar-reserva')));
    await tester.pump();

    expect(find.text('Reserva provisional'), findsOneWidget);
    expect(find.text('Reserva confirmada'), findsNothing);
  });

  testWidgets('mientras envía bloquea el botón y no manda dos pedidos', (
    tester,
  ) async {
    final respuesta = Completer<Reserva>();
    var pedidos = 0;
    await mostrar(
      tester,
      crear: (_, _) {
        pedidos++;
        return respuesta.future;
      },
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('parada-2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirmar-reserva')));
    await tester.pump();

    expect(find.text('Reservando…'), findsOneWidget);
    expect(botonConfirmar(tester).onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey('confirmar-reserva')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(pedidos, 1);

    respuesta.complete(reserva());
    await tester.pump();
    expect(find.text('Reserva confirmada'), findsOneWidget);
  });

  group('rechazos del backend', () {
    Future<void> reservarConError(WidgetTester tester, Object error) async {
      await mostrar(tester, crear: (_, _) async => throw error);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('parada-2')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('confirmar-reserva')));
      await tester.pump();
    }

    String aviso(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const ValueKey('aviso-reserva'))).data!;

    testWidgets('sin cupo dice el horario y no deja reintentar', (
      tester,
    ) async {
      await reservarConError(tester, rechazo('CUPO_NO_DISPONIBLE'));

      expect(aviso(tester), startsWith('Sin cupo en el 06:15.'));
      expect(botonConfirmar(tester).onPressed, isNull);
    });

    testWidgets('ya reservado (RN-031) dice el sentido y la fecha', (
      tester,
    ) async {
      await reservarConError(tester, rechazo('RESERVA_DUPLICADA_DEL_DIA'));

      expect(aviso(tester), 'Ya tenés una reserva de ida para el 30/10/2026.');
      expect(botonConfirmar(tester).onPressed, isNull);
    });

    testWidgets('reserva cancelada previa y viaje no reservable', (
      tester,
    ) async {
      await reservarConError(tester, rechazo('RESERVA_CANCELADA_PREVIA'));
      expect(aviso(tester), contains('no se puede reactivar'));

      await tester.pumpWidget(const SizedBox());
      await reservarConError(tester, rechazo('VIAJE_NO_RESERVABLE'));
      expect(aviso(tester), 'Este viaje ya no admite reservas.');
    });

    testWidgets('parada no válida deja elegir otra', (tester) async {
      await reservarConError(tester, rechazo('PARADA_NO_VALIDA'));

      expect(aviso(tester), contains('Elegí otra'));
      expect(botonConfirmar(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('parada-3')));
      await tester.pump();
      expect(find.byKey(const ValueKey('aviso-reserva')), findsNothing);
    });

    testWidgets('una falla de red deja reintentar', (tester) async {
      await reservarConError(tester, Exception('sin conexión'));

      expect(aviso(tester), 'No pudimos crear la reserva. Volvé a intentar.');
      expect(botonConfirmar(tester).onPressed, isNotNull);
    });

    testWidgets('un código desconocido muestra el mensaje del backend', (
      tester,
    ) async {
      await reservarConError(tester, rechazo('OTRO', 'Motivo del servidor.'));

      expect(aviso(tester), 'Motivo del servidor.');
    });
  });

  testWidgets('si falla la carga de paradas permite reintentar', (
    tester,
  ) async {
    var llamadas = 0;
    await mostrar(
      tester,
      paradas: (_) async {
        llamadas++;
        if (llamadas == 1) throw Exception('sin red');
        return paradasDelRecorrido;
      },
      crear: (_, _) async => reserva(),
    );
    await tester.pump();

    expect(find.text('No pudimos cargar las paradas.'), findsOneWidget);
    expect(botonConfirmar(tester).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('reintentar-paradas')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Plaza Belgrano'), findsOneWidget);
  });

  testWidgets('un viaje sin horario no inventa uno', (tester) async {
    await mostrar(
      tester,
      elegido: viaje(horario: null),
      crear: (_, _) async => throw rechazo('CUPO_NO_DISPONIBLE'),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('parada-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirmar-reserva')));
    await tester.pump();

    expect(find.text('Sin horario'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('aviso-reserva'))).data,
      startsWith('Sin cupo en este viaje.'),
    );
  });
}
