import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/session/sesion.dart';
import 'package:frontend/core/session/sesion_controller.dart';

SesionController controlador({
  required List<String> tokens,
  CerrarSesion? cerrar,
}) {
  final pendientes = [...tokens];
  return SesionController(
    iniciarSesion: (_, _) async =>
        Sesion(accessToken: pendientes.removeAt(0), roles: const ['pasajero']),
    cerrarSesion: cerrar,
  );
}

void main() {
  test('el logout viaja con el token de la sesión que sale', () async {
    String? enviado;
    String? vigenteAlEnviar = 'sin-medir';
    late SesionController c;
    c = controlador(
      tokens: ['A'],
      cerrar: (token) async {
        enviado = token;
        vigenteAlEnviar = c.token;
      },
    );
    await c.ingresar('ana', 'clave');

    await c.salir();

    expect(enviado, 'A');
    expect(vigenteAlEnviar, isNull, reason: 'la salida local ya ocurrió');
  });

  test('la salida local se mantiene aunque el logout falle', () async {
    final c = controlador(
      tokens: ['A'],
      cerrar: (_) async => throw Exception('sin red'),
    );
    await c.ingresar('ana', 'clave');

    await c.salir();

    expect(c.sesion, isNull);
  });

  test('salir sin sesión no pide nada al servidor', () async {
    var llamadas = 0;
    final c = controlador(tokens: [], cerrar: (_) async => llamadas++);

    await c.salir();

    expect(llamadas, 0);
  });

  test('un 401 del token vigente cierra la sesión', () async {
    final c = controlador(tokens: ['A']);
    await c.ingresar('ana', 'clave');

    c.invalidar('A');

    expect(c.sesion, isNull);
  });

  test('un 401 tardío de la cuenta anterior no toca a la actual', () async {
    final c = controlador(tokens: ['A', 'B']);
    await c.ingresar('ana', 'clave');
    await c.salir();
    await c.ingresar('beto', 'clave');

    c.invalidar('A');

    expect(c.token, 'B');
  });

  test('la generación cambia en cada ingreso, salida o invalidación', () async {
    final c = controlador(tokens: ['A', 'B']);
    final vistas = <int>[c.generacion];

    await c.ingresar('ana', 'clave');
    vistas.add(c.generacion);
    await c.salir();
    vistas.add(c.generacion);
    await c.ingresar('beto', 'clave');
    vistas.add(c.generacion);
    c.invalidar('B');
    vistas.add(c.generacion);

    expect(vistas.toSet().length, vistas.length);
  });

  test('un ingreso fallido no cambia la generación', () async {
    final c = SesionController(
      iniciarSesion: (_, _) async => throw const CredencialesInvalidas(),
    );
    final antes = c.generacion;

    await c.ingresar('ana', 'mal');

    expect(c.generacion, antes);
  });

  test('un logout lento no retrasa la salida local', () async {
    final respuesta = Completer<void>();
    final c = controlador(tokens: ['A'], cerrar: (_) => respuesta.future);
    await c.ingresar('ana', 'clave');

    final saliendo = c.salir();

    expect(c.sesion, isNull);
    respuesta.complete();
    await saliendo;
  });
}
