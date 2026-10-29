import 'package:flutter/material.dart';

import '../../core/format/importe.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/pasajero/deuda.dart';

/// Presentación parcial de CU-015/RF-010, sin transporte ni acciones económicas.
/// El integrador debe obtener los datos mediante una consulta autorizada.
/// Saldo/estado provienen del backend; no infiere suspensión, límite o habilitación.
class ResumenDeudaAdmin extends StatelessWidget {
  const ResumenDeudaAdmin({
    super.key,
    required this.idCliente,
    required this.deuda,
  });

  final int idCliente;
  final Deuda? deuda;

  @override
  Widget build(BuildContext context) {
    final situacion = deuda;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cliente $idCliente',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (situacion == null)
              const Text('Sin información de deuda disponible.')
            else ...[
              Text('Saldo deudor: ${importeLegible(situacion.saldo)}'),
              Text(
                'Situación: ${situacion.estado == EstadoDeuda.alDia ? 'Al día' : 'Con deuda'}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
