import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';
import 'package:frontend/models/pasajero/disponibilidad_viaje.dart';
import 'package:frontend/models/pasajero/parada.dart';
import 'package:frontend/screens/pasajero/buscar_servicio_screen.dart';

DisponibilidadViaje viaje(
  int id, {
  String? horario = '06:15',
  int? cupo = 14,
  int recorrido = 3,
}) => DisponibilidadViaje.fromJson({
  'id_viaje': id,
  'id_servicio': 2,
  'id_recorrido': recorrido,
  'fecha': '2026-10-30',
  'horario': ?horario,
  'sentido': 'IDA',
  'cupo_disponible': ?cupo,
});

Parada parada(int orden, String? nombre, {String? direccion}) =>
    Parada.fromJson({
      'id_parada': orden * 10,
      'orden': orden,
      'nombre_descripcion': ?nombre,
      'direccion': ?direccion,
      'comprometida': true,
    });

Future<void> mostrar(
  WidgetTester tester, {
  required CargarDisponibilidad disponibilidad,
  CargarParadas? paradas,
  ValueChanged<DisponibilidadViaje>? reservar,
}) => tester.pumpWidget(
  MaterialApp(
    home: BuscarServicioScreen(
      fechaInicial: DateTime(2026, 10, 30, 15),
      cargarDisponibilidad: disponibilidad,
      cargarParadas: paradas ?? (_) async => const [],
      onReservar: reservar ?? (_) {},
    ),
  ),
);

void main() {
  testWidgets('carga con fecha y sentido explícitos, y muestra el cupo', (
    tester,
  ) async {
    DateTime? fecha;
    SentidoViaje? sentido;
    await mostrar(
      tester,
      disponibilidad: (f, s) async {
        fecha = f;
        sentido = s;
        return [viaje(1), viaje(2, horario: '07:30', cupo: 1)];
      },
    );
    await tester.pump();

    expect(fecha, DateTime(2026, 10, 30));
    expect(sentido, SentidoViaje.ida);
    expect(find.text('06:15'), findsOneWidget);
    expect(find.text('14 lugares'), findsOneWidget);
    expect(find.text('1 lugar'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('cantidad-viajes'))).data,
      '2',
    );
  });

  testWidgets('mientras carga muestra un esqueleto y no un spinner', (
    tester,
  ) async {
    final pendiente = Completer<List<DisponibilidadViaje>>();
    await mostrar(tester, disponibilidad: (_, _) => pendiente.future);

    expect(find.bySemanticsLabel('Cargando viajes'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('cantidad-viajes'))).data,
      '–',
    );
  });

  testWidgets('sin viajes explica qué falta y ofrece cambiar la fecha', (
    tester,
  ) async {
    await mostrar(tester, disponibilidad: (_, _) async => const []);
    await tester.pump();

    expect(
      find.text('No hay viajes ida para el 30/10/2026. Probá con otra fecha.'),
      findsOneWidget,
    );
    expect(find.text('Cambiar fecha'), findsOneWidget);
  });

  testWidgets('cupo 0 se lee como texto y en rojo', (tester) async {
    await mostrar(tester, disponibilidad: (_, _) async => [viaje(1, cupo: 0)]);
    await tester.pump();

    final texto = tester.widget<Text>(find.text('Sin cupo'));
    expect(texto.style?.color, AppColors.alertDark);
  });

  testWidgets('cupo ausente no se muestra como cero', (tester) async {
    await mostrar(
      tester,
      disponibilidad: (_, _) async => [viaje(1, cupo: null)],
    );
    await tester.pump();

    expect(find.text('Cupo a confirmar'), findsOneWidget);
    expect(find.text('Sin cupo'), findsNothing);
  });

  testWidgets('un error permite reintentar', (tester) async {
    var llamadas = 0;
    await mostrar(
      tester,
      disponibilidad: (_, _) async {
        llamadas++;
        if (llamadas == 1) throw Exception('sin red');
        return [viaje(1)];
      },
    );
    await tester.pump();

    expect(
      find.text('No pudimos cargar los viajes. Volvé a intentar.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();

    expect(llamadas, 2);
    expect(find.text('06:15'), findsOneWidget);
  });

  testWidgets('cambiar el sentido vuelve a consultar con VUELTA', (
    tester,
  ) async {
    final sentidos = <SentidoViaje>[];
    await mostrar(
      tester,
      disponibilidad: (_, s) async {
        sentidos.add(s);
        return const [];
      },
    );
    await tester.pump();

    await tester.tap(find.text('Vuelta'));
    await tester.pump();
    await tester.pump();

    expect(sentidos, [SentidoViaje.ida, SentidoViaje.vuelta]);
    expect(find.textContaining('VUELTA'), findsOneWidget);
  });

  testWidgets('una respuesta vieja no pisa a la más nueva', (tester) async {
    final primera = Completer<List<DisponibilidadViaje>>();
    final segunda = Completer<List<DisponibilidadViaje>>();
    final pendientes = [primera, segunda];
    await mostrar(
      tester,
      disponibilidad: (_, _) => pendientes.removeAt(0).future,
    );

    await tester.tap(find.text('Vuelta'));
    await tester.pump();

    segunda.complete([viaje(2, horario: '18:20')]);
    await tester.pump();
    primera.complete([viaje(1, horario: '05:40')]);
    await tester.pump();

    expect(find.text('18:20'), findsOneWidget);
    expect(find.text('05:40'), findsNothing);
  });

  testWidgets('tocar un viaje muestra sus paradas en orden', (tester) async {
    int? pedido;
    await mostrar(
      tester,
      disponibilidad: (_, _) async => [viaje(1, recorrido: 9)],
      paradas: (id) async {
        pedido = id;
        return [
          parada(2, 'Plaza Belgrano', direccion: 'Belgrano 100'),
          parada(1, null, direccion: 'Av. San Martín 1240'),
        ];
      },
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('viaje-1')));
    await tester.pump();
    await tester.pump();

    expect(pedido, 9);
    expect(find.text('Plaza Belgrano'), findsOneWidget);
    expect(find.text('Belgrano 100'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Av. San Martín 1240')).dy,
      lessThan(tester.getTopLeft(find.text('Plaza Belgrano')).dy),
    );
  });

  testWidgets('las paradas de un recorrido se piden una sola vez', (
    tester,
  ) async {
    var pedidos = 0;
    await mostrar(
      tester,
      disponibilidad: (_, _) async => [viaje(1)],
      paradas: (_) async {
        pedidos++;
        return [parada(1, 'Plaza Belgrano')];
      },
    );
    await tester.pump();

    final fila = find.byKey(const ValueKey('viaje-1'));
    await tester.tap(fila);
    await tester.pump();
    await tester.tap(fila);
    await tester.pump();
    await tester.tap(fila);
    await tester.pump();

    expect(pedidos, 1);
  });

  testWidgets('si fallan las paradas se puede reintentar', (tester) async {
    var llamadas = 0;
    await mostrar(
      tester,
      disponibilidad: (_, _) async => [viaje(1)],
      paradas: (_) async {
        llamadas++;
        if (llamadas == 1) throw Exception('sin red');
        return [parada(1, 'Plaza Belgrano')];
      },
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('viaje-1')));
    await tester.pump();
    await tester.pump();

    expect(find.text('No pudimos cargar las paradas.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reintentar-paradas')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Plaza Belgrano'), findsOneWidget);
  });

  testWidgets('reservar entrega el viaje elegido', (tester) async {
    DisponibilidadViaje? elegido;
    await mostrar(
      tester,
      disponibilidad: (_, _) async => [viaje(1), viaje(2, horario: '07:30')],
      reservar: (v) => elegido = v,
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('viaje-2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reservar-viaje')));

    expect(elegido?.idViaje, 2);
  });

  testWidgets('un viaje sin cupo no se puede reservar', (tester) async {
    DisponibilidadViaje? elegido;
    await mostrar(
      tester,
      disponibilidad: (_, _) async => [viaje(1, cupo: 0)],
      reservar: (v) => elegido = v,
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('viaje-1')));
    await tester.pump();

    final boton = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('reservar-viaje')),
    );
    expect(boton.onPressed, isNull);
    expect(find.text('Sin cupo en este viaje'), findsOneWidget);
    expect(elegido, isNull);
  });
}
