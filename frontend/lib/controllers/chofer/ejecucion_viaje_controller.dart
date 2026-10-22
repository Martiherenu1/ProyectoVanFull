import 'package:flutter/foundation.dart';

import '../../models/chofer/operacion_asignada.dart';
import '../../models/chofer/viaje_resumen.dart';

/// null representa detalle no disponible, sin distinguir ajeno de inexistente.
typedef CargarDetalleViajeChofer = Future<OperacionAsignada?> Function(
  int idViaje,
);

/// El futuro adaptador invocará el POST sin cuerpo y devolverá su Viaje.
typedef CambiarEstadoViajeChofer = Future<ViajeResumen> Function(int idViaje);

enum MotivoRechazoViaje {
  validacion,
  noAutenticado,
  sinPermiso,
  noDisponible,
  conflicto,
}

/// Rechazo conocido de esta solicitud (400/401/403/404/409).
/// No demuestra el resultado de una solicitud anterior incierta.
class RechazoOperacionViaje implements Exception {
  const RechazoOperacionViaje(this.motivo, {this.codigo});

  final MotivoRechazoViaje motivo;
  final String? codigo;
}

/// No hay evidencia concluyente de que la escritura se confirmó o rechazó.
/// También se trata como incierto un fallo no clasificado por el adaptador.
class ResultadoViajeIncierto implements Exception {
  const ResultadoViajeIncierto();
}

class AccionesEjecucionViaje {
  const AccionesEjecucionViaje({
    required this.iniciar,
    required this.finalizar,
    this.onRechazo,
  });

  final CambiarEstadoViajeChofer iniciar;
  final CambiarEstadoViajeChofer finalizar;

  /// Permite al contenedor común resolver sesión/permisos, sin login propio.
  final ValueChanged<RechazoOperacionViaje>? onRechazo;
}

enum OperacionViaje { inicio, finalizacion }

enum FaseDetalleViaje {
  cargando,
  listo,
  error,
  noDisponible,
  operando,
  recargando,
  incierto,
  confirmadoSinDetalle,
}

class _OperacionEnviada {
  const _OperacionEnviada(this.operacion, this.estadoPrevio);
  final OperacionViaje operacion;
  final EstadoViaje estadoPrevio;

  bool resueltaPor(EstadoViaje estado) => switch (operacion) {
    OperacionViaje.inicio =>
      estado == EstadoViaje.enCurso ||
          estado == EstadoViaje.finalizado ||
          estado == EstadoViaje.cancelado,
    OperacionViaje.finalizacion =>
      estado == EstadoViaje.finalizado || estado == EstadoViaje.cancelado,
  };
}

/// Coordina la lectura existente y las escrituras: nunca combina un Viaje nuevo
/// con listas anteriores. Las generaciones invalidan UI, no efectos en backend.
class EjecucionViajeController extends ChangeNotifier {
  EjecucionViajeController({
    required this._idViaje,
    required this._cargarDetalle,
    this._acciones,
  });

  int _idViaje;
  CargarDetalleViajeChofer _cargarDetalle;
  AccionesEjecucionViaje? _acciones;
  int _generacion = 0;
  Object _contexto = Object();
  bool _activo = true;
  _OperacionEnviada? _enviada;
  _OperacionEnviada? _pendiente;
  bool _repetible = false;

  FaseDetalleViaje _fase = FaseDetalleViaje.cargando;
  OperacionAsignada? _detalle;
  ViajeResumen? _viajeConfirmado;
  EstadoViaje? _estadoConsultado;
  RechazoOperacionViaje? _rechazo;

  FaseDetalleViaje get fase => _fase;
  OperacionAsignada? get detalle => _detalle;
  ViajeResumen? get viajeConfirmado => _viajeConfirmado;
  EstadoViaje? get estadoConsultado => _estadoConsultado;
  RechazoOperacionViaje? get rechazo => _rechazo;
  Object get contexto => _contexto;
  OperacionViaje? get operacionPendiente => _pendiente?.operacion;

  bool get ocupado => switch (_fase) {
    FaseDetalleViaje.cargando ||
    FaseDetalleViaje.operando ||
    FaseDetalleViaje.recargando => true,
    _ => false,
  };

  bool get puedeIniciar =>
      _activo &&
      _acciones != null &&
      _fase == FaseDetalleViaje.listo &&
      _detalle?.viaje.estado == EstadoViaje.programado;
  bool get puedeFinalizar =>
      _activo &&
      _acciones != null &&
      _fase == FaseDetalleViaje.listo &&
      _detalle?.viaje.estado == EstadoViaje.enCurso;
  bool get puedeRepetir =>
      _activo &&
      _acciones != null &&
      _fase == FaseDetalleViaje.incierto &&
      _repetible;

  void actualizarContexto({
    required int idViaje,
    required CargarDetalleViajeChofer cargarDetalle,
    AccionesEjecucionViaje? acciones,
  }) {
    if (!_activo) return;
    // En el mismo viaje, cambiar la fuente no prueba que un POST en vuelo falló.
    _pendiente = idViaje == _idViaje ? _pendiente ?? _enviada : null;
    _enviada = null;
    _idViaje = idViaje;
    _cargarDetalle = cargarDetalle;
    _acciones = acciones;
    _contexto = Object();
    _generacion++;
    _detalle = null;
    _viajeConfirmado = null;
    _estadoConsultado = null;
    _rechazo = null;
    _repetible = false;
    _cargar();
  }

  /// Lectura explícita; nunca reenvía una transición automáticamente.
  Future<void> consultar() async {
    if (!_activo || ocupado && _generacion != 0) return;
    await _cargar();
  }

  bool _vigente(int generacion) => _activo && generacion == _generacion;

  void _avisar() {
    if (_activo) notifyListeners();
  }

  void _notificarRechazo(RechazoOperacionViaje rechazo) {
    try {
      _acciones?.onRechazo?.call(rechazo);
    } catch (error, stack) {
      // Un fallo del contenedor no cambia el resultado conocido del servidor.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'ejecucion de viaje',
        ),
      );
    }
  }

  Future<void> _cargar() async {
    final generacion = ++_generacion;
    final id = _idViaje;
    final fuente = _cargarDetalle;
    _detalle = null;
    _rechazo = null;
    _repetible = false;
    _fase = _viajeConfirmado == null
        ? FaseDetalleViaje.cargando
        : FaseDetalleViaje.recargando;
    _avisar();
    try {
      final recibido = await fuente(id);
      if (!_vigente(generacion)) return;
      if (recibido == null) {
        _falloLectura(
          const RechazoOperacionViaje(MotivoRechazoViaje.noDisponible),
        );
        return;
      }
      if (recibido.viaje.idViaje != id) {
        throw const FormatException('Detalle de otro viaje');
      }
      final confirmado = _viajeConfirmado?.estado;
      // Los POST actuales confirman en_curso o finalizado. Una lectura puede
      // conservar ese estado o avanzar de en_curso a finalizado, nunca retroceder.
      final compatible =
          confirmado == null ||
          recibido.viaje.estado == confirmado ||
          confirmado == EstadoViaje.enCurso &&
              recibido.viaje.estado == EstadoViaje.finalizado;
      if (!compatible) {
        _fase = FaseDetalleViaje.confirmadoSinDetalle;
        _avisar();
        return;
      }
      _estadoConsultado = recibido.viaje.estado;
      if (_pendiente != null &&
          !_pendiente!.resueltaPor(recibido.viaje.estado)) {
        _repetible = recibido.viaje.estado == _pendiente!.estadoPrevio;
        _fase = FaseDetalleViaje.incierto;
        // Una lectura del estado previo no prueba que el POST no siga en vuelo.
      } else {
        _pendiente = null;
        _viajeConfirmado = null;
        _detalle = recibido;
        _fase = FaseDetalleViaje.listo;
      }
      _avisar();
    } catch (error) {
      if (!_vigente(generacion)) return;
      _falloLectura(error);
    }
  }

  void _falloLectura(Object error) {
    _rechazo = error is RechazoOperacionViaje ? error : null;
    _fase = _pendiente != null
        ? FaseDetalleViaje.incierto
        : _viajeConfirmado != null
        ? FaseDetalleViaje.confirmadoSinDetalle
        : _rechazo?.motivo == MotivoRechazoViaje.noDisponible
        ? FaseDetalleViaje.noDisponible
        : FaseDetalleViaje.error;
    _avisar();
    if (_rechazo != null) _notificarRechazo(_rechazo!);
  }

  Future<void> iniciar() async {
    if (puedeIniciar) await _ejecutar(OperacionViaje.inicio);
  }

  Future<void> finalizar() async {
    if (puedeFinalizar) await _ejecutar(OperacionViaje.finalizacion);
  }

  Future<void> repetir() async {
    if (puedeRepetir) await _ejecutar(_pendiente!.operacion);
  }

  Future<void> _ejecutar(OperacionViaje operacion) async {
    final generacion = ++_generacion; // Invalida toda lectura previa.
    final id = _idViaje;
    final fuente = operacion == OperacionViaje.inicio
        ? _acciones!.iniciar
        : _acciones!.finalizar;
    final enviada =
        _pendiente ?? _OperacionEnviada(operacion, _detalle!.viaje.estado);
    _enviada = enviada;
    _detalle = null;
    _rechazo = null;
    _repetible = false;
    _fase = FaseDetalleViaje.operando;
    _avisar();
    try {
      final viaje = await fuente(id);
      if (!_vigente(generacion)) return;
      if (viaje.idViaje != id) {
        throw const FormatException('Respuesta de otro viaje');
      }
      _enviada = null;
      _pendiente = null;
      _viajeConfirmado = viaje; // También si iniciar devuelve finalizado.
    } catch (error) {
      if (!_vigente(generacion)) return;
      _enviada = null;
      if (error is RechazoOperacionViaje) {
        _rechazo = error;
        // Un rechazo del reintento no resuelve la solicitud anterior incierta.
        _fase = _pendiente == null
            ? FaseDetalleViaje.error
            : FaseDetalleViaje.incierto;
        _avisar();
        _notificarRechazo(error);
      } else {
        _pendiente = enviada;
        _fase = FaseDetalleViaje.incierto;
        _avisar();
      }
      return;
    }
    await _cargar();
  }

  @override
  void dispose() {
    _activo = false;
    _generacion++;
    super.dispose();
  }
}
