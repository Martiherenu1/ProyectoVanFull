import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/session/sesion.dart';
import 'package:frontend/core/session/sesion_app.dart';
import 'package:frontend/core/session/sesion_controller.dart';
import 'package:frontend/screens/admin/viajes_dia_admin_screen.dart';

Sesion sesionDe(List<String> roles) => Sesion(accessToken: 'tok', roles: roles);

Future<void> completar(WidgetTester tester, {String pass = 'clave'}) async {
  await tester.enterText(find.byType(TextField).at(0), ' ana@vanfull.test ');
  await tester.enterText(find.byType(TextField).at(1), pass);
  await tester.tap(find.text('Ingresar'));
  await tester.pump();
}

void main() {
  test('Sesion.fromJson lee el TokenResponse del contrato', () {
    final s = Sesion.fromJson({
      'access_token': 'abc',
      'token_type': 'bearer',
      'roles': ['pasajero'],
    });
    expect(s.accessToken, 'abc');
    expect(s.roles, ['pasajero']);
  });

  testWidgets('sin sesión muestra el login y no pide nada hasta enviar', (
    tester,
  ) async {
    var llamadas = 0;
    final c = SesionController(
      iniciarSesion: (_, _) async {
        llamadas++;
        return sesionDe(['pasajero']);
      },
    );
    await tester.pumpWidget(SesionApp(controller: c));

    expect(find.text('Ingresar'), findsOneWidget);
    await tester.tap(find.text('Ingresar'));
    await tester.pump();
    expect(llamadas, 0, reason: 'campos vacíos no llaman al servidor');
  });

  testWidgets('ingresa con el identificador sin espacios y abre el rol', (
    tester,
  ) async {
    String? recibido;
    final c = SesionController(
      iniciarSesion: (id, _) async {
        recibido = id;
        return sesionDe(['chofer']);
      },
    );
    await tester.pumpWidget(SesionApp(controller: c));

    await completar(tester);
    await tester.pumpAndSettle();

    expect(recibido, 'ana@vanfull.test');
    expect(c.token, 'tok');
    expect(find.text('VanFull — Chofer'), findsOneWidget);
    expect(find.text('Ingresar'), findsNothing);
  });

  testWidgets(
    'credenciales inválidas muestran el motivo y siguen en el login',
    (tester) async {
      final c = SesionController(
        iniciarSesion: (_, _) async => throw const CredencialesInvalidas(),
      );
      await tester.pumpWidget(SesionApp(controller: c));

      await completar(tester);
      await tester.pump();

      expect(
        find.text('El correo o la contraseña no son correctos.'),
        findsOneWidget,
      );
      expect(c.sesion, isNull);
    },
  );

  testWidgets('un fallo de red se distingue de las credenciales', (
    tester,
  ) async {
    final c = SesionController(
      iniciarSesion: (_, _) async => throw Exception('sin conexión'),
    );
    await tester.pumpWidget(SesionApp(controller: c));

    await completar(tester);
    await tester.pump();

    expect(find.textContaining('No pudimos conectarnos'), findsOneWidget);
  });

  testWidgets('no permite doble envío mientras ingresa', (tester) async {
    final espera = Completer<Sesion>();
    var llamadas = 0;
    final c = SesionController(
      iniciarSesion: (_, _) {
        llamadas++;
        return espera.future;
      },
    );
    await tester.pumpWidget(SesionApp(controller: c));

    await completar(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await c.ingresar('otro', 'otra');
    expect(llamadas, 1);

    espera.complete(sesionDe(['administrador']));
    await tester.pumpAndSettle();
    expect(find.byType(ViajesDiaAdminScreen), findsOneWidget);
  });

  testWidgets('salir vuelve al login aunque el logout falle', (tester) async {
    final c = SesionController(
      iniciarSesion: (_, _) async => sesionDe(['pasajero']),
      cerrarSesion: (_) async => throw Exception('sin red'),
    );
    await tester.pumpWidget(SesionApp(controller: c));
    await completar(tester);
    await tester.pumpAndSettle();
    expect(find.text('VanFull — Pasajero'), findsOneWidget);

    await c.salir();
    await tester.pumpAndSettle();

    expect(c.token, isNull);
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('la contraseña arranca oculta y se puede mostrar', (
    tester,
  ) async {
    final c = SesionController(
      iniciarSesion: (_, _) async => sesionDe(['pasajero']),
    );
    await tester.pumpWidget(SesionApp(controller: c));

    TextField campo() => tester.widget<TextField>(find.byType(TextField).at(1));
    expect(campo().obscureText, isTrue);
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(campo().obscureText, isFalse);
  });

  testWidgets('el pasajero entra a su pantalla y los otros roles no', (
    tester,
  ) async {
    for (final (rol, esperado) in [
      ('pasajero', 'entrada-del-pasajero'),
      ('chofer', 'VanFull — Chofer'),
    ]) {
      final c = SesionController(
        iniciarSesion: (_, _) async => sesionDe([rol]),
      );
      await tester.pumpWidget(
        SesionApp(
          controller: c,
          entradaPasajero: (_) => const Text('entrada-del-pasajero'),
        ),
      );
      await completar(tester);
      await tester.pumpAndSettle();

      expect(find.text(esperado), findsOneWidget, reason: rol);
    }
  });

  testWidgets('el administrador recibe sus dependencias en Viajes del día', (
    tester,
  ) async {
    final fechas = <DateTime>[];
    final c = SesionController(
      iniciarSesion: (_, _) async => sesionDe(['administrador']),
    );
    await tester.pumpWidget(
      SesionApp(
        controller: c,
        fechaAdmin: DateTime(2026, 10, 30, 18),
        cargarViajesAdmin: (fecha) async {
          fechas.add(fecha);
          return const [];
        },
      ),
    );
    await completar(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ViajesDiaAdminScreen), findsOneWidget);
    expect(fechas, [DateTime(2026, 10, 30)]);
  });
}
