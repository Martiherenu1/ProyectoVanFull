import '../chofer/viaje_resumen.dart' show EstadoViaje, SentidoViaje;

/// Cuerpo de `POST /viajes` según `ViajeCreate` de OpenAPI.
final class ViajeCreate {
  const ViajeCreate({
    required this.idServicio,
    required this.idRecorrido,
    required this.fecha,
    required this.sentido,
    this.idVehiculo,
    this.idChofer,
    this.horario,
    this.capacidadPlanificada,
  });

  final int idServicio;
  final int idRecorrido;
  final int? idVehiculo;
  final int? idChofer;
  final DateTime fecha;
  final String? horario;
  final SentidoViaje sentido;
  final int? capacidadPlanificada;

  Map<String, dynamic> toJson() => {
    'id_servicio': idServicio,
    'id_recorrido': idRecorrido,
    'id_vehiculo': idVehiculo,
    'id_chofer': idChofer,
    'fecha': _fechaIso(fecha),
    'horario': ?horario,
    'sentido': sentido.valorApi,
    'capacidad_planificada': ?capacidadPlanificada,
  };

  static String _fechaIso(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';
}

/// La respuesta 201 no respeta el schema `Viaje` del contrato.
final class ViajeCreadoInvalidoException implements Exception {
  const ViajeCreadoInvalidoException();

  @override
  String toString() => 'La respuesta de creación del viaje es inválida.';
}

/// Respuesta de `POST /viajes` según `Viaje` de OpenAPI.
///
/// El contrato vigente no declara propiedades obligatorias en este schema;
/// por eso cada valor puede estar ausente, aunque si aparece debe respetar su
/// tipo y sus valores permitidos.
final class ViajeCreado {
  const ViajeCreado({
    this.idViaje,
    this.idServicio,
    this.idRecorrido,
    this.idVehiculo,
    this.idChofer,
    this.fecha,
    this.horario,
    this.sentido,
    this.estado,
  });

  factory ViajeCreado.fromJson(Map<String, dynamic> json) {
    final fechaTexto = _opcional<String>(json, 'fecha');
    final fecha = fechaTexto == null ? null : _leerFecha(fechaTexto);
    final sentidoTexto = _opcional<String>(json, 'sentido');
    final estadoTexto = _opcional<String>(json, 'estado');

    return ViajeCreado(
      idViaje: _opcional<int>(json, 'id_viaje'),
      idServicio: _opcional<int>(json, 'id_servicio'),
      idRecorrido: _opcional<int>(json, 'id_recorrido'),
      idVehiculo: _opcional<int>(json, 'id_vehiculo', admiteNull: true),
      idChofer: _opcional<int>(json, 'id_chofer', admiteNull: true),
      fecha: fecha,
      horario: _opcional<String>(json, 'horario'),
      sentido: sentidoTexto == null
          ? null
          : SentidoViaje.values.firstWhere(
              (valor) => valor.valorApi == sentidoTexto,
              orElse: _invalido,
            ),
      estado: estadoTexto == null
          ? null
          : EstadoViaje.values.firstWhere(
              (valor) => valor.valorApi == estadoTexto,
              orElse: _estadoInvalido,
            ),
    );
  }

  final int? idViaje;
  final int? idServicio;
  final int? idRecorrido;
  final int? idVehiculo;
  final int? idChofer;
  final DateTime? fecha;
  final String? horario;
  final SentidoViaje? sentido;
  final EstadoViaje? estado;

  static T? _opcional<T>(
    Map<String, dynamic> json,
    String clave, {
    bool admiteNull = false,
  }) {
    if (!json.containsKey(clave)) return null;
    final valor = json[clave];
    if (valor == null && admiteNull) return null;
    if (valor is T) return valor;
    throw const ViajeCreadoInvalidoException();
  }

  static DateTime _leerFecha(String texto) {
    final fecha = DateTime.tryParse(texto);
    if (fecha == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(texto) ||
        fecha.year != int.parse(texto.substring(0, 4)) ||
        fecha.month != int.parse(texto.substring(5, 7)) ||
        fecha.day != int.parse(texto.substring(8, 10))) {
      throw const ViajeCreadoInvalidoException();
    }
    return fecha;
  }

  static SentidoViaje _invalido() {
    throw const ViajeCreadoInvalidoException();
  }

  static EstadoViaje _estadoInvalido() {
    throw const ViajeCreadoInvalidoException();
  }
}
