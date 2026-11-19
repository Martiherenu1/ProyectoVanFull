import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/admin/historial_viaje.dart';
import 'package:frontend/screens/admin/historial_viajes_screen.dart';

HistorialViaje viaje(int id, {String estado = 'finalizado'}) => HistorialViaje(
  idViaje: id,
  fecha: '2026-03-10',
  horario: '07:30',
  sentido: 'IDA',
  estado: estado,
  tipoServicio: 'LABORAL',
  idRecorrido: 2,
  chofer: const PersonaHistorial(
    idPersona: 4,
    nombre: 'Carla',
    apellido: 'Ruta',
  ),
  patente: 'AB123CD',
);

HistorialViajeDetalle detalleDe(int id) => HistorialViajeDetalle(
  viaje: viaje(id),
  capacidadPlanificada: 10,
  paradas: const [
    ParadaHistorial(orden: 1, idParada: 5, nombre: 'Plaza'),
    ParadaHistorial(orden: 2, idParada: 6),
  ],
  conteos: const ConteosHistorial(
    provisionales: 1,
    consolidadas: 2,
    canceladas: 3,
    abordajes: 4,
    ausencias: 5,
  ),
);

/// Dobles exclusivos del test: no demuestran permisos ni integración real.
class Doble {
  Doble(this.viajes);
  List<HistorialViaje> viajes;
  final consultas = <HistorialFiltros>[];
  Object? errorAlListar;
  Object? errorEnDetalle;

  Widget pantalla() => MaterialApp(
    home: HistorialViajesScreen(
      listar: (f) async {
        consultas.add(f);
        if (errorAlListar != null) throw errorAlListar!;
        return viajes;
      },
      detalle: (id) async {
        if (errorEnDetalle != null) throw errorEnDetalle!;
        return detalleDe(id);
      },
    ),
  );
}

void main() {
  testWidgets('al abrir lista los viajes sin criterios', (tester) async {
    final doble = Doble([viaje(7)]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('historial-viaje-7')), findsOneWidget);
    expect(find.textContaining('2026-03-10 07:30 · Ida'), findsOneWidget);
    expect(find.textContaining('Carla Ruta'), findsOneWidget);
    expect(doble.consultas.single.toQuery(), isEmpty);
  });

  testWidgets('sin resultados informa que no se encontraron registros', (
    tester,
  ) async {
    await tester.pumpWidget(Doble([]).pantalla());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('historial-vacio')), findsOneWidget);
    expect(find.text('No se encontraron registros.'), findsOneWidget);
  });

  testWidgets('si falla la carga ofrece reintentar', (tester) async {
    final doble = Doble([viaje(7)])..errorAlListar = StateError('sin red');
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('historial-error')), findsOneWidget);

    doble.errorAlListar = null;
    await tester.tap(find.byKey(const Key('historial-reintentar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('historial-viaje-7')), findsOneWidget);
  });

  testWidgets('buscar manda estado y sentido elegidos', (tester) async {
    final doble = Doble([viaje(7)]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('historial-estado')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelado').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('historial-sentido')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vuelta').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('historial-buscar')));
    await tester.pumpAndSettle();

    expect(doble.consultas, hasLength(2));
    expect(doble.consultas.last.estado, 'cancelado');
    expect(doble.consultas.last.sentido, 'VUELTA');
  });

  testWidgets('elegir una fecha la manda como criterio', (tester) async {
    final doble = Doble([]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('historial-desde')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Desde 20'), findsOneWidget);

    await tester.tap(find.byKey(const Key('historial-buscar')));
    await tester.pumpAndSettle();
    expect(doble.consultas.last.desde, isNotNull);
  });

  testWidgets('seleccionar un viaje muestra su información operativa', (
    tester,
  ) async {
    await tester.pumpWidget(Doble([viaje(7)]).pantalla());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('historial-viaje-7')));
    await tester.pumpAndSettle();

    expect(find.text('Viaje 7'), findsOneWidget);
    expect(find.byKey(const Key('dato-Chofer')), findsOneWidget);
    expect(find.text('Carla Ruta'), findsOneWidget);
    expect(find.text('AB123CD'), findsOneWidget);
    expect(find.text('Plaza'), findsOneWidget);
    expect(find.text('Parada 6'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('dato-Reservas consolidadas')))
          .data,
      '2',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('dato-Ausencias'))).data,
      '5',
    );
  });

  testWidgets('un 404 en el detalle se explica y deja reintentar', (
    tester,
  ) async {
    final doble = Doble([viaje(7)])
      ..errorEnDetalle = const ApiException(
        statusCode: 404,
        codigo: 'VIAJE_NO_ENCONTRADO',
        mensaje: 'x',
      );
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('historial-viaje-7')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detalle-error')), findsOneWidget);
    expect(
      find.text('Ese viaje ya no figura en el historial.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('detalle-reintentar')), findsOneWidget);
  });
}
