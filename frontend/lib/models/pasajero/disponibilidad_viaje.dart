import '../chofer/viaje_resumen.dart' show SentidoViaje;

/// Lectura de Disponibilidad en GET /servicios/disponibilidad (CU-002).
/// El cupo lo calcula el backend; acá solo se muestra.
class DisponibilidadViaje {
  const DisponibilidadViaje({
    required this.idViaje,
    required this.idServicio,
    required this.idRecorrido,
    required this.fecha,
    required this.sentido,
    this.horario,
    this.cupoDisponible,
  });

  factory DisponibilidadViaje.fromJson(Map<String, dynamic> json) {
    final fechaTexto = json['fecha'] as String;
    final fecha = DateTime.tryParse(fechaTexto);
    // DateTime normaliza fechas imposibles. No mostrar otro día en silencio.
    if (fecha == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fechaTexto) ||
        fecha.year != int.parse(fechaTexto.substring(0, 4)) ||
        fecha.month != int.parse(fechaTexto.substring(5, 7)) ||
        fecha.day != int.parse(fechaTexto.substring(8, 10))) {
      throw const FormatException('Fecha de viaje inválida');
    }

    return DisponibilidadViaje(
      idViaje: json['id_viaje'] as int,
      idServicio: json['id_servicio'] as int,
      idRecorrido: json['id_recorrido'] as int,
      fecha: fecha,
      horario: json['horario'] as String?,
      sentido: SentidoViaje.values.firstWhere(
        (sentido) => sentido.valorApi == json['sentido'],
        orElse: () => throw const FormatException('Sentido de viaje inválido'),
      ),
      cupoDisponible: json['cupo_disponible'] as int?,
    );
  }

  final int idViaje;
  final int idServicio;
  final int idRecorrido;
  final DateTime fecha;

  /// "HH:MM". Un viaje en planificación puede no tener horario.
  final String? horario;
  final SentidoViaje sentido;

  /// Ausente cuando el backend no puede determinarlo: no equivale a 0.
  final int? cupoDisponible;
}
