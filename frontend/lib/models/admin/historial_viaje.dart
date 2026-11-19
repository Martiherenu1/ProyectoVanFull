/// Criterios del historial de viajes (CU-026). Todos opcionales.
final class HistorialFiltros {
  const HistorialFiltros({this.desde, this.hasta, this.estado, this.sentido});

  final DateTime? desde;
  final DateTime? hasta;
  final String? estado;
  final String? sentido;

  Map<String, String> toQuery() => {
    if (desde != null) 'desde': fechaIso(desde!),
    if (hasta != null) 'hasta': fechaIso(hasta!),
    'estado': ?estado,
    'sentido': ?sentido,
  };
}

/// `YYYY-MM-DD`, el único formato que acepta la API.
String fechaIso(DateTime f) =>
    '${f.year.toString().padLeft(4, '0')}-'
    '${f.month.toString().padLeft(2, '0')}-'
    '${f.day.toString().padLeft(2, '0')}';

final class PersonaHistorial {
  const PersonaHistorial({
    required this.idPersona,
    required this.nombre,
    required this.apellido,
  });

  factory PersonaHistorial.fromJson(Map<String, dynamic> json) =>
      PersonaHistorial(
        idPersona: json['id_persona'] as int,
        nombre: json['nombre'] as String,
        apellido: json['apellido'] as String,
      );

  final int idPersona;
  final String nombre;
  final String apellido;

  String get nombreCompleto => '$nombre $apellido';
}

/// Un viaje anterior, tal como lo lista el historial.
final class HistorialViaje {
  const HistorialViaje({
    required this.idViaje,
    required this.fecha,
    required this.sentido,
    required this.estado,
    required this.tipoServicio,
    required this.idRecorrido,
    this.horario,
    this.chofer,
    this.patente,
  });

  factory HistorialViaje.fromJson(Map<String, dynamic> json) => HistorialViaje(
    idViaje: json['id_viaje'] as int,
    fecha: json['fecha'] as String,
    horario: json['horario'] as String?,
    sentido: json['sentido'] as String,
    estado: json['estado'] as String,
    tipoServicio: json['tipo_servicio'] as String,
    idRecorrido: json['id_recorrido'] as int,
    chofer: json['chofer'] == null
        ? null
        : PersonaHistorial.fromJson(json['chofer'] as Map<String, dynamic>),
    patente: (json['vehiculo'] as Map<String, dynamic>?)?['patente'] as String?,
  );

  final int idViaje;
  final String fecha;
  final String? horario;
  final String sentido;
  final String estado;
  final String tipoServicio;
  final int idRecorrido;
  final PersonaHistorial? chofer;
  final String? patente;
}

final class ParadaHistorial {
  const ParadaHistorial({
    required this.orden,
    required this.idParada,
    this.nombre,
  });

  factory ParadaHistorial.fromJson(Map<String, dynamic> json) =>
      ParadaHistorial(
        orden: json['orden'] as int,
        idParada: json['id_parada'] as int,
        nombre: json['nombre_descripcion'] as String?,
      );

  final int orden;
  final int idParada;
  final String? nombre;

  String get etiqueta => nombre ?? 'Parada $idParada';
}

/// Solo cantidades: el historial no expone datos de los pasajeros.
final class ConteosHistorial {
  const ConteosHistorial({
    required this.provisionales,
    required this.consolidadas,
    required this.canceladas,
    required this.abordajes,
    required this.ausencias,
  });

  factory ConteosHistorial.fromJson(Map<String, dynamic> json) =>
      ConteosHistorial(
        provisionales: json['reservas_provisionales'] as int,
        consolidadas: json['reservas_consolidadas'] as int,
        canceladas: json['reservas_canceladas'] as int,
        abordajes: json['abordajes'] as int,
        ausencias: json['ausencias'] as int,
      );

  final int provisionales;
  final int consolidadas;
  final int canceladas;
  final int abordajes;
  final int ausencias;
}

final class HistorialViajeDetalle {
  const HistorialViajeDetalle({
    required this.viaje,
    required this.paradas,
    required this.conteos,
    this.capacidadPlanificada,
  });

  factory HistorialViajeDetalle.fromJson(Map<String, dynamic> json) =>
      HistorialViajeDetalle(
        viaje: HistorialViaje.fromJson(json),
        capacidadPlanificada: json['capacidad_planificada'] as int?,
        paradas: (json['paradas'] as List)
            .map((e) => ParadaHistorial.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        conteos: ConteosHistorial.fromJson(
          json['conteos'] as Map<String, dynamic>,
        ),
      );

  final HistorialViaje viaje;
  final int? capacidadPlanificada;
  final List<ParadaHistorial> paradas;
  final ConteosHistorial conteos;
}
