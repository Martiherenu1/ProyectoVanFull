import '../chofer/viaje_resumen.dart' show SentidoViaje;

/// Cuerpo de `PATCH /viajes/{id_viaje}` según `ViajeUpdate` de OpenAPI.
final class ViajeUpdate {
  const ViajeUpdate({
    required this.fecha,
    required this.horario,
    required this.sentido,
    required this.capacidadPlanificada,
    required this.idChofer,
    required this.idVehiculo,
  });

  final DateTime fecha;
  final String? horario;
  final SentidoViaje sentido;
  final int? capacidadPlanificada;
  final int? idChofer;
  final int? idVehiculo;

  Map<String, dynamic> toJson() => {
    'fecha': _fechaIso(fecha),
    'horario': horario,
    'sentido': sentido.valorApi,
    'capacidad_planificada': capacidadPlanificada,
    'id_chofer': idChofer,
    'id_vehiculo': idVehiculo,
  };

  static String _fechaIso(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';
}
