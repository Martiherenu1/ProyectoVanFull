import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/controllers/chofer/ejecucion_viaje_controller.dart';
import 'package:frontend/core/theme/app_spacing.dart';
import 'package:frontend/models/chofer/operacion_asignada.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';
import 'package:frontend/screens/chofer/detalle_viaje_chofer_screen.dart';

import '../../fixtures/chofer/operacion_asignada_fixture.dart';

OperacionAsignada snapshot(String estado, {int id = 41}) {
  final json = detalleJson(id: id);
  (json['viaje'] as Map)['estado'] = estado;
  return OperacionAsignada.fromJson(json);
}

Future<void> mostrar(
  WidgetTester tester,
  CargarDetalleViajeChofer cargar,
  AccionesEjecucionViaje acciones, {
  int id = 41,
}) => tester.pumpWidget(
  MaterialApp(
    home: DetalleViajeChoferScreen(
      idViaje: id,
      cargarDetalle: cargar,
      acciones: acciones,
    ),
  ),
);

AccionesEjecucionViaje fuentes({
  CambiarEstadoViajeChofer? inicio,
  CambiarEstadoViajeChofer? fin,
  void Function(RechazoOperacionViaje)? rechazo,
}) => AccionesEjecucionViaje(
  iniciar: inicio ?? (_) async => snapshot('en_curso').viaje,
  finalizar: fin ?? (_) async => snapshot('finalizado').viaje,
  onRechazo: rechazo,
);

Future<void> confirmar(WidgetTester tester) async {
  await tester.tap(find.text('Finalizar viaje'));
  await tester.pumpAndSettle();
  expect(find.text('¿Finalizar este viaje?'), findsOneWidget);
  expect(find.text('El viaje quedará finalizado.'), findsOneWidget);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Finalizar viaje').last);
  await tester.pump();
}

void main() {
  for (final estado in ['programado', 'en_curso', 'finalizado', 'cancelado']) {
    testWidgets('acciones de $estado sin transiciones nuevas en terminales', (
      tester,
    ) async {
      await mostrar(tester, (_) async => snapshot(estado), fuentes());
      await tester.pumpAndSettle();
      expect(
        find.text('Iniciar viaje'),
        estado == 'programado' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Finalizar viaje'),
        estado == 'en_curso' ? findsOneWidget : findsNothing,
      );
    });
  }

  for (final aceptar in [false, true]) {
    testWidgets(
      'confirmación finalización aceptar=$aceptar y controles de 64 px',
      (tester) async {
        var estado = 'en_curso';
        var finales = 0;
        await mostrar(
          tester,
          (_) async => snapshot(estado),
          fuentes(
            fin: (id) async {
              expect(id, 41);
              finales++;
              estado = 'finalizado';
              return snapshot(estado).viaje;
            },
          ),
        );
        await tester.pumpAndSettle();
        final boton = find.widgetWithText(ElevatedButton, 'Finalizar viaje');
        expect(
          tester.getSize(boton).height,
          greaterThanOrEqualTo(AppSpacing.driverTouchTarget),
        );
        expect(Theme.of(tester.element(boton)).brightness, Brightness.dark);
        await tester.tap(boton);
        await tester.pumpAndSettle();
        expect(finales, 0);
        expect(find.text('¿Finalizar este viaje?'), findsOneWidget);
        expect(find.text('El viaje quedará finalizado.'), findsOneWidget);
        final accion = find
            .widgetWithText(
              ElevatedButton,
              aceptar ? 'Finalizar viaje' : 'Volver',
            )
            .last;
        expect(
          tester.getSize(accion).height,
          greaterThanOrEqualTo(AppSpacing.driverTouchTarget),
        );
        await tester.tap(accion);
        await tester.pumpAndSettle();
        expect(finales, aceptar ? 1 : 0);
        expect(
          find.text('Ida · Finalizado'),
          aceptar ? findsOneWidget : findsNothing,
        );
      },
    );
  }

  testWidgets(
    'doble pulsación inicia una vez y bloquea hasta recarga completa',
    (tester) async {
      final post = Completer<ViajeResumen>();
      final lectura = Completer<OperacionAsignada?>();
      var inicios = 0;
      var consultas = 0;
      await mostrar(
        tester,
        (_) {
          consultas++;
          return consultas == 1
              ? Future.value(snapshot('programado'))
              : lectura.future;
        },
        fuentes(
          inicio: (_) {
            inicios++;
            return post.future;
          },
        ),
      );
      await tester.pumpAndSettle();
      final boton = find.text('Iniciar viaje');
      await tester.tap(boton);
      await tester.tap(boton);
      await tester.pump();
      expect(inicios, 1);
      expect(find.text('Iniciar viaje'), findsNothing);
      expect(find.text('Finalizar viaje'), findsNothing);
      expect(find.text('Ana Prueba'), findsNothing);
      post.complete(snapshot('en_curso').viaje);
      await tester.pump();
      expect(find.text('Estado confirmado: En curso'), findsOneWidget);
      expect(find.text('Finalizar viaje'), findsNothing);
      lectura.complete(snapshot('en_curso'));
      await tester.pumpAndSettle();
      expect(find.text('Finalizar viaje'), findsOneWidget);
    },
  );

  testWidgets(
    'inicio devuelve finalizado y recarga fallida no mezcla listas viejas',
    (tester) async {
      var consultas = 0;
      var posts = 0;
      await mostrar(
        tester,
        (_) async {
          consultas++;
          if (consultas == 2) throw StateError('red privada');
          return snapshot(consultas == 1 ? 'programado' : 'finalizado');
        },
        fuentes(
          inicio: (_) async {
            posts++;
            return snapshot('finalizado').viaje;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar viaje'));
      await tester.pumpAndSettle();
      expect(find.text('Estado confirmado: Finalizado'), findsOneWidget);
      expect(
        find.text(
          'Estado del viaje confirmado. No pudimos actualizar el detalle.',
        ),
        findsOneWidget,
      );
      expect(find.text('Ana Prueba'), findsNothing);
      expect(find.text('Cantidades independientes'), findsNothing);
      expect(find.text('Iniciar viaje'), findsNothing);
      expect(find.text('Finalizar viaje'), findsNothing);
      await tester.tap(find.text('Actualizar detalle'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(find.text('Ida · Finalizado'), findsOneWidget);
      expect(find.textContaining('red privada'), findsNothing);
    },
  );

  testWidgets(
    'incertidumbre, consulta fallida, mismo estado y rechazo del reintento',
    (tester) async {
      var consultas = 0;
      var posts = 0;
      await mostrar(
        tester,
        (_) async {
          consultas++;
          if (consultas == 2) throw StateError('red');
          return snapshot(consultas < 5 ? 'programado' : 'en_curso');
        },
        fuentes(
          inicio: (_) async {
            posts++;
            if (posts == 1) throw const ResultadoViajeIncierto();
            throw const RechazoOperacionViaje(MotivoRechazoViaje.conflicto);
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar viaje'));
      await tester.pumpAndSettle();
      const mensaje =
          'No pudimos confirmar el resultado. Consultá el estado antes de continuar.';
      expect(find.text(mensaje), findsOneWidget);
      expect(find.text('Reintentar inicio'), findsNothing);
      await tester.tap(find.text('Consultar estado'));
      await tester.pumpAndSettle();
      expect(find.text(mensaje), findsOneWidget);
      expect(find.text('Reintentar inicio'), findsNothing);
      expect(posts, 1);
      await tester.tap(find.text('Consultar estado'));
      await tester.pumpAndSettle();
      expect(find.text('Último estado consultado: Programado'), findsOneWidget);
      expect(find.text('Reintentar inicio'), findsOneWidget);
      expect(find.text('Iniciar viaje'), findsNothing);
      expect(find.text('Finalizar viaje'), findsNothing);
      await tester.tap(find.text('Reintentar inicio'));
      await tester.pumpAndSettle();
      expect(posts, 2);
      expect(find.text(mensaje), findsOneWidget);
      expect(find.text('Reintentar inicio'), findsNothing);
      await tester.tap(find.text('Consultar estado'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar inicio'), findsOneWidget);
      await tester.tap(find.text('Consultar estado'));
      await tester.pumpAndSettle();
      expect(find.text(mensaje), findsNothing);
      expect(find.text('Finalizar viaje'), findsOneWidget);
      expect(posts, 2);
    },
  );

  testWidgets(
    'reintento de finalización requiere otra confirmación explícita',
    (tester) async {
      var posts = 0;
      var estado = 'en_curso';
      await mostrar(
        tester,
        (_) async => snapshot(estado),
        fuentes(
          fin: (_) async {
            if (++posts == 1) throw const ResultadoViajeIncierto();
            estado = 'finalizado';
            return snapshot(estado).viaje;
          },
        ),
      );
      await tester.pumpAndSettle();
      await confirmar(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Consultar estado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reintentar finalización'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      await tester.tap(find.text('Reintentar finalización'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Finalizar viaje').last,
      );
      await tester.pumpAndSettle();
      expect(posts, 2);
      expect(find.text('Ida · Finalizado'), findsOneWidget);
    },
  );

  final rechazos = {
    MotivoRechazoViaje.validacion: 'La solicitud no es válida.',
    MotivoRechazoViaje.noAutenticado:
        'Necesitás una sesión válida para continuar.',
    MotivoRechazoViaje.sinPermiso: 'No tenés permiso para esta operación.',
    MotivoRechazoViaje.noDisponible: 'Viaje no disponible.',
    MotivoRechazoViaje.conflicto:
        'El estado del viaje no permite esta operación. Actualizá el detalle.',
  };
  for (final entrada in rechazos.entries) {
    testWidgets(
      'presenta rechazo ${entrada.key} y actualiza antes de otra acción',
      (tester) async {
        final avisos = <RechazoOperacionViaje>[];
        var estado = 'programado';
        await mostrar(
          tester,
          (_) async => snapshot(estado),
          fuentes(
            inicio: (_) async {
              estado = 'cancelado';
              throw RechazoOperacionViaje(
                entrada.key,
                codigo: 'CODIGO_PRIVADO',
              );
            },
            rechazo: avisos.add,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Iniciar viaje'));
        await tester.pumpAndSettle();
        expect(find.text(entrada.value), findsOneWidget);
        expect(avisos.single.motivo, entrada.key);
        expect(find.text('Iniciar viaje'), findsNothing);
        expect(find.textContaining('CODIGO_PRIVADO'), findsNothing);
        await tester.tap(find.text('Actualizar detalle'));
        await tester.pumpAndSettle();
        expect(find.text('Ida · Cancelado'), findsOneWidget);
        expect(find.text('Iniciar viaje'), findsNothing);
      },
    );
  }

  testWidgets('cambio de viaje durante diálogo no finaliza ninguno', (
    tester,
  ) async {
    var finales = 0;
    Future<OperacionAsignada?> cargar(int id) async =>
        snapshot('en_curso', id: id);
    final acciones = fuentes(
      fin: (_) async {
        finales++;
        return snapshot('finalizado').viaje;
      },
    );
    await mostrar(tester, cargar, acciones);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar viaje'));
    await tester.pumpAndSettle();
    await mostrar(tester, cargar, acciones, id: 42);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Finalizar viaje').last,
    );
    await tester.pumpAndSettle();
    expect(finales, 0);
    expect(find.text('Viaje 42'), findsOneWidget);
  });

  for (final resultado in ['exito', 'error']) {
    testWidgets(
      'POST $resultado después de cambiar viaje no altera detalle nuevo',
      (tester) async {
        final post = Completer<ViajeResumen>();
        Future<OperacionAsignada?> cargar(int id) async =>
            snapshot('programado', id: id);
        final acciones = fuentes(inicio: (_) => post.future);
        await mostrar(tester, cargar, acciones);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Iniciar viaje'));
        await tester.pump();
        await mostrar(tester, cargar, acciones, id: 42);
        await tester.pumpAndSettle();
        if (resultado == 'exito') {
          post.complete(snapshot('finalizado').viaje);
        } else {
          post.completeError(const ResultadoViajeIncierto());
        }
        await tester.pumpAndSettle();
        expect(find.text('Viaje 42'), findsOneWidget);
        expect(find.text('Ida · Programado'), findsOneWidget);
        expect(find.text('Iniciar viaje'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('POST $resultado después del desmontaje no actualiza UI', (
      tester,
    ) async {
      final post = Completer<ViajeResumen>();
      await mostrar(
        tester,
        (_) async => snapshot('programado'),
        fuentes(inicio: (_) => post.future),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar viaje'));
      await tester.pumpWidget(const SizedBox());
      if (resultado == 'exito') {
        post.complete(snapshot('en_curso').viaje);
      } else {
        post.completeError(StateError('red'));
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  for (final fallo in [false, true]) {
    testWidgets(
      'cambiar solo fuente durante POST fallo=$fallo conserva incertidumbre',
      (tester) async {
        final post = Completer<ViajeResumen>();
        final acciones = fuentes(inicio: (_) => post.future);
        Future<OperacionAsignada?> original(int id) async =>
            snapshot('programado');
        var estadoNuevo = 'programado';
        Future<OperacionAsignada?> nueva(int id) async => snapshot(estadoNuevo);
        await mostrar(tester, original, acciones);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Iniciar viaje'));
        await tester.pump();
        await mostrar(tester, nueva, acciones);
        await tester.pumpAndSettle();
        expect(find.text('Reintentar inicio'), findsOneWidget);
        if (fallo) {
          post.completeError(
            const RechazoOperacionViaje(MotivoRechazoViaje.conflicto),
          );
        } else {
          post.complete(snapshot('en_curso').viaje);
        }
        await tester.pumpAndSettle();
        expect(find.text('Iniciar viaje'), findsNothing);
        expect(find.text('Finalizar viaje'), findsNothing);
        expect(find.text('Reintentar inicio'), findsOneWidget);
        estadoNuevo = 'en_curso';
        await tester.tap(find.text('Consultar estado'));
        await tester.pumpAndSettle();
        expect(find.text('Finalizar viaje'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('409 de vehículo muestra el motivo sin validación local previa', (
    tester,
  ) async {
    final json = detalleJson();
    final viaje = json['viaje'] as Map;
    viaje['estado'] = 'programado';
    viaje.remove('id_vehiculo');
    viaje.remove('horario');
    await mostrar(
      tester,
      (_) async => OperacionAsignada.fromJson(json),
      fuentes(
        inicio: (_) async => throw const RechazoOperacionViaje(
          MotivoRechazoViaje.conflicto,
          codigo: 'VEHICULO_NO_ASIGNADO',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fecha: 30/10/2026 · Sin horario'), findsOneWidget);
    await tester.tap(find.text('Iniciar viaje'));
    await tester.pumpAndSettle();
    expect(
      find.text('El viaje necesita un vehículo asignado para iniciarse.'),
      findsOneWidget,
    );
    expect(find.text('Actualizar detalle'), findsOneWidget);
  });

  testWidgets(
    'retirar acciones no oculta el resultado incierto del mismo viaje',
    (tester) async {
      final post = Completer<ViajeResumen>();
      Future<OperacionAsignada?> cargar(int id) async => snapshot('programado');
      await mostrar(tester, cargar, fuentes(inicio: (_) => post.future));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar viaje'));
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: DetalleViajeChoferScreen(idViaje: 41, cargarDetalle: cargar),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No pudimos confirmar el resultado. Consultá el estado antes de continuar.',
        ),
        findsOneWidget,
      );
      expect(find.text('Consultar estado'), findsOneWidget);
      expect(find.text('Reintentar inicio'), findsNothing);
      post.completeError(const ResultadoViajeIncierto());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'detalle regresivo no sustituye finalizado ni muestra listas actualizadas',
    (tester) async {
      var lecturas = 0;
      var posts = 0;
      await mostrar(
        tester,
        (_) async {
          lecturas++;
          return snapshot(switch (lecturas) {
            1 => 'programado',
            2 => 'en_curso',
            _ => 'finalizado',
          });
        },
        fuentes(
          inicio: (_) async {
            posts++;
            return snapshot('finalizado').viaje;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar viaje'));
      await tester.pumpAndSettle();
      expect(find.text('Estado confirmado: Finalizado'), findsOneWidget);
      expect(
        find.text(
          'Estado del viaje confirmado. No pudimos actualizar el detalle.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cantidades independientes'), findsNothing);
      expect(find.text('Pasajeros con reserva'), findsNothing);
      expect(find.text('Iniciar viaje'), findsNothing);
      expect(find.text('Finalizar viaje'), findsNothing);
      await tester.tap(find.text('Actualizar detalle'));
      await tester.pumpAndSettle();
      expect(find.text('Ida · Finalizado'), findsOneWidget);
      expect(find.text('Cantidades independientes'), findsOneWidget);
      expect(find.text('Actualizar detalle'), findsNothing);
      expect(posts, 1);
    },
  );
  for (final cambioFuente in [true, false]) {
    testWidgets(
      'cambio fuente=$cambioFuente conserva confirmación y Actualizar detalle',
      (tester) async {
        var lecturas = 0;
        var recuperar = false;
        Future<OperacionAsignada?> cargar(int id) async {
          if (++lecturas == 1) return snapshot('programado');
          if (lecturas == 2) throw StateError('recarga fallida');
          return snapshot(recuperar ? 'finalizado' : 'en_curso');
        }

        final acciones = fuentes(
          inicio: (_) async => snapshot('finalizado').viaje,
        );
        await mostrar(tester, cargar, acciones);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Iniciar viaje'));
        await tester.pumpAndSettle();
        await mostrar(
          tester,
          cambioFuente ? (id) => cargar(id) : cargar,
          cambioFuente ? acciones : fuentes(),
        );
        await tester.pumpAndSettle();
        expect(find.text('Estado confirmado: Finalizado'), findsOneWidget);
        expect(find.text('Actualizar detalle'), findsOneWidget);
        expect(find.text('Pasajeros con reserva'), findsNothing);
        expect(find.text('Cantidades independientes'), findsNothing);
        expect(find.text('Iniciar viaje'), findsNothing);
        expect(find.text('Finalizar viaje'), findsNothing);
        recuperar = true;
        await tester.tap(find.text('Actualizar detalle'));
        await tester.pumpAndSettle();
        expect(find.text('Ida · Finalizado'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Pasajeros con reserva'),
          250,
        );
        expect(find.text('Pasajeros con reserva'), findsOneWidget);
        expect(find.text('Actualizar detalle'), findsNothing);
      },
    );
  }
}
