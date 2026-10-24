import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/pasajero/perfil.dart';
import 'package:frontend/screens/pasajero/perfil_screen.dart';

Perfil perfil({String? telefono = '1155550000', String? direccion}) => Perfil(
  nombre: 'Ana',
  apellido: 'Gómez',
  dni: '30111222',
  email: 'ana@vanfull.test',
  telefono: telefono,
  direccion: direccion,
);

ApiException error(int estado, String codigo) => ApiException(
  statusCode: estado,
  codigo: codigo,
  mensaje: 'Mensaje de $codigo',
);

Future<void> mostrar(
  WidgetTester tester, {
  CargarPerfil? cargar,
  ModificarPerfil? modificar,
  VoidCallback? salir,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PerfilScreen(
        cargarPerfil: cargar ?? () async => perfil(),
        modificarPerfil: modificar ?? (cambios) async => perfil(),
        onSalir: salir ?? () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ElevatedButton guardar(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byKey(const ValueKey('guardar-perfil')));

String textoDe(WidgetTester tester, String clave) =>
    tester.widget<Text>(find.byKey(ValueKey(clave))).data!;

Future<void> escribir(WidgetTester tester, String clave, String texto) async {
  await tester.enterText(find.byKey(ValueKey(clave)), texto);
  await tester.pump();
}

void main() {
  testWidgets('muestra nombre y DNI sin edición y los datos editables', (
    tester,
  ) async {
    await mostrar(tester);

    expect(textoDe(tester, 'nombre-perfil'), 'Ana Gómez');
    expect(textoDe(tester, 'dni-perfil'), '30111222');
    expect(find.text('ana@vanfull.test'), findsOneWidget);
    expect(find.text('1155550000'), findsOneWidget);
    expect(guardar(tester).onPressed, isNull);
  });

  testWidgets('si falla la carga ofrece reintentar', (tester) async {
    var intentos = 0;
    await mostrar(
      tester,
      cargar: () async {
        intentos++;
        if (intentos == 1) throw Exception('sin red');
        return perfil();
      },
    );
    expect(find.textContaining('No pudimos cargar'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reintentar-perfil')));
    await tester.pumpAndSettle();
    expect(textoDe(tester, 'nombre-perfil'), 'Ana Gómez');
  });

  testWidgets('guarda solo los campos que cambiaron y confirma', (
    tester,
  ) async {
    Map<String, String>? enviado;
    await mostrar(
      tester,
      modificar: (cambios) async {
        enviado = cambios;
        return perfil(telefono: '1166660000', direccion: 'Mitre 123');
      },
    );

    await escribir(tester, 'telefono-perfil', ' 1166660000 ');
    await escribir(tester, 'direccion-perfil', 'Mitre 123');
    expect(guardar(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('guardar-perfil')));
    await tester.pumpAndSettle();

    expect(enviado, {'telefono': '1166660000', 'direccion': 'Mitre 123'});
    expect(find.byKey(const ValueKey('guardado')), findsOneWidget);
    expect(guardar(tester).onPressed, isNull);
  });

  testWidgets('un dato que quedaría vacío no se puede guardar', (tester) async {
    await mostrar(tester);

    await escribir(tester, 'telefono-perfil', '   ');
    expect(find.text('No puede quedar vacío.'), findsOneWidget);
    expect(guardar(tester).onPressed, isNull);
  });

  testWidgets('mientras guarda no se puede volver a tocar', (tester) async {
    final respuesta = Completer<Perfil>();
    var llamadas = 0;
    await mostrar(
      tester,
      modificar: (_) {
        llamadas++;
        return respuesta.future;
      },
    );
    await escribir(tester, 'direccion-perfil', 'Mitre 123');
    await tester.tap(find.byKey(const ValueKey('guardar-perfil')));
    await tester.pump();

    expect(find.text('Guardando…'), findsOneWidget);
    expect(guardar(tester).onPressed, isNull);
    respuesta.complete(perfil(direccion: 'Mitre 123'));
    await tester.pumpAndSettle();
    expect(llamadas, 1);
  });

  testWidgets('un rechazo del contrato muestra su motivo; una falla, no', (
    tester,
  ) async {
    Object falla = error(403, 'DATO_NO_MODIFICABLE');
    await mostrar(tester, modificar: (_) async => throw falla);
    await escribir(tester, 'direccion-perfil', 'Mitre 123');

    await tester.tap(find.byKey(const ValueKey('guardar-perfil')));
    await tester.pumpAndSettle();
    expect(textoDe(tester, 'aviso-perfil'), 'Mensaje de DATO_NO_MODIFICABLE');
    // Lo escrito se conserva para corregirlo.
    expect(find.text('Mitre 123'), findsOneWidget);
    expect(guardar(tester).onPressed, isNotNull);

    falla = Exception('sin red');
    await tester.tap(find.byKey(const ValueKey('guardar-perfil')));
    await tester.pumpAndSettle();
    expect(textoDe(tester, 'aviso-perfil'), contains('Volvé a intentar'));
  });

  testWidgets('cerrar sesión avisa a quien navega', (tester) async {
    var salio = false;
    await mostrar(tester, salir: () => salio = true);

    await tester.ensureVisible(find.byKey(const ValueKey('cerrar-sesion')));
    await tester.tap(find.byKey(const ValueKey('cerrar-sesion')));
    expect(salio, isTrue);
  });
}
