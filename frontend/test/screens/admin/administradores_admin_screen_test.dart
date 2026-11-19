import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/admin/administrador.dart';
import 'package:frontend/screens/admin/administradores_admin_screen.dart';

Administrador admin(
  int id, {
  String estado = 'activo',
  String nombre = 'Ada',
}) => Administrador.fromJson({
  'id_cuenta_acceso': id,
  'id_persona': 70 + id,
  'nombre': nombre,
  'apellido': 'Admin',
  'dni': '3011122$id',
  'identificador_acceso': 'admin$id@vanfull.test',
  'estado': estado,
});

/// Dobles exclusivos del test: no demuestran permisos ni integración real.
class Doble {
  Doble(this.lista);
  List<Administrador> lista;
  final creados = <AdministradorCreate>[];
  final modificados = <(int, Map<String, Object?>)>[];
  final deshabilitados = <int>[];
  Object? errorAlCrear;

  Widget pantalla() => MaterialApp(
    home: AdministradoresAdminScreen(
      listar: () async => lista,
      crear: (datos) async {
        if (errorAlCrear != null) throw errorAlCrear!;
        creados.add(datos);
        final nuevo = admin(99, nombre: datos.nombre);
        lista = [...lista, nuevo];
        return nuevo;
      },
      modificar: (id, cambios) async {
        modificados.add((id, cambios));
        return lista.firstWhere((a) => a.idCuentaAcceso == id);
      },
      deshabilitar: (id) async {
        deshabilitados.add(id);
        lista = [
          for (final a in lista)
            a.idCuentaAcceso == id ? admin(id, estado: 'deshabilitado') : a,
        ];
        return lista.firstWhere((a) => a.idCuentaAcceso == id);
      },
    ),
  );
}

void main() {
  testWidgets('lista los administradores y marca los deshabilitados', (
    tester,
  ) async {
    final doble = Doble([admin(1), admin(2, estado: 'deshabilitado')]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('administrador-1')), findsOneWidget);
    expect(find.textContaining('Deshabilitado'), findsOneWidget);
    // Solo el activo ofrece deshabilitar.
    expect(
      find.byKey(const Key('administrador-deshabilitar-1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('administrador-deshabilitar-2')), findsNothing);
  });

  testWidgets('sin administradores muestra el estado vacío', (tester) async {
    await tester.pumpWidget(Doble([]).pantalla());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('administradores-vacio')), findsOneWidget);
  });

  testWidgets('si falla la carga ofrece reintentar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdministradoresAdminScreen(
          listar: () async => throw StateError('sin red'),
          crear: (_) async => admin(1),
          modificar: (_, _) async => admin(1),
          deshabilitar: (_) async => admin(1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('administradores-error')), findsOneWidget);
    expect(find.byKey(const Key('administradores-reintentar')), findsOneWidget);
  });

  testWidgets('alta: valida la contraseña y manda los datos', (tester) async {
    final doble = Doble([admin(1)]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('administradores-nuevo')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('administrador-campo-nombre')),
      'Grace',
    );
    await tester.enterText(
      find.byKey(const Key('administrador-campo-apellido')),
      'Hopper',
    );
    await tester.enterText(
      find.byKey(const Key('administrador-campo-dni')),
      '28000111',
    );
    await tester.enterText(
      find.byKey(const Key('administrador-campo-identificador')),
      'grace@vanfull.test',
    );
    await tester.enterText(
      find.byKey(const Key('administrador-campo-contrasena')),
      'corta',
    );
    await tester.tap(find.byKey(const Key('administrador-guardar')));
    await tester.pumpAndSettle();
    expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
    expect(doble.creados, isEmpty);

    await tester.enterText(
      find.byKey(const Key('administrador-campo-contrasena')),
      'clave-segura-1',
    );
    await tester.tap(find.byKey(const Key('administrador-guardar')));
    await tester.pumpAndSettle();

    expect(doble.creados.single.identificadorAcceso, 'grace@vanfull.test');
    expect(doble.creados.single.contrasena, 'clave-segura-1');
    // El diálogo se cerró y la lista se recargó con el nuevo.
    expect(find.byKey(const Key('administrador-guardar')), findsNothing);
    expect(find.byKey(const Key('administrador-99')), findsOneWidget);
  });

  testWidgets('alta con DNI duplicado muestra el error y deja el diálogo', (
    tester,
  ) async {
    final doble = Doble([])
      ..errorAlCrear = const ApiException(
        statusCode: 409,
        codigo: 'DNI_DUPLICADO',
        mensaje: 'x',
      );
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('administradores-nuevo')));
    await tester.pumpAndSettle();
    for (final (clave, texto) in [
      ('nombre', 'Grace'),
      ('apellido', 'Hopper'),
      ('dni', '28000111'),
      ('identificador', 'grace@vanfull.test'),
      ('contrasena', 'clave-segura-1'),
    ]) {
      await tester.enterText(
        find.byKey(Key('administrador-campo-$clave')),
        texto,
      );
    }
    await tester.tap(find.byKey(const Key('administrador-guardar')));
    await tester.pumpAndSettle();

    expect(find.text('Ya hay una persona con ese DNI.'), findsOneWidget);
    expect(find.byKey(const Key('administrador-guardar')), findsOneWidget);
  });

  testWidgets('modificar envía solo lo que cambió', (tester) async {
    final doble = Doble([admin(1)]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('administrador-editar-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('administrador-campo-apellido')),
      'Nuevo',
    );
    await tester.tap(find.byKey(const Key('administrador-guardar')));
    await tester.pumpAndSettle();

    expect(doble.modificados.single.$1, 1);
    expect(doble.modificados.single.$2, {'apellido': 'Nuevo'});
  });

  testWidgets('deshabilitar pide confirmación y recarga la lista', (
    tester,
  ) async {
    final doble = Doble([admin(1)]);
    await tester.pumpWidget(doble.pantalla());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('administrador-deshabilitar-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('administradores-cancelar-deshabilitar')),
    );
    await tester.pumpAndSettle();
    expect(doble.deshabilitados, isEmpty);

    await tester.tap(find.byKey(const Key('administrador-deshabilitar-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('administradores-confirmar-deshabilitar')),
    );
    await tester.pumpAndSettle();

    expect(doble.deshabilitados, [1]);
    expect(find.byKey(const Key('administrador-deshabilitar-1')), findsNothing);
    expect(find.textContaining('Deshabilitado'), findsOneWidget);
  });
}
