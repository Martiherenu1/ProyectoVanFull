import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/admin/abono_gestion.dart';
import 'package:frontend/screens/admin/abonos_admin_screen.dart';

AbonoGestion abono({int id = 5, String modalidad = 'IDA_VUELTA'}) =>
    AbonoGestion(
      idAbonoMensual: id,
      idPasajero: 3,
      nombre: 'Ana',
      apellido: 'Abono',
      idServicio: 2,
      tipoServicio: 'LABORAL',
      modalidad: modalidad,
      diasSemanales: 'L,M',
      estado: 'activo',
      periodos: const [
        PeriodoAbono(idPeriodoAbono: 1, periodo: '2026-11', estado: 'vigente'),
      ],
    );

/// Dobles exclusivos del test: no demuestran permisos ni integración real.
class Doble {
  Doble(this.abonos);
  List<AbonoGestion> abonos;
  final filtros = <int?>[];
  final creados = <AbonoGestionCreate>[];
  final cambios = <(int, Map<String, Object?>)>[];
  final periodos = <(int, String)>[];
  Object? errorAlCrear;
  Object? errorAlAgregarPeriodo;

  Widget pantalla() => MaterialApp(
    home: AbonosAdminScreen(
      listar: (id) async {
        filtros.add(id);
        return abonos;
      },
      listarServicios: () async => const [
        ServicioAbono(idServicio: 1, tipo: 'UNIVERSITARIO'),
        ServicioAbono(idServicio: 2, tipo: 'LABORAL'),
        ServicioAbono(idServicio: 3, tipo: 'ESPECIAL'),
      ],
      crear: (datos) async {
        if (errorAlCrear != null) throw errorAlCrear!;
        creados.add(datos);
        return abono(id: 99);
      },
      modificar: (id, c) async {
        cambios.add((id, c));
        return abono();
      },
      agregarPeriodo: (id, periodo) async {
        if (errorAlAgregarPeriodo != null) throw errorAlAgregarPeriodo!;
        periodos.add((id, periodo));
        return abono();
      },
    ),
  );
}

Future<void> abrirAlta(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('abonos-nuevo')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lista los abonos con modalidad, días, estado y períodos', (
    tester,
  ) async {
    await tester.pumpWidget(Doble([abono()]).pantalla());
    await tester.pumpAndSettle();
    expect(find.text('Ana Abono · LABORAL'), findsOneWidget);
    expect(find.textContaining('Ida y vuelta · L,M · activo'), findsOneWidget);
    expect(find.textContaining('Períodos: 2026-11'), findsOneWidget);
  });

  testWidgets('sin abonos muestra el estado vacío', (tester) async {
    await tester.pumpWidget(Doble([]).pantalla());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('abonos-vacio')), findsOneWidget);
  });

  testWidgets('si falla la carga ofrece reintentar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AbonosAdminScreen(
          listar: (_) async => throw StateError('sin red'),
          listarServicios: () async => [],
          crear: (_) async => abono(),
          modificar: (_, _) async => abono(),
          agregarPeriodo: (_, _) async => abono(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('abonos-error')), findsOneWidget);
  });

  testWidgets('buscar por pasajero manda el número', (tester) async {
    final doble = Doble([abono()]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('abonos-filtro-pasajero')),
      '3',
    );
    await tester.tap(find.byKey(const Key('abonos-buscar')));
    await tester.pumpAndSettle();
    expect(doble.filtros, [null, 3]);
  });

  testWidgets('alta: ofrece solo servicios con abono y crea', (tester) async {
    final doble = Doble([]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await abrirAlta(tester);

    await tester.enterText(find.byKey(const Key('abono-campo-pasajero')), '3');
    await tester.enterText(find.byKey(const Key('abono-campo-dias')), 'M,J');
    await tester.enterText(
      find.byKey(const Key('abono-campo-importe')),
      '45000,5',
    );
    await tester.enterText(
      find.byKey(const Key('abono-campo-periodo')),
      '2026-11',
    );
    await tester.tap(find.byKey(const Key('abono-campo-servicio')));
    await tester.pumpAndSettle();
    expect(find.text('ESPECIAL (3)'), findsNothing);
    await tester.tap(find.text('LABORAL (2)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('abono-guardar')));
    await tester.pumpAndSettle();

    final c = doble.creados.single;
    expect(c.idPasajero, 3);
    expect(c.idServicio, 2);
    expect(c.modalidad, 'IDA_VUELTA');
    expect(c.diasSemanales, 'M,J');
    expect(c.importeAcordado, 45000.5);
    expect(c.periodo, '2026-11');
    expect(find.byKey(const Key('abono-guardar')), findsNothing);
  });

  testWidgets('alta: valida campos antes de enviar', (tester) async {
    final doble = Doble([]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await abrirAlta(tester);

    await tester.enterText(find.byKey(const Key('abono-campo-pasajero')), '0');
    await tester.enterText(
      find.byKey(const Key('abono-campo-periodo')),
      '2026-13',
    );
    await tester.tap(find.byKey(const Key('abono-guardar')));
    await tester.pumpAndSettle();

    expect(find.text('Número válido'), findsOneWidget);
    expect(find.text('Campo obligatorio'), findsOneWidget); // días
    expect(find.text('Formato AAAA-MM'), findsOneWidget);
    expect(doble.creados, isEmpty);
  });

  testWidgets('alta sin elegir servicio pide elegirlo', (tester) async {
    final doble = Doble([]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await abrirAlta(tester);
    await tester.enterText(find.byKey(const Key('abono-campo-pasajero')), '3');
    await tester.enterText(find.byKey(const Key('abono-campo-dias')), 'L');
    await tester.tap(find.byKey(const Key('abono-guardar')));
    await tester.pumpAndSettle();
    expect(find.text('Elegí un servicio.'), findsOneWidget);
    expect(doble.creados, isEmpty);
  });

  testWidgets('un 409 de servicio sin abono se explica y deja el diálogo', (
    tester,
  ) async {
    final doble = Doble([])
      ..errorAlCrear = const ApiException(
        statusCode: 409,
        codigo: 'SERVICIO_SIN_ABONO',
        mensaje: 'x',
      );
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await abrirAlta(tester);
    await tester.enterText(find.byKey(const Key('abono-campo-pasajero')), '3');
    await tester.enterText(find.byKey(const Key('abono-campo-dias')), 'L');
    await tester.tap(find.byKey(const Key('abono-campo-servicio')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LABORAL (2)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('abono-guardar')));
    await tester.pumpAndSettle();

    expect(
      find.text('Solo los servicios universitarios y laborales tienen abono.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('abono-guardar')), findsOneWidget);
  });

  testWidgets('modificar manda solo lo que cambió', (tester) async {
    final doble = Doble([abono()]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('abono-editar-5')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('abono-mod-dias')), 'V');
    await tester.tap(find.byKey(const Key('abono-mod-guardar')));
    await tester.pumpAndSettle();

    expect(doble.cambios.single.$1, 5);
    expect(doble.cambios.single.$2, {'dias_semanales': 'V'});
  });

  testWidgets('modificar sin cambios no llama a la API', (tester) async {
    final doble = Doble([abono()]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('abono-editar-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('abono-mod-guardar')));
    await tester.pumpAndSettle();
    expect(doble.cambios, isEmpty);
    expect(find.byKey(const Key('abono-mod-guardar')), findsNothing);
  });

  testWidgets('agregar período valida el formato y lo manda', (tester) async {
    final doble = Doble([abono()]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('abono-periodo-5')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('periodo-campo')), '2026-13');
    await tester.tap(find.byKey(const Key('periodo-guardar')));
    await tester.pumpAndSettle();
    expect(find.text('Formato AAAA-MM'), findsOneWidget);
    expect(doble.periodos, isEmpty);

    await tester.enterText(find.byKey(const Key('periodo-campo')), '2026-12');
    await tester.tap(find.byKey(const Key('periodo-guardar')));
    await tester.pumpAndSettle();
    expect(doble.periodos.single, (5, '2026-12'));
  });

  testWidgets('un período repetido se explica', (tester) async {
    final doble = Doble([abono()])
      ..errorAlAgregarPeriodo = const ApiException(
        statusCode: 409,
        codigo: 'PERIODO_DUPLICADO',
        mensaje: 'x',
      );
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('abono-periodo-5')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('periodo-campo')), '2026-11');
    await tester.tap(find.byKey(const Key('periodo-guardar')));
    await tester.pumpAndSettle();
    expect(find.text('El abono ya tiene ese período.'), findsOneWidget);
  });
}
