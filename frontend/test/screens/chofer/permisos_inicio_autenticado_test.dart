import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:frontend/adapters/chofer/comprobador_ubicacion_android.dart';
import 'package:frontend/controllers/chofer/asistencia_ubicacion_inicio.dart';
import 'package:frontend/controllers/chofer/ejecucion_viaje_controller.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/chofer/chofer_shell.dart';

import '../../fixtures/chofer/plataforma_ubicacion_fake.dart';
import 'ejecucion_autenticada_chofer_test.dart' as circuito;

class _Plataforma extends PlataformaUbicacionFake {
  LocationPermission respuesta = LocationPermission.whileInUse;
  Completer<LocationPermission>? solicitudPendiente;
  Completer<bool>? ajustesPendientes;
  Object? falloSolicitud;

  @override
  Future<LocationPermission> requestPermission() async {
    llamadas.add('solicitarPermiso');
    if (falloSolicitud != null) throw falloSolicitud!;
    permiso = solicitudPendiente == null
        ? respuesta
        : await solicitudPendiente!.future;
    return permiso;
  }

  @override
  Future<bool> openAppSettings() async {
    llamadas.add('ajustesApp');
    return ajustesPendientes?.future ?? ajustesAbiertos;
  }

  @override
  Future<bool> openLocationSettings() async {
    llamadas.add('ajustesUbicacion');
    return ajustesPendientes?.future ?? ajustesAbiertos;
  }
}

Future<void> _montar(
  WidgetTester t,
  circuito.Escenario e,
  _Plataforma plataforma,
) async {
  final adaptador = ComprobadorUbicacionAndroid(plataforma: plataforma);
  await t.pumpWidget(
    VanFullBootstrap(
      apiBaseUrl: 'https://vanfull.test/api/',
      crearTransporte: () => e,
      comprobarUbicacionInicio: adaptador.comprobar,
      asistenciaUbicacionInicio: AsistenciaUbicacionInicio(
        solicitarPermiso: adaptador.solicitarPermiso,
        abrirAjustesApp: adaptador.abrirAjustesApp,
        abrirAjustesUbicacion: adaptador.abrirAjustesUbicacion,
      ),
    ),
  );
  await circuito.ingresar(t);
  await circuito.detalle(t);
  await t.pumpAndSettle();
}

Future<void> _pulsar(WidgetTester t, String texto) async {
  final boton = find.widgetWithText(ElevatedButton, texto);
  await t.ensureVisible(boton);
  await t.tap(boton);
  await circuito.paso(t);
}

void main() {
  testWidgets(
    'permiso ya concedido admite aproximada y no solicita permisos ni posición',
    (t) async {
      final e = circuito.Escenario();
      final p = _Plataforma();
      await _montar(t, e, p);
      await _pulsar(t, 'Iniciar viaje');
      await t.pumpAndSettle();
      expect(e.posts.length, 1);
      expect(p.llamadas, ['servicio', 'permiso']);
      expect(find.text('Solicitar permiso de ubicación'), findsNothing);
    },
  );

  for (final respuesta in [
    LocationPermission.denied,
    LocationPermission.deniedForever,
    LocationPermission.whileInUse,
  ]) {
    testWidgets('solicitar ${respuesta.name} nunca inicia automáticamente', (
      t,
    ) async {
      final e = circuito.Escenario();
      final p = _Plataforma()
        ..permiso = LocationPermission.denied
        ..respuesta = respuesta;
      await _montar(t, e, p);
      expect(p.llamadas, isEmpty);
      await _pulsar(t, 'Iniciar viaje');
      expect(p.llamadas, ['servicio', 'permiso']);
      expect(e.posts, isEmpty);
      final consultas = e.gets.length;
      await _pulsar(t, 'Solicitar permiso de ubicación');
      await t.pumpAndSettle();
      expect(e.posts, isEmpty);
      expect(e.gets.length, consultas);
      expect(p.llamadas, ['servicio', 'permiso', 'solicitarPermiso']);
      if (respuesta == LocationPermission.deniedForever) {
        expect(find.text('Ajustes de la app'), findsOneWidget);
        expect(find.text('Solicitar permiso de ubicación'), findsNothing);
      }
      if (respuesta == LocationPermission.whileInUse) {
        await _pulsar(t, 'Iniciar viaje');
        await t.pumpAndSettle();
        expect(e.posts.length, 1);
        expect(p.llamadas, [
          'servicio',
          'permiso',
          'solicitarPermiso',
          'servicio',
          'permiso',
        ]);
      } else {
        await _pulsar(t, 'Iniciar viaje');
        await t.pumpAndSettle();
        expect(e.posts, isEmpty);
      }
    });
  }

  for (final app in [true, false]) {
    testWidgets(
      'volver de Ajustes ${app ? 'app' : 'ubicación'} exige nuevo Iniciar',
      (t) async {
        final e = circuito.Escenario();
        final p = _Plataforma()
          ..permiso = app
              ? LocationPermission.deniedForever
              : LocationPermission.whileInUse
          ..servicio = app;
        await _montar(t, e, p);
        await _pulsar(t, 'Iniciar viaje');
        expect(e.posts, isEmpty);
        await _pulsar(t, app ? 'Ajustes de la app' : 'Ajustes de ubicación');
        expect(p.llamadas.last, app ? 'ajustesApp' : 'ajustesUbicacion');
        p.permiso = LocationPermission.whileInUse;
        p.servicio = true;
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pumpAndSettle();
        expect(e.posts, isEmpty);
        expect(p.llamadas.length, 3);
        await _pulsar(t, 'Iniciar viaje');
        await t.pumpAndSettle();
        expect(e.posts.length, 1);
        // Tras el POST confirmado se verifica nuevamente antes de abrir captura.
        expect(p.llamadas.sublist(3), [
          'servicio',
          'permiso',
          'servicio',
          'permiso',
        ]);
      },
    );
  }

  testWidgets('Ajustes no disponibles orienta sin iniciar', (t) async {
    final e = circuito.Escenario();
    final p = _Plataforma()
      ..servicio = false
      ..ajustesAbiertos = false;
    await _montar(t, e, p);
    await _pulsar(t, 'Iniciar viaje');
    await _pulsar(t, 'Ajustes de ubicación');
    expect(find.text('No se pudieron abrir los Ajustes.'), findsOneWidget);
    expect(e.posts, isEmpty);
  });

  testWidgets(
    'fallo al pedir permiso no inicia y permite otra acción explícita',
    (t) async {
      final e = circuito.Escenario();
      final p = _Plataforma()
        ..permiso = LocationPermission.denied
        ..falloSolicitud = StateError('simulado');
      await _montar(t, e, p);
      await _pulsar(t, 'Iniciar viaje');
      await _pulsar(t, 'Solicitar permiso de ubicación');
      expect(
        find.text('No se pudo completar la acción de ubicación.'),
        findsOneWidget,
      );
      expect(e.posts, isEmpty);
      p.falloSolicitud = null;
      await _pulsar(t, 'Solicitar permiso de ubicación');
      expect(e.posts, isEmpty);
    },
  );

  testWidgets(
    'solicitud pendiente bloquea Iniciar y descarta respuesta al cerrar detalle',
    (t) async {
      final e = circuito.Escenario();
      final p = _Plataforma()
        ..permiso = LocationPermission.denied
        ..solicitudPendiente = Completer<LocationPermission>();
      await _montar(t, e, p);
      await _pulsar(t, 'Iniciar viaje');
      final consultas = e.gets.length;
      await _pulsar(t, 'Solicitar permiso de ubicación');
      expect(
        t
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Iniciar viaje'),
            )
            .onPressed,
        isNull,
      );
      await circuito.volver(t);
      p.solicitudPendiente!.complete(LocationPermission.whileInUse);
      await t.pumpAndSettle();
      expect(e.posts, isEmpty);
      expect(e.gets.length, consultas);
      await circuito.detalle(t);
      await t.pumpAndSettle();
      expect(e.posts, isEmpty);
    },
  );

  for (final ajustes in [false, true]) {
    testWidgets(
      'cambio de sesión durante ${ajustes ? 'Ajustes' : 'permiso'} descarta respuesta y callbacks de A',
      (t) async {
        final e = circuito.Escenario();
        final p = _Plataforma()
          ..permiso = ajustes
              ? LocationPermission.deniedForever
              : LocationPermission.denied;
        if (ajustes) {
          p.ajustesPendientes = Completer<bool>();
        } else {
          p.solicitudPendiente = Completer<LocationPermission>();
        }
        await _montar(t, e, p);
        await _pulsar(t, 'Iniciar viaje');
        final vieja = t
            .widget<ChoferShell>(find.byType(ChoferShell))
            .asistenciaUbicacionInicio!;
        await _pulsar(
          t,
          ajustes ? 'Ajustes de la app' : 'Solicitar permiso de ubicación',
        );
        await circuito.nuevaCuenta(t);
        if (ajustes) {
          p.ajustesPendientes!.complete(true);
        } else {
          p.solicitudPendiente!.complete(LocationPermission.whileInUse);
        }
        await t.pumpAndSettle();
        expect(e.posts, isEmpty);
        expect(find.textContaining('Al volver de Ajustes'), findsNothing);
        expect(find.textContaining('Permiso concedido.'), findsNothing);
        final llamadas = p.llamadas.length;
        await expectLater(
          vieja.solicitarPermiso(),
          throwsA(isA<RechazoOperacionViaje>()),
        );
        await expectLater(
          vieja.abrirAjustesApp(),
          throwsA(isA<RechazoOperacionViaje>()),
        );
        expect(p.llamadas.length, llamadas);
      },
    );
  }

  testWidgets(
    'finalizar y repetir finalización nunca usan comprobación ni asistencia',
    (t) async {
      final e = circuito.Escenario()
        ..estado = 'en_curso'
        ..incierto = true;
      final p = _Plataforma()
        ..permiso = LocationPermission.deniedForever
        ..servicio = false;
      await _montar(t, e, p);
      await circuito.finalizar(t);
      await t.pumpAndSettle();
      await _pulsar(t, 'Consultar estado');
      await t.pumpAndSettle();
      await _pulsar(t, 'Reintentar finalización');
      e.incierto = false;
      await t.tap(find.text('Finalizar viaje').last);
      await t.pumpAndSettle();
      expect(e.posts.length, 2);
      expect(p.llamadas, isEmpty);
    },
  );

  testWidgets(
    'permiso concedido no elimina incertidumbre ni rechazo posterior',
    (t) async {
      final e = circuito.Escenario()..incierto = true;
      final p = _Plataforma();
      await _montar(t, e, p);
      await _pulsar(t, 'Iniciar viaje');
      await t.pumpAndSettle();
      await _pulsar(t, 'Consultar estado');
      await t.pumpAndSettle();
      p.permiso = LocationPermission.denied;
      await _pulsar(t, 'Reintentar inicio');
      await _pulsar(t, 'Solicitar permiso de ubicación');
      expect(e.posts.length, 1);
      expect(
        find.textContaining('No pudimos confirmar el resultado'),
        findsOneWidget,
      );
      e.incierto = false;
      e.statusPost = 409;
      await _pulsar(t, 'Reintentar inicio');
      await t.pumpAndSettle();
      expect(e.posts.length, 2);
      expect(
        find.textContaining('No pudimos confirmar el resultado'),
        findsOneWidget,
      );
    },
  );
}
