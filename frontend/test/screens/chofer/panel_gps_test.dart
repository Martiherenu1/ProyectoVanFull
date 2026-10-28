import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:frontend/controllers/chofer/seguimiento_gps_controller.dart';
import 'package:frontend/controllers/chofer/condiciones_ubicacion_inicio.dart';
import 'package:frontend/core/theme/app_spacing.dart';
import 'package:frontend/screens/chofer/panel_gps.dart';

import '../../controllers/chofer/seguimiento_gps_controller_test.dart' as f;

import 'package:frontend/models/chofer/viaje_resumen.dart';

void main() {
  testWidgets('reactivar usa mínimo Chofer y crece con texto ampliado', (
    t,
  ) async {
    final c = SeguimientoGpsController(
      comprobar: () async => const CondicionesUbicacionInicio(
        servicioActivado: true,
        permisoConcedido: true,
      ),
      capturar: () => const Stream<Position>.empty(),
      enviar: (_, _) async {},
      sesionVigente: () => true,
    );
    addTearDown(c.dispose);
    c.confirmar(f.viaje(EstadoViaje.enCurso));
    double? normal;
    for (final escala in [1.0, 3.0]) {
      await t.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escala)),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 230,
              child: PanelGps(controller: c, child: const SizedBox()),
            ),
          ),
        ),
      );
      await t.pump();
      final boton = find.widgetWithText(
        OutlinedButton,
        'Reactivar GPS del viaje 1',
      );
      final alto = t.getSize(boton).height;
      expect(alto, greaterThanOrEqualTo(AppSpacing.driverTouchTarget));
      expect(t.takeException(), isNull);
      if (normal == null) {
        normal = alto;
      } else {
        expect(alto, greaterThan(normal));
      }
    }
    await t.pumpWidget(const SizedBox());
  });
}
