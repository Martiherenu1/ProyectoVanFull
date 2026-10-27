import 'package:flutter/material.dart';

import '../../controllers/chofer/ejecucion_viaje_controller.dart';
import '../../controllers/chofer/asistencia_ubicacion_inicio.dart';
import '../../core/theme/app_spacing.dart';

/// Escrituras/reconciliación usan el coordinador; permisos y Ajustes son acciones
/// locales separadas. Su retorno nunca inicia ni reintenta un viaje.
class AccionesViajeChofer extends StatefulWidget {
  const AccionesViajeChofer({
    required this.controlador,
    this.asistenciaUbicacion,
    super.key,
  });

  final EjecucionViajeController controlador;
  final AsistenciaUbicacionInicio? asistenciaUbicacion;

  @override
  State<AccionesViajeChofer> createState() => _AccionesViajeChoferState();
}

class _AccionesViajeChoferState extends State<AccionesViajeChofer> {
  bool _confirmando = false;
  bool _gestionandoUbicacion = false;
  String? _mensajeAyuda;
  ResultadoPermisoUbicacion? _permisoSolicitado;

  Future<void> _ayudar(
    Future<(String, ResultadoPermisoUbicacion?)> Function() accion,
  ) async {
    if (_gestionandoUbicacion || _confirmando || widget.controlador.ocupado) {
      return;
    }
    final controlador = widget.controlador;
    final contexto = controlador.contexto;
    final asistencia = widget.asistenciaUbicacion;
    bool vigente() =>
        mounted &&
        widget.controlador == controlador &&
        controlador.contexto == contexto &&
        widget.asistenciaUbicacion == asistencia;
    setState(() {
      _gestionandoUbicacion = true;
      _mensajeAyuda = null;
    });
    try {
      final (mensaje, permiso) = await accion();
      if (!vigente()) return;
      setState(() {
        _mensajeAyuda = mensaje;
        if (permiso != null) _permisoSolicitado = permiso;
      });
    } catch (_) {
      if (vigente()) {
        setState(
          () => _mensajeAyuda = 'No se pudo completar la acción de ubicación.',
        );
      }
    } finally {
      if (mounted) setState(() => _gestionandoUbicacion = false);
    }
  }

  Future<void> _solicitarPermiso() => _ayudar(() async {
    final permiso = await widget.asistenciaUbicacion!.solicitarPermiso();
    final mensaje = switch (permiso) {
      ResultadoPermisoUbicacion.concedido => 'Permiso concedido. Pulsá Iniciar nuevamente para comprobar la ubicación.',
      ResultadoPermisoUbicacion.denegado =>
        'Permiso no concedido. Podés solicitarlo nuevamente.',
      ResultadoPermisoUbicacion.denegadoPermanentemente => 'Habilitá el permiso desde Ajustes de la app y pulsá Iniciar nuevamente.',
    };
    return (mensaje, permiso);
  });

  Future<void> _abrirAjustes({required bool app}) => _ayudar(() async {
    final asistencia = widget.asistenciaUbicacion!;
    final abierto = await (app
        ? asistencia.abrirAjustesApp()
        : asistencia.abrirAjustesUbicacion());
    return (
      abierto
          ? 'Al volver de Ajustes, pulsá Iniciar nuevamente para comprobar la ubicación.'
          : 'No se pudieron abrir los Ajustes.',
      null,
    );
  });

  Future<void> _iniciar({bool reintento = false}) async {
    setState(() {
      _mensajeAyuda = null;
      _permisoSolicitado = null;
    });
    if (reintento) {
      await widget.controlador.repetir();
    } else {
      await widget.controlador.iniciar();
    }
  }

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
        if (c.comprobandoUbicacion) const Text('Comprobando ubicación.'),
        if (c.mensajeUbicacion != null) Text(c.mensajeUbicacion!),
        if (_gestionandoUbicacion) const Text('Gestionando ubicación.'),
        if (_mensajeAyuda != null) Text(_mensajeAyuda!),
        if (widget.asistenciaUbicacion != null &&
            !c.ocupado &&
            (c.puedeIniciar ||
                c.puedeRepetir &&
                    c.operacionPendiente == OperacionViaje.inicio)) ...[
          if (c.bloqueoUbicacion == BloqueoUbicacionInicio.servicioDesactivado)
            _boton('Ajustes de ubicación', () => _abrirAjustes(app: false)),
          if (c.bloqueoUbicacion ==
                  BloqueoUbicacionInicio.permisoDenegadoPermanentemente ||
              _permisoSolicitado ==
                  ResultadoPermisoUbicacion.denegadoPermanentemente)
            _boton('Ajustes de la app', () => _abrirAjustes(app: true))
          else if (c.bloqueoUbicacion ==
              BloqueoUbicacionInicio.permisoNoConcedido)
            _boton('Solicitar permiso de ubicación', _solicitarPermiso),
        ],
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
          _boton('Iniciar viaje', _confirmando ? null : () => _iniciar()),
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
                ? () => _iniciar(reintento: true)
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
      onPressed: _gestionandoUbicacion ? null : accion,
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
