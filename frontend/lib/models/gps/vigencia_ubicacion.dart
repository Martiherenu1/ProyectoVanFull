import 'ubicacion_viaje.dart';

/// Edad contractual acotada. No mide la edad física ni la conexión del chofer.
class VigenciaUbicacion {
  static const desactualizada = 'Información desactualizada';
  static const incierta = 'Vigencia no confirmada';
  static const noVerificable = 'Antigüedad no verificable';
  static const sinMarca = 'Sin marca de desactualización en la última consulta';
  static const limite = Duration(seconds: 30);

  UbicacionViaje? _posicion;
  DateTime? _ultimaEvaluacion;
  Duration? _edad, _rtt, _recepcion, _ultimoReloj;
  bool _acreditada = false;

  void limpiar() {
    _posicion = null;
    _ultimaEvaluacion = null;
    _acreditada = false;
    invalidarAncla();
  }

  void invalidarAncla() {
    _edad = _rtt = _recepcion = _ultimoReloj = null;
  }

  bool _mismoP(UbicacionViaje p) {
    final anterior = _posicion;
    return anterior != null &&
        anterior.idViaje == p.idViaje &&
        anterior.fecha == p.fecha &&
        anterior.latitud == p.latitud &&
        anterior.longitud == p.longitud;
  }

  void aceptar(
    UbicacionViaje p, {
    required Duration? inicio,
    required Duration? recepcion,
    bool continuidad = true,
  }) {
    if (!_mismoP(p)) {
      limpiar();
    } else if (continuidad && recepcion != null) {
      // Acreditar el envejecimiento del ancla anterior antes de sustituirla.
      texto(recepcion);
    }
    _posicion = p;
    _acreditada = _acreditada || p.desactualizada;
    final s = p.fechaEvaluacion;
    if (!continuidad ||
        !p.sinCache ||
        s == null ||
        !s.isUtc ||
        inicio == null ||
        recepcion == null ||
        inicio.isNegative ||
        recepcion < inicio ||
        (_ultimoReloj != null && recepcion < _ultimoReloj!)) {
      invalidarAncla();
      return;
    }
    final a = s.difference(p.fecha);
    if (a.isNegative || (a > limite) != p.desactualizada) {
      invalidarAncla();
      return;
    }
    final ultima = _ultimaEvaluacion;
    if (ultima != null && !s.isAfter(ultima)) {
      // Una respuesta repetida no crea un ancla nueva ni rejuvenece P.
      if (s.isBefore(ultima)) invalidarAncla();
      return;
    }
    _ultimaEvaluacion = s;
    _edad = a;
    _rtt = recepcion - inicio;
    _recepcion = _ultimoReloj = recepcion;
    texto(recepcion);
  }

  String texto(Duration? ahora) {
    if (_acreditada) return desactualizada;
    if (ahora == null ||
        ahora.isNegative ||
        (_ultimoReloj != null && ahora < _ultimoReloj!)) {
      invalidarAncla();
      return noVerificable;
    }
    _ultimoReloj = ahora;
    final edad = _edad, rtt = _rtt, recepcion = _recepcion;
    if (edad == null || rtt == null || recepcion == null || ahora < recepcion) {
      return noVerificable;
    }
    final minima = edad + (ahora - recepcion);
    if (minima > limite) {
      _acreditada = true;
      return desactualizada;
    }
    return minima + rtt > limite ? incierta : sinMarca;
  }
}
