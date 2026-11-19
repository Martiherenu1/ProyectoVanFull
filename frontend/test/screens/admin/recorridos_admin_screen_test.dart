import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/admin/recorrido_gestion.dart';
import 'package:frontend/screens/admin/recorridos_admin_screen.dart';

ParadaCatalogo cat(int id, String nombre) =>
    ParadaCatalogo(idParada: id, nombre: nombre);

ParadaDeRecorrido enRec(
  int orden,
  int id,
  String nombre, {
  bool comprometida = false,
}) => ParadaDeRecorrido(
  orden: orden,
  idParada: id,
  nombre: nombre,
  comprometida: comprometida,
);

/// Dobles exclusivos del test: no demuestran permisos ni integración real.
class Doble {
  Doble(this.recorridos, [List<ParadaCatalogo>? catalogo])
    : catalogo =
          catalogo ?? [cat(1, 'A'), cat(2, 'B'), cat(3, 'C'), cat(4, 'D')];
  List<RecorridoGestion> recorridos;
  List<ParadaCatalogo> catalogo;
  final creados = <List<int>>[];
  final reemplazos = <(int, List<int>)>[];
  final paradasCreadas = <ParadaCatalogoCreate>[];
  Object? errorAlReemplazar;

  Widget pantalla() => MaterialApp(
    home: RecorridosAdminScreen(
      listar: () async => recorridos,
      listarParadas: () async => catalogo,
      crearParada: (datos) async {
        paradasCreadas.add(datos);
        return ParadaCatalogo(idParada: 50, nombre: datos.nombre);
      },
      crear: (ids) async {
        creados.add(ids);
        return RecorridoGestion(idRecorrido: 99, paradas: const []);
      },
      reemplazar: (id, ids) async {
        if (errorAlReemplazar != null) throw errorAlReemplazar!;
        reemplazos.add((id, ids));
        return recorridos.firstWhere((r) => r.idRecorrido == id);
      },
    ),
  );
}

RecorridoGestion recorrido() => RecorridoGestion(
  idRecorrido: 5,
  paradas: [
    enRec(1, 1, 'A'),
    enRec(2, 2, 'B', comprometida: true),
    enRec(3, 3, 'C'),
  ],
);

void main() {
  testWidgets('lista los recorridos con sus paradas en orden', (tester) async {
    await tester.pumpWidget(Doble([recorrido()]).pantalla());
    await tester.pumpAndSettle();
    expect(find.text('Recorrido 5'), findsOneWidget);
    expect(find.text('A → B → C'), findsOneWidget);
  });

  testWidgets('sin recorridos muestra el estado vacío', (tester) async {
    await tester.pumpWidget(Doble([]).pantalla());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recorridos-vacio')), findsOneWidget);
  });

  testWidgets('si falla la carga ofrece reintentar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecorridosAdminScreen(
          listar: () async => throw StateError('sin red'),
          listarParadas: () async => [],
          crearParada: (_) async => cat(1, 'A'),
          crear: (_) async => recorrido(),
          reemplazar: (_, _) async => recorrido(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recorridos-error')), findsOneWidget);
  });

  testWidgets('alta: agrega paradas del catálogo y crea en el orden elegido', (
    tester,
  ) async {
    final doble = Doble([]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recorridos-nuevo')));
    await tester.pumpAndSettle();

    // Sin paradas no se puede guardar.
    expect(find.byKey(const Key('editor-sin-paradas')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('editor-guardar')))
          .onPressed,
      isNull,
    );

    for (final id in [3, 1]) {
      await tester.tap(find.byKey(const Key('editor-agregar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('editor-opcion-$id')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('editor-guardar')));
    await tester.pumpAndSettle();

    expect(doble.creados.single, [3, 1]);
    expect(
      find.byKey(const Key('recorrido-99')),
      findsNothing,
    ); // volvió a la lista
    expect(find.byKey(const Key('editor-guardar')), findsNothing);
  });

  testWidgets('alta: permite guardar un recorrido con una sola parada', (
    tester,
  ) async {
    final doble = Doble([]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recorridos-nuevo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editor-agregar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editor-opcion-2')));
    await tester.pumpAndSettle();

    final guardar = find.byKey(const Key('editor-guardar'));
    expect(tester.widget<FilledButton>(guardar).onPressed, isNotNull);
    await tester.tap(guardar);
    await tester.pumpAndSettle();

    expect(doble.creados, [
      [2],
    ]);
    expect(guardar, findsNothing);
  });

  testWidgets('una parada ya elegida no se ofrece de nuevo', (tester) async {
    await tester.pumpWidget(Doble([]).pantalla());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recorridos-nuevo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editor-agregar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editor-opcion-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editor-agregar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('editor-opcion-2')), findsNothing);
    expect(find.byKey(const Key('editor-opcion-1')), findsOneWidget);
  });

  testWidgets('la comprometida no se quita ni se mueve, ni deja pasar a otra', (
    tester,
  ) async {
    final doble = Doble([recorrido()]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recorrido-editar-5')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('editor-candado')), findsOneWidget);
    expect(find.text('Comprometida (RN-021)'), findsOneWidget);
    expect(find.byKey(const Key('editor-quitar-1')), findsNothing);
    // A (orden 1) no puede bajar cruzando a la comprometida; C (orden 3) tampoco subir.
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('editor-bajar-0')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('editor-subir-2')))
          .onPressed,
      isNull,
    );
    // Sin cambios, no se puede guardar.
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('editor-guardar')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('modificar: quitar una libre y guardar manda el nuevo orden', (
    tester,
  ) async {
    final doble = Doble([recorrido()]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recorrido-editar-5')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editor-quitar-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editor-guardar')));
    await tester.pumpAndSettle();

    expect(doble.reemplazos.single.$1, 5);
    expect(doble.reemplazos.single.$2, [1, 2]);
  });

  testWidgets('un 409 por comprometida se explica y deja el editor abierto', (
    tester,
  ) async {
    final doble = Doble([recorrido()])
      ..errorAlReemplazar = const ApiException(
        statusCode: 409,
        codigo: 'PARADA_COMPROMETIDA',
        mensaje: 'x',
      );
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recorrido-editar-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editor-quitar-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editor-guardar')));
    await tester.pumpAndSettle();

    expect(find.textContaining('parada comprometida'), findsOneWidget);
    expect(find.byKey(const Key('editor-guardar')), findsOneWidget);
  });

  testWidgets('nueva parada: valida coordenadas y la suma al recorrido', (
    tester,
  ) async {
    final doble = Doble([]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recorridos-nuevo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editor-nueva-parada')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('parada-campo-nombre')),
      'Estación',
    );
    await tester.enterText(
      find.byKey(const Key('parada-campo-latitud')),
      '-34,6',
    );
    await tester.tap(find.byKey(const Key('parada-guardar')));
    await tester.pumpAndSettle();
    expect(find.text('Informá latitud y longitud, o ninguna'), findsWidgets);
    expect(doble.paradasCreadas, isEmpty);

    await tester.enterText(
      find.byKey(const Key('parada-campo-longitud')),
      '-58,4',
    );
    await tester.tap(find.byKey(const Key('parada-guardar')));
    await tester.pumpAndSettle();

    expect(doble.paradasCreadas.single.latitud, -34.6);
    expect(doble.paradasCreadas.single.longitud, -58.4);
    expect(find.byKey(const Key('editor-parada-0')), findsOneWidget);
    expect(find.text('Estación'), findsOneWidget);
  });
}
