import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pasajero/respuesta_chat.dart';
import 'package:frontend/screens/pasajero/asistente_screen.dart';

RespuestaChat respuesta(
  String texto, {
  String conversacion = 'c-1',
  bool derivar = false,
  String? tool,
}) => RespuestaChat(
  respuesta: texto,
  conversacionId: conversacion,
  derivarHumano: derivar,
  toolUsada: tool,
);

Future<void> mostrar(WidgetTester tester, EnviarMensaje enviar) => tester
    .pumpWidget(MaterialApp(home: AsistenteScreen(enviarMensaje: enviar)));

Future<void> escribirYEnviar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byKey(const ValueKey('mensaje')), texto);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('enviar')));
  await tester.pump();
}

bool envioHabilitado(WidgetTester tester) =>
    tester.widget<IconButton>(find.byKey(const ValueKey('enviar'))).onPressed !=
    null;

void main() {
  testWidgets('al empezar presenta lo que puede hacer y no envía nada', (
    tester,
  ) async {
    await mostrar(tester, (_, _) async => respuesta('hola'));

    expect(find.byKey(const ValueKey('presentacion')), findsOneWidget);
    expect(find.textContaining('Los pagos no los confirmo yo'), findsOneWidget);
    expect(envioHabilitado(tester), isFalse);
  });

  testWidgets('no se puede enviar un mensaje vacío o solo con espacios', (
    tester,
  ) async {
    await mostrar(tester, (_, _) async => respuesta('hola'));

    await tester.enterText(find.byKey(const ValueKey('mensaje')), '   ');
    await tester.pump();
    expect(envioHabilitado(tester), isFalse);

    await tester.enterText(find.byKey(const ValueKey('mensaje')), 'Hola');
    await tester.pump();
    expect(envioHabilitado(tester), isTrue);
  });

  testWidgets(
    'envía el mensaje sin espacios sobrantes y muestra la respuesta',
    (tester) async {
      String? enviado;
      await mostrar(tester, (mensaje, _) async {
        enviado = mensaje;
        return respuesta('Hay 14 lugares en el 06:15.');
      });
      await escribirYEnviar(tester, '  ¿Hay lugar mañana?  ');
      await tester.pump();

      expect(enviado, '¿Hay lugar mañana?');
      expect(find.text('¿Hay lugar mañana?'), findsOneWidget);
      expect(find.text('Hay 14 lugares en el 06:15.'), findsOneWidget);
      expect(find.byKey(const ValueKey('presentacion')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('mensaje')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets('continúa la conversación con el id que devolvió el backend', (
    tester,
  ) async {
    final ids = <String?>[];
    await mostrar(tester, (mensaje, id) async {
      ids.add(id);
      return respuesta('ok', conversacion: 'c-77');
    });
    await escribirYEnviar(tester, 'Primero');
    await tester.pump();
    await escribirYEnviar(tester, 'Segundo');
    await tester.pump();

    expect(ids, [null, 'c-77']);
  });

  testWidgets('mientras espera avisa y no deja mandar otro mensaje', (
    tester,
  ) async {
    final pendiente = Completer<RespuestaChat>();
    var pedidos = 0;
    await mostrar(tester, (_, _) {
      pedidos++;
      return pendiente.future;
    });
    await escribirYEnviar(tester, 'Hola');

    expect(find.byKey(const ValueKey('escribiendo')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('mensaje')), 'Otro');
    await tester.pump();
    expect(envioHabilitado(tester), isFalse);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    pendiente.complete(respuesta('Listo'));
    await tester.pump();
    expect(pedidos, 1);
    expect(find.byKey(const ValueKey('escribiendo')), findsNothing);
    expect(find.text('Listo'), findsOneWidget);
  });

  testWidgets('si el asistente deriva, lo marca', (tester) async {
    await mostrar(
      tester,
      (_, _) async => respuesta('Te derivo con una persona.', derivar: true),
    );
    await escribirYEnviar(tester, 'Quiero hablar con alguien');
    await tester.pump();

    expect(find.text('Te derivo con una persona.'), findsOneWidget);
    expect(find.byKey(const ValueKey('derivado')), findsOneWidget);
  });

  testWidgets('una respuesta normal no se marca como derivada', (tester) async {
    await mostrar(tester, (_, _) async => respuesta('Hay lugar.'));
    await escribirYEnviar(tester, 'Hola');
    await tester.pump();

    expect(find.byKey(const ValueKey('derivado')), findsNothing);
  });

  testWidgets('si falla el envío conserva el mensaje y permite reintentar', (
    tester,
  ) async {
    var llamadas = 0;
    final ids = <String?>[];
    await mostrar(tester, (mensaje, id) async {
      llamadas++;
      ids.add(id);
      if (llamadas == 1) throw Exception('sin red');
      return respuesta('Ahora sí.');
    });
    await escribirYEnviar(tester, 'Hola');
    await tester.pump();

    expect(find.text('Hola'), findsOneWidget);
    expect(find.text('No se pudo enviar.'), findsOneWidget);
    expect(envioHabilitado(tester), isFalse);

    await tester.tap(find.byKey(const ValueKey('reintentar-mensaje')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Ahora sí.'), findsOneWidget);
    expect(find.text('No se pudo enviar.'), findsNothing);
    expect(find.text('Hola'), findsOneWidget);
    expect(ids, [null, null]);
  });

  testWidgets('limita el mensaje a lo que acepta el backend', (tester) async {
    await mostrar(tester, (_, _) async => respuesta('ok'));
    await tester.enterText(
      find.byKey(const ValueKey('mensaje')),
      'a' * (maxCaracteresMensaje + 50),
    );
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('mensaje')))
          .controller!
          .text
          .length,
      maxCaracteresMensaje,
    );
  });
}
