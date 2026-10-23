import 'package:flutter/material.dart';

import '../../controllers/chofer/ejecucion_viaje_controller.dart';
import '../../core/theme/app_spacing.dart';

/// Presentación de acciones; toda solicitud y reconciliación usa el coordinador
/// del detalle. No crea navegación de aplicación, HTTP ni sesión.
class AccionesViajeChofer extends StatefulWidget {
  const AccionesViajeChofer({required this.controlador, super.key});

  final EjecucionViajeController controlador;

  @override
  State<AccionesViajeChofer> createState() => _AccionesViajeChoferState();
}

class _AccionesViajeChoferState extends State<AccionesViajeChofer> {
  bool _confirmando = false;

  Future<void> _confirmarFinalizacion({bool reintento = false}) async {
    if (_confirmando) return;
    final controlador = widget.controlador;
    final contexto = controlador.contexto;
    setState(() => _confirmando = true);
    try {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Finalizar este viaje?'),
          content: const Text('El viaje quedará finalizado.'),
          actions: [
            _boton('Volver', () => Navigator.of(context).pop(false)),
            _boton('Finalizar viaje', () => Navigator.of(context).pop(true)),
          ],
        ),
      );
      if (!mounted ||
          confirmar != true ||
          controlador != widget.controlador ||
          contexto != controlador.contexto) {
        return;
      }
      if (reintento) {
        await controlador.repetir();
      } else {
        await controlador.finalizar();
      }
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controlador;
    final rechazo = c.rechazo;
    final confirmado = c.viajeConfirmado;
    final mensaje = switch (c.fase) {
      FaseDetalleViaje.incierto => 'No pudimos confirmar el resultado. Consultá el estado antes de continuar.',
      FaseDetalleViaje.confirmadoSinDetalle =>
        'Estado del viaje confirmado. No pudimos actualizar el detalle.',
      FaseDetalleViaje.error =>
        rechazo == null ? 'No pudimos cargar el detalle.' : _mensaje(rechazo),
      FaseDetalleViaje.noDisponible => 'Detalle no disponible.',
      FaseDetalleViaje.operando => 'Procesando solicitud.',
      FaseDetalleViaje.recargando => 'Actualizando detalle.',
      _ => null,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (confirmado != null)
          Text('Estado confirmado: ${confirmado.estado.etiqueta}'),
        if (mensaje != null) Text(mensaje),
        if (c.fase == FaseDetalleViaje.incierto && c.estadoConsultado != null)
          Text('Último estado consultado: ${c.estadoConsultado!.etiqueta}'),
        if (c.fase == FaseDetalleViaje.incierto && rechazo != null)
          Text(_mensaje(rechazo)),
        if (c.ocupado)
          const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Procesando viaje',
            ),
          ),
        if (c.puedeIniciar)
          _boton('Iniciar viaje', _confirmando ? null : c.iniciar),
        if (c.puedeFinalizar)
          _boton(
            'Finalizar viaje',
            _confirmando ? null : () => _confirmarFinalizacion(),
          ),
        if (c.fase == FaseDetalleViaje.incierto && !c.ocupado)
          _boton('Consultar estado', c.consultar),
        if (c.puedeRepetir)
          _boton(
            c.operacionPendiente == OperacionViaje.inicio
                ? 'Reintentar inicio'
                : 'Reintentar finalización',
            _confirmando
                ? null
                : c.operacionPendiente == OperacionViaje.inicio
                ? c.repetir
                : () => _confirmarFinalizacion(reintento: true),
          ),
        if (c.fase == FaseDetalleViaje.confirmadoSinDetalle ||
            c.fase == FaseDetalleViaje.error)
          _boton('Actualizar detalle', c.consultar),
        if (c.fase == FaseDetalleViaje.noDisponible)
          _boton('Reintentar', c.consultar),
      ],
    );
  }

  Widget _boton(String texto, VoidCallback? accion) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: ElevatedButton(
      onPressed: accion,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, AppSpacing.driverTouchTarget),
      ),
      child: Text(texto),
    ),
  );

  String _mensaje(RechazoOperacionViaje rechazo) => switch (rechazo.motivo) {
    MotivoRechazoViaje.validacion => 'La solicitud no es válida.',
    MotivoRechazoViaje.noAutenticado =>
      'Necesitás una sesión válida para continuar.',
    MotivoRechazoViaje.sinPermiso => 'No tenés permiso para esta operación.',
    MotivoRechazoViaje.noDisponible => 'Viaje no disponible.',
    MotivoRechazoViaje.conflicto =>
      rechazo.codigo == 'VEHICULO_NO_ASIGNADO'
          ? 'El viaje necesita un vehículo asignado para iniciarse.'
          : 'El estado del viaje no permite esta operación. Actualizá el detalle.',
  };
}
