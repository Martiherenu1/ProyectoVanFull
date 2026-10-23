import '../chofer/viaje_resumen.dart' show SentidoViaje;

/// Valores contratados de Reserva.estado. `consolidada` se le muestra al
/// pasajero como "Confirmada" (brief §10).
enum EstadoReserva {
  provisional('provisional', 'Provisional'),
  consolidada('consolidada', 'Confirmada'),
  cancelada('cancelada', 'Cancelada');

  const EstadoReserva(this.valorApi, this.etiqueta);

  final String valorApi;
  final String etiqueta;
}

/// Lectura de Reserva en POST /reservas (CU-003). Los datos del viaje
/// (`fecha`, `horario`, `sentido`) vienen en la respuesta; no se recalculan.
class Reserva {
  const Reserva({
    required this.idReserva,
    required this.idViaje,
    required this.idRecorrido,
    required this.ordenParada,
    required this.fecha,
    required this.sentido,
    required this.estado,
    this.horario,
  });

  factory Reserva.fromJson(Map<String, dynamic> json) {
    final fechaTexto = json['fecha'] as String;
    final fecha = DateTime.tryParse(fechaTexto);
    // DateTime normaliza fechas imposibles. No mostrar otro día en silencio.
    if (fecha == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fechaTexto) ||
        fecha.year != int.parse(fechaTexto.substring(0, 4)) ||
        fecha.month != int.parse(fechaTexto.substring(5, 7)) ||
        fecha.day != int.parse(fechaTexto.substring(8, 10))) {
      throw const FormatException('Fecha de reserva inválida');
    }

    return Reserva(
      idReserva: json['id_reserva'] as int,
      idViaje: json['id_viaje'] as int,
      idRecorrido: json['id_recorrido'] as int,
      ordenParada: json['orden_parada'] as int,
      fecha: fecha,
      horario: json['horario'] as String?,
      sentido: SentidoViaje.values.firstWhere(
        (sentido) => sentido.valorApi == json['sentido'],
        orElse: () => throw const FormatException('Sentido de viaje inválido'),
      ),
      estado: EstadoReserva.values.firstWhere(
        (estado) => estado.valorApi == json['estado'],
        orElse: () => throw const FormatException('Estado de reserva inválido'),
      ),
    );
  }

  final int idReserva;
  final int idViaje;
  final int idRecorrido;

  /// Parada de ascenso dentro del recorrido (GET /recorridos/{id}/paradas).
  final int ordenParada;
  final DateTime fecha;

  /// "HH:MM". Es `null` si el viaje todavía no tiene horario.
  final String? horario;
  final SentidoViaje sentido;
  final EstadoReserva estado;
}

/// Cuerpo de error del contrato (`{"error": {codigo, mensaje, detalles}}`)
/// que el adaptador común lanza cuando una operación sobre una reserva
/// (POST /reservas, POST /reservas/{id}/cancelacion) responde 400 o 409.
class ReservaRechazada implements Exception {
  const ReservaRechazada({
    required this.codigo,
    required this.mensaje,
    this.listaEspera = false,
  });

  factory ReservaRechazada.fromJson(Map<String, dynamic> json) {
    final error = json['error'] as Map<String, dynamic>;
    final detalles = error['detalles'] as Map<String, dynamic>?;
    return ReservaRechazada(
      codigo: error['codigo'] as String,
      mensaje: error['mensaje'] as String,
      listaEspera: detalles?['lista_espera'] == true,
    );
  }

  /// Códigos de CU-003: CUPO_NO_DISPONIBLE, RESERVA_DUPLICADA_DEL_DIA,
  /// RESERVA_CANCELADA_PREVIA, VIAJE_NO_RESERVABLE y PARADA_NO_VALIDA; de
  /// CU-004: RESERVA_NO_CANCELABLE y VIAJE_NO_CANCELABLE.
  final String codigo;
  final String mensaje;

  /// `detalles.lista_espera` del 409 de cupo. La incorporación a la lista no
  /// tiene operación todavía (Issue #34).
  final bool listaEspera;

  @override
  String toString() => 'ReservaRechazada($codigo)';
}

/// Lectura de ResultadoCancelacion en POST /reservas/{id}/cancelacion (CU-004).
class ResultadoCancelacion {
  const ResultadoCancelacion({
    required this.reserva,
    required this.cupoLiberado,
    required this.penalidadAplicada,
    required this.importePenalidad,
    required this.motivo,
  });

  factory ResultadoCancelacion.fromJson(Map<String, dynamic> json) =>
      ResultadoCancelacion(
        reserva: Reserva.fromJson(json['reserva'] as Map<String, dynamic>),
        cupoLiberado: json['cupo_liberado'] as bool,
        penalidadAplicada: json['penalidad_aplicada'] as bool,
        importePenalidad: (json['importe_penalidad'] as num).toDouble(),
        motivo: json['motivo'] as String,
      );

  /// La reserva ya cancelada.
  final Reserva reserva;
  final bool cupoLiberado;
  final bool penalidadAplicada;
  final double importePenalidad;

  /// La regla que decidió la consecuencia económica, en texto del backend.
  final String motivo;
}
