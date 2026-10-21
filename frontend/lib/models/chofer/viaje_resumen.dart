/// Valores contratados por CU-029; las etiquetas son solo de presentación.
enum SentidoViaje {
  ida('IDA', 'Ida'),
  vuelta('VUELTA', 'Vuelta');

  const SentidoViaje(this.valorApi, this.etiqueta);

  final String valorApi;
  final String etiqueta;
}

enum EstadoViaje {
  programado('programado', 'Programado'),
  enCurso('en_curso', 'En curso'),
  finalizado('finalizado', 'Finalizado'),
  cancelado('cancelado', 'Cancelado');

  const EstadoViaje(this.valorApi, this.etiqueta);

  final String valorApi;
  final String etiqueta;
}

/// Lectura de Viaje en GET /choferes/me/viajes, sin reglas de negocio.
/// Los identificadores no representan nombres de servicios o recorridos.
class ViajeResumen {
  const ViajeResumen({
    required this.idViaje,
    required this.idServicio,
    required this.idRecorrido,
    required this.fecha,
    required this.sentido,
    required this.estado,
    this.idVehiculo,
    this.idChofer,
    this.horario,
  });

  factory ViajeResumen.fromJson(Map<String, dynamic> json) {
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

    return ViajeResumen(
      idViaje: json['id_viaje'] as int,
      idServicio: json['id_servicio'] as int,
      idRecorrido: json['id_recorrido'] as int,
      idVehiculo: json['id_vehiculo'] as int?,
      idChofer: json['id_chofer'] as int?,
      fecha: fecha,
      horario: json['horario'] as String?,
      sentido: SentidoViaje.values.firstWhere(
        (sentido) => sentido.valorApi == json['sentido'],
        orElse: () => throw const FormatException('Sentido de viaje inválido'),
      ),
      estado: EstadoViaje.values.firstWhere(
        (estado) => estado.valorApi == json['estado'],
        orElse: () => throw const FormatException('Estado de viaje inválido'),
      ),
    );
  }

  final int idViaje;
  final int idServicio;
  final int idRecorrido;
  final int? idVehiculo;
  final int? idChofer;
  final DateTime fecha;
  final String? horario;
  final SentidoViaje sentido;
  final EstadoViaje estado;
}
