import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/admin/vehiculo_admin.dart';
import 'package:frontend/screens/admin/vehiculos_admin_screen.dart';

VehiculoAdmin vehiculo({
  int id = 1,
  String patente = 'VF022AA',
  int capacidad = 19,
  bool disponibilidad = true,
}) => VehiculoAdmin(
  idVehiculo: id,
  patente: patente,
  marca: 'Mercedes-Benz',
  modelo: 'Sprinter',
  capacidad: capacidad,
  disponibilidad: disponibilidad,
);

void main() {
  Future<void> mostrar(
    WidgetTester tester, {
    required Future<List<VehiculoAdmin>> Function() cargar,
    required Future<VehiculoAdmin> Function(VehiculoCreate) crear,
    required Future<VehiculoAdmin> Function(int, VehiculoUpdate) actualizar,
  }) => tester.pumpWidget(
    MaterialApp(
      home: VehiculosAdminScreen(
        cargar: cargar,
        crear: crear,
        actualizar: actualizar,
      ),
    ),
  );

  testWidgets('consulta y muestra todos los campos disponibles', (
    tester,
  ) async {
    await mostrar(
      tester,
      cargar: () async => [vehiculo()],
      crear: (_) async => vehiculo(),
      actualizar: (_, _) async => vehiculo(),
    );
    await tester.pumpAndSettle();
    expect(find.text('VF022AA'), findsOneWidget);
    expect(find.textContaining('Mercedes-Benz Sprinter'), findsOneWidget);
    expect(find.textContaining('Capacidad: 19 · Disponible'), findsOneWidget);
    expect(find.textContaining('document'), findsNothing);
  });

  testWidgets('registra un vehículo y lo agrega al listado', (tester) async {
    VehiculoCreate? recibido;
    await mostrar(
      tester,
      cargar: () async => [],
      crear: (datos) async {
        recibido = datos;
        return vehiculo(
          id: 2,
          patente: datos.patente,
          capacidad: datos.capacidad,
        );
      },
      actualizar: (_, _) async => vehiculo(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('registrar-vehiculo')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('vehiculo-patente')),
      'VF022BB',
    );
    await tester.enterText(find.byKey(const Key('vehiculo-marca')), 'Iveco');
    await tester.enterText(find.byKey(const Key('vehiculo-modelo')), 'Daily');
    await tester.enterText(find.byKey(const Key('vehiculo-capacidad')), '24');
    await tester.tap(find.byKey(const Key('guardar-vehiculo')));
    await tester.pumpAndSettle();
    expect(recibido?.patente, 'VF022BB');
    expect(recibido?.capacidad, 24);
    expect(recibido?.disponibilidad, isTrue);
    expect(find.text('VF022BB'), findsOneWidget);
  });

  testWidgets('modifica capacidad y disponibilidad sin tocar viajes', (
    tester,
  ) async {
    int? idRecibido;
    VehiculoUpdate? recibido;
    await mostrar(
      tester,
      cargar: () async => [vehiculo()],
      crear: (_) async => vehiculo(),
      actualizar: (id, datos) async {
        idRecibido = id;
        recibido = datos;
        return vehiculo(
          capacidad: datos.capacidad,
          disponibilidad: datos.disponibilidad,
        );
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editar-vehiculo-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('vehiculo-capacidad')), '20');
    await tester.tap(find.byType(Switch));
    await tester.tap(find.byKey(const Key('guardar-vehiculo')));
    await tester.pumpAndSettle();
    expect(idRecibido, 1);
    expect(recibido?.capacidad, 20);
    expect(recibido?.disponibilidad, isFalse);
    expect(
      find.textContaining('Capacidad: 20 · No disponible'),
      findsOneWidget,
    );
  });

  testWidgets('valida patente y capacidad antes de llamar al backend', (
    tester,
  ) async {
    var llamadas = 0;
    await mostrar(
      tester,
      cargar: () async => [],
      crear: (_) async {
        llamadas++;
        return vehiculo();
      },
      actualizar: (_, _) async => vehiculo(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('registrar-vehiculo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('vehiculo-capacidad')), '0');
    await tester.tap(find.byKey(const Key('guardar-vehiculo')));
    await tester.pump();
    expect(find.text('Este campo es obligatorio.'), findsOneWidget);
    expect(find.text('Indicá una capacidad mayor que cero.'), findsOneWidget);
    expect(llamadas, 0);
  });
}
