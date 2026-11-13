import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/pasajero/parada.dart';
import 'package:frontend/models/pasajero/reserva.dart';
import 'package:frontend/screens/pasajero/buscar_servicio_screen.dart';
import 'package:frontend/screens/pasajero/cambiar_parada_screen.dart';

Parada parada(int orden, String nombre) => Parada.fromJson({
  'id_parada': orden * 10,
  'orden': orden,
  'nombre_descripcion': nombre,
  'comprometida': true,
});

/// La reserva sube hoy en la parada 2.
Reserva reserva({int orden = 2}) => Reserva.fromJson({
  'id_reserva': 41,
  'id_pasajero': 7,
  'id_viaje': 12,
  'id_recorrido': 3,
  'orden_parada': orden,
  'fecha': '2026-10-30',
  'horario': '06:15',
  'sentido': 'IDA',
  'estado': 'consolidada',
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
  CargarParadas? paradas,
  required CambiarParada cambiar,
  ValueChanged<Reserva>? terminar,
}) => tester.pumpWidget(
  MaterialApp(
    home: CambiarParadaScreen(
      reserva: reserva(),
      cargarParadas: paradas ?? (_) async => paradasDelRecorrido,
      cambiarParada: cambiar,
      onTerminar: terminar ?? (_) {},
    ),
  ),
);

ElevatedButton botonConfirmar(WidgetTester tester) =>
    tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('confirmar-cambio-parada')),
    );

String aviso(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('aviso-cambio-parada')))
    .data!;

Future<void> elegirYConfirmar(WidgetTester tester, int orden) async {
  await tester.tap(find.byKey(ValueKey('parada-$orden')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('confirmar-cambio-parada')));
  await tester.pump();
}

void main() {
  testWidgets('muestra la reserva y pide las paradas de su recorrido', (
    tester,
  ) async {
    int? recorrido;
    await mostrar(
      tester,
      paradas: (id) async {
        recorrido = id;
        return paradasDelRecorrido;
      },
      cambiar: (_, _) async => reserva(),
    );
    await tester.pump();

    expect(recorrido, 3);
    expect(find.text('06:15'), findsOneWidget);
    expect(find.text('IDA · 30/10/2026'), findsOneWidget);
    expect(find.text('Av. San Martín 1240'), findsOneWidget);
    expect(find.text('Terminal de Ómnibus'), findsOneWidget);
  });

  testWidgets('marca la parada actual y no deja elegirla', (tester) async {
    await mostrar(tester, cambiar: (_, _) async => reserva());
    await tester.pump();

    expect(find.byKey(const ValueKey('parada-actual')), findsOneWidget);
    expect(
      tester.widget<InkWell>(find.byKey(const ValueKey('parada-2'))).onTap,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('parada-2')));
    await tester.pump();
    expect(botonConfirmar(tester).onPressed, isNull);
  });

  testWidgets('no se puede confirmar sin elegir otra parada', (tester) async {
    await mostrar(tester, cambiar: (_, _) async => reserva());
    await tester.pump();

    expect(botonConfirmar(tester).onPressed, isNull);
    expect(find.text('Elegí la nueva parada'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('parada-3')));
    await tester.pump();

    expect(botonConfirmar(tester).onPressed, isNotNull);
    expect(find.text('Cambiar parada'), findsNWidgets(2));
  });

  testWidgets('cambia con el id de la reserva y el orden de la parada', (
    tester,
  ) async {
    int? idReserva;
    int? orden;
    Reserva? terminada;
    await mostrar(
      tester,
      cambiar: (id, o) async {
        idReserva = id;
        orden = o;
        return reserva(orden: 3);
      },
      terminar: (r) => terminada = r,
    );
    await tester.pump();
    await elegirYConfirmar(tester, 3);
    await tester.pump();

    expect(idReserva, 41);
    expect(orden, 3);
    expect(find.text('Cambiaste tu parada'), findsOneWidget);
    expect(find.text('Ahora subís en Terminal de Ómnibus.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('terminar-cambio-parada')));
    expect(terminada?.ordenParada, 3);
  });

  testWidgets('no envía dos veces mientras espera la respuesta', (
    tester,
  ) async {
    var llamadas = 0;
    final respuesta = Completer<Reserva>();
    await mostrar(
      tester,
      cambiar: (_, _) {
        llamadas++;
        return respuesta.future;
      },
    );
    await tester.pump();
    await elegirYConfirmar(tester, 3);

    expect(find.text('Cambiando…'), findsOneWidget);
    expect(botonConfirmar(tester).onPressed, isNull);
    await tester.tap(
      find.byKey(const ValueKey('confirmar-cambio-parada')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(llamadas, 1);

    respuesta.complete(reserva(orden: 3));
    await tester.pump();
    expect(find.text('Cambiaste tu parada'), findsOneWidget);
  });

  group('rechazos del backend', () {
    for (final caso in [
      (
        'PARADA_NO_VALIDA',
        'Esa parada no pertenece al recorrido de tu viaje. '
            'Tu parada no cambió: elegí otra.',
      ),
      ('PARADA_SIN_CAMBIOS', 'Ya subís en esa parada. Elegí otra.'),
    ]) {
      testWidgets('${caso.$1} avisa y deja elegir otra', (tester) async {
        await mostrar(tester, cambiar: (_, _) async => throw rechazo(caso.$1));
        await tester.pump();
        await elegirYConfirmar(tester, 3);
        await tester.pump();

        expect(aviso(tester), caso.$2);
        expect(find.text('Cambiaste tu parada'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('parada-1')));
        await tester.pump();
        expect(botonConfirmar(tester).onPressed, isNotNull);
        expect(find.byKey(const ValueKey('aviso-cambio-parada')), findsNothing);
      });
    }

    for (final caso in [
      (
        'RESERVA_NO_MODIFICABLE',
        'Esta reserva está cancelada: no se puede cambiar la parada.',
      ),
      (
        'VIAJE_NO_MODIFICABLE',
        'El viaje ya no está programado: no se puede cambiar la parada. '
            'Tu parada no cambió.',
      ),
    ]) {
      testWidgets('${caso.$1} es definitivo y bloquea el botón', (
        tester,
      ) async {
        await mostrar(tester, cambiar: (_, _) async => throw rechazo(caso.$1));
        await tester.pump();
        await elegirYConfirmar(tester, 3);
        await tester.pump();

        expect(aviso(tester), caso.$2);
        expect(botonConfirmar(tester).onPressed, isNull);
        // Elegir otra parada no destraba nada: reintentar no cambia el resultado.
        await tester.tap(find.byKey(const ValueKey('parada-1')));
        await tester.pump();
        expect(botonConfirmar(tester).onPressed, isNull);
      });
    }

    testWidgets('un código que la pantalla no conoce muestra el del backend', (
      tester,
    ) async {
      await mostrar(
        tester,
        cambiar: (_, _) async => throw rechazo('OTRO', 'Motivo del backend.'),
      );
      await tester.pump();
      await elegirYConfirmar(tester, 3);
      await tester.pump();

      expect(aviso(tester), 'Motivo del backend.');
    });

    testWidgets('el 404 es definitivo', (tester) async {
      await mostrar(
        tester,
        cambiar: (_, _) async => throw const ApiException(
          statusCode: 404,
          codigo: 'NO_ENCONTRADO',
          mensaje: 'x',
        ),
      );
      await tester.pump();
      await elegirYConfirmar(tester, 3);
      await tester.pump();

      expect(
        aviso(tester),
        'No encontramos esta reserva. Volvé a Mis reservas.',
      );
      expect(botonConfirmar(tester).onPressed, isNull);
    });
  });

  testWidgets('una falla sin respuesta no afirma nada y permite reintentar', (
    tester,
  ) async {
    var llamadas = 0;
    await mostrar(
      tester,
      cambiar: (_, _) async {
        llamadas++;
        if (llamadas == 1) throw Exception('sin red');
        return reserva(orden: 3);
      },
    );
    await tester.pump();
    await elegirYConfirmar(tester, 3);
    await tester.pump();

    expect(
      aviso(tester),
      'No pudimos confirmar el cambio. Revisá Mis reservas o volvé a intentar.',
    );
    expect(botonConfirmar(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('confirmar-cambio-parada')));
    await tester.pump();
    await tester.pump();
    expect(llamadas, 2);
    expect(find.text('Cambiaste tu parada'), findsOneWidget);
  });

  testWidgets('si fallan las paradas permite reintentar', (tester) async {
    var llamadas = 0;
    await mostrar(
      tester,
      paradas: (_) async {
        llamadas++;
        if (llamadas == 1) throw Exception('sin red');
        return paradasDelRecorrido;
      },
      cambiar: (_, _) async => reserva(),
    );
    await tester.pump();

    expect(find.text('No pudimos cargar las paradas.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reintentar-paradas')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Plaza Belgrano'), findsOneWidget);
    expect(llamadas, 2);
  });
}
