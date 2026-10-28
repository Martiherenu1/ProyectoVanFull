import 'package:flutter/material.dart';

import '../../controllers/chofer/seguimiento_gps_controller.dart';
import '../../core/theme/app_spacing.dart';

class PanelGps extends StatelessWidget {
  const PanelGps({required this.controller, required this.child, super.key});
  final SeguimientoGpsController controller;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limits) => Column(
      children: [
        // Con texto grande o varios viajes, las opciones pueden desplazarse
        // sin ocupar el espacio necesario para acceder al detalle y sus acciones.
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: limits.maxHeight / 2),
          child: Material(
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (_, _) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(controller.estado),
                        for (final id in controller.viajesReactivables)
                          OutlinedButton(
                            onPressed: () => controller.reactivarViaje(id),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(
                                0,
                                AppSpacing.driverTouchTarget,
                              ),
                            ),
                            child: Text('Reactivar GPS del viaje $id'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}
