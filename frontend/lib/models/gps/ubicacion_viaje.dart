class UbicacionViaje {
  const UbicacionViaje(
    this.idViaje,
    this.latitud,
    this.longitud,
    this.fecha,
    this.desactualizada,
    this.etaMinutos, {
    this.fechaEvaluacion,
    this.sinCache = false,
  });
  final int idViaje;
  final double latitud, longitud;
  final DateTime fecha;
  final bool desactualizada;
  final int? etaMinutos;
  final DateTime? fechaEvaluacion;

  /// Solo el adaptador HTTP verifica no-store; el JSON por sí solo no lo acredita.
  final bool sinCache;

  factory UbicacionViaje.fromJson(
    Object? value,
    int id, {
    bool sinCache = false,
  }) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Ubicación inválida');
    }
    final lat = value['latitud'], lon = value['longitud'];
    final fecha = DateTime.tryParse(
      value['fecha_hora_posicion'] as String? ?? '',
    );
    final eta = value['eta_minutos'];
    final rawEvaluacion = value['fecha_hora_evaluacion'];
    final evaluacion = rawEvaluacion is String
        ? DateTime.tryParse(rawEvaluacion)
        : null;
    // Un metadato opcional inválido no elimina una posición válida: pierde el ancla.
    final evaluacionValida = evaluacion != null && evaluacion.isUtc
        ? evaluacion
        : null;
    if (value['id_viaje'] != id ||
        lat is! num ||
        lon is! num ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180 ||
        fecha == null ||
        !fecha.isUtc ||
        value['desactualizada'] is! bool ||
        (eta != null && (eta is! int || eta < 0))) {
      throw const FormatException('Ubicación inválida');
    }
    return UbicacionViaje(
      id,
      lat.toDouble(),
      lon.toDouble(),
      fecha,
      value['desactualizada'] as bool,
      eta as int?,
      fechaEvaluacion: evaluacionValida,
      sinCache: sinCache,
    );
  }
}
