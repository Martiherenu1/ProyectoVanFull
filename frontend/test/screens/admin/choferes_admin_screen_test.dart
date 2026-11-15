import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/admin/chofer_admin.dart';
import 'package:frontend/screens/admin/choferes_admin_screen.dart';

ChoferAdmin _chofer({String nombre = 'Ana'}) => ChoferAdmin(
  idPersona: 7,
  nombre: nombre,
  apellido: 'Pérez',
  dni: '21000001',
  direccion: 'Calle 1',
  telefono: '1122334455',
  email: 'ana@vanfull.test',
  cuil: '27-21000001-1',
  registroConducir: 'REG-21',
  fechaVencimientoRegistro: DateTime(2028, 6, 30),
);

Future<void> _mostrar(
  WidgetTester tester, {
  List<ChoferAdmin>? choferes,
  CrearChofer? crear,
  ActualizarChofer? actualizar,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ChoferesAdminScreen(
        cargar: () async => choferes ?? [_chofer()],
        crear: crear ?? (_) async => _chofer(),
        actualizar: actualizar ?? (_, _) async => _chofer(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('consulta los datos administrativos existentes', (tester) async {
    await _mostrar(tester);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.textContaining('DNI: 21000001'), findsOneWidget);
    expect(find.textContaining('REG-21'), findsOneWidget);
    expect(find.textContaining('30/06/2028'), findsOneWidget);
    expect(find.textContaining('Cuenta'), findsNothing);
    expect(find.textContaining('Estado'), findsNothing);
  });

  testWidgets('registra sin pedir cuenta ni documentación nueva', (tester) async {
    ChoferAdminCreate? enviada;
    await _mostrar(
      tester,
      choferes: [],
      crear: (datos) async {
        enviada = datos;
        return _chofer();
      },
    );
    await tester.tap(find.byKey(const Key('registrar-chofer')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chofer-nombre')), 'Ana');
    await tester.enterText(find.byKey(const Key('chofer-apellido')), 'Pérez');
    await tester.enterText(find.byKey(const Key('chofer-dni')), '21000001');
    await tester.enterText(find.byKey(const Key('chofer-registro')), 'REG-21');
    await tester.enterText(
      find.byKey(const Key('chofer-vencimiento')),
      '2028-06-30',
    );
    await tester.tap(find.byKey(const Key('guardar-chofer')));
    await tester.pumpAndSettle();
    expect(enviada?.dni, '21000001');
    expect(enviada?.registroConducir, 'REG-21');
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.textContaining('Cuenta'), findsNothing);
    expect(find.textContaining('Documentación'), findsNothing);
  });

  testWidgets('modifica Persona y Chofer existentes', (tester) async {
    ChoferAdminUpdate? enviada;
    await _mostrar(
      tester,
      actualizar: (id, datos) async {
        expect(id, 7);
        enviada = datos;
        return _chofer(nombre: 'Andrea');
      },
    );
    await tester.tap(find.byKey(const Key('editar-chofer-7')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chofer-nombre')), 'Andrea');
    await tester.tap(find.byKey(const Key('guardar-chofer')));
    await tester.pumpAndSettle();
    expect(enviada?.nombre, 'Andrea');
    expect(find.text('Andrea Pérez'), findsOneWidget);
  });

  testWidgets('valida obligatorios y fecha antes de enviar', (tester) async {
    var llamadas = 0;
    await _mostrar(
      tester,
      choferes: [],
      crear: (datos) async {
        llamadas++;
        return _chofer();
      },
    );
    await tester.tap(find.byKey(const Key('registrar-chofer')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chofer-vencimiento')),
      '30/06/2028',
    );
    await tester.tap(find.byKey(const Key('guardar-chofer')));
    await tester.pumpAndSettle();
    expect(find.text('Este campo es obligatorio.'), findsNWidgets(3));
    expect(find.text('Usá el formato AAAA-MM-DD.'), findsOneWidget);
    expect(llamadas, 0);
  });
}
