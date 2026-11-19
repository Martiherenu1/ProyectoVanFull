import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/admin/tarifa_gestion.dart';
import 'package:frontend/screens/admin/tarifas_admin_screen.dart';

TarifaGestion tarifa(
  int id, {
  String nombre = 'Universitario ida',
  double importe = 1500.5,
  String? tipo = 'OCASIONAL',
  String? vigencia,
}) => TarifaGestion.fromJson({
  'id_tarifa': id,
  'nombre': nombre,
  'tipo': ?tipo,
  'importe': importe,
  'fecha_creacion': '2026-11-18',
  'fecha_vigencia': ?vigencia,
});

/// Dobles exclusivos del test: no demuestran permisos ni integración real.
class Doble {
  Doble(this.lista);
  List<TarifaGestion> lista;
  final creadas = <TarifaGestionCreate>[];
  final modificadas = <(int, Map<String, Object?>)>[];
  Object? errorAlCrear;

  Widget pantalla() => MaterialApp(
    home: TarifasAdminScreen(
      listar: () async => lista,
      crear: (datos) async {
        if (errorAlCrear != null) throw errorAlCrear!;
        creadas.add(datos);
        final nueva = tarifa(99, nombre: datos.nombre, importe: datos.importe);
        lista = [...lista, nueva];
        return nueva;
      },
      modificar: (id, cambios) async {
        modificadas.add((id, cambios));
        return lista.firstWhere((t) => t.idTarifa == id);
      },
    ),
  );
}

void main() {
  testWidgets('lista las tarifas con importe, tipo y vigencia', (tester) async {
    await tester.pumpWidget(
      Doble([tarifa(1, vigencia: '2026-12-01'), tarifa(2, tipo: null)])
          .pantalla(),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tarifa-1')), findsOneWidget);
    expect(
      find.textContaining('\$ 1500.50 · OCASIONAL · vigencia 2026-12-01'),
      findsOneWidget,
    );
    expect(find.text('\$ 1500.50'), findsOneWidget);
  });

  testWidgets('sin tarifas muestra el estado vacío', (tester) async {
    await tester.pumpWidget(Doble([]).pantalla());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tarifas-vacio')), findsOneWidget);
  });

  testWidgets('si falla la carga ofrece reintentar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TarifasAdminScreen(
          listar: () async => throw StateError('sin red'),
          crear: (_) async => tarifa(1),
          modificar: (_, _) async => tarifa(1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tarifas-error')), findsOneWidget);
    expect(find.byKey(const Key('tarifas-reintentar')), findsOneWidget);
  });

  testWidgets('alta: valida el importe y acepta coma decimal', (tester) async {
    final doble = Doble([]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tarifas-nueva')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('tarifa-campo-nombre')),
      'Laboral vuelta',
    );
    for (final importe in ['10,123', '10000000000']) {
      await tester.enterText(
        find.byKey(const Key('tarifa-campo-importe')),
        importe,
      );
      await tester.tap(find.byKey(const Key('tarifa-guardar')));
      await tester.pumpAndSettle();
      expect(
        find.text('Importe válido, con hasta 2 decimales'),
        findsOneWidget,
      );
      expect(doble.creadas, isEmpty);
    }

    await tester.enterText(
      find.byKey(const Key('tarifa-campo-importe')),
      '1200,50',
    );
    await tester.tap(find.byKey(const Key('tarifa-guardar')));
    await tester.pumpAndSettle();

    expect(doble.creadas.single.importe, 1200.5);
    expect(doble.creadas.single.nombre, 'Laboral vuelta');
    expect(find.byKey(const Key('tarifa-guardar')), findsNothing);
    expect(find.byKey(const Key('tarifa-99')), findsOneWidget);
  });

  testWidgets('la vigencia debe ser una fecha válida en formato ISO', (
    tester,
  ) async {
    final doble = Doble([]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tarifas-nueva')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tarifa-campo-nombre')), 'A');
    await tester.enterText(find.byKey(const Key('tarifa-campo-importe')), '10');
    for (final fecha in ['1/12/2026', '2026-02-30', '0000-01-01']) {
      await tester.enterText(
        find.byKey(const Key('tarifa-campo-vigencia')),
        fecha,
      );
      await tester.tap(find.byKey(const Key('tarifa-guardar')));
      await tester.pumpAndSettle();
      expect(find.text('Formato AAAA-MM-DD'), findsOneWidget);
      expect(doble.creadas, isEmpty);
    }

    await tester.enterText(
      find.byKey(const Key('tarifa-campo-vigencia')),
      '2028-02-29',
    );
    await tester.tap(find.byKey(const Key('tarifa-guardar')));
    await tester.pumpAndSettle();
    expect(doble.creadas.single.fechaVigencia, '2028-02-29');
  });

  testWidgets('un error del backend se muestra y deja el diálogo', (
    tester,
  ) async {
    final doble = Doble([])
      ..errorAlCrear = const ApiException(
        statusCode: 403,
        codigo: 'SIN_PERMISO',
        mensaje: 'x',
      );
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tarifas-nueva')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tarifa-campo-nombre')), 'A');
    await tester.enterText(find.byKey(const Key('tarifa-campo-importe')), '10');
    await tester.tap(find.byKey(const Key('tarifa-guardar')));
    await tester.pumpAndSettle();
    expect(find.text('Solo el dueño puede gestionar tarifas.'), findsOneWidget);
    expect(find.byKey(const Key('tarifa-guardar')), findsOneWidget);
  });

  testWidgets('modificar envía solo lo que cambió y vacía con null', (
    tester,
  ) async {
    final doble = Doble([tarifa(1, vigencia: '2026-12-01')]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tarifa-editar-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('tarifa-campo-importe')),
      '2000',
    );
    await tester.enterText(find.byKey(const Key('tarifa-campo-vigencia')), '');
    await tester.tap(find.byKey(const Key('tarifa-guardar')));
    await tester.pumpAndSettle();

    expect(doble.modificadas.single.$1, 1);
    expect(doble.modificadas.single.$2, {
      'importe': 2000.0,
      'fecha_vigencia': null,
    });
  });

  testWidgets('modificar sin cambios no llama al backend', (tester) async {
    final doble = Doble([tarifa(1)]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tarifa-editar-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tarifa-guardar')));
    await tester.pumpAndSettle();
    expect(doble.modificadas, isEmpty);
  });
}
