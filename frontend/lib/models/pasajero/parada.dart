/// Lectura de Parada en GET /recorridos/{id}/paradas (CU-002).
class Parada {
  const Parada({
    required this.idParada,
    required this.orden,
    required this.comprometida,
    this.nombreDescripcion,
    this.direccion,
    this.latitud,
    this.longitud,
  });

  factory Parada.fromJson(Map<String, dynamic> json) => Parada(
    idParada: json['id_parada'] as int,
    orden: json['orden'] as int,
    comprometida: json['comprometida'] as bool,
    nombreDescripcion: json['nombre_descripcion'] as String?,
    direccion: json['direccion'] as String?,
    latitud: (json['latitud'] as num?)?.toDouble(),
    longitud: (json['longitud'] as num?)?.toDouble(),
  );

  final int idParada;

  /// Posición dentro del recorrido.
  final int orden;
  final bool comprometida;
  final String? nombreDescripcion;
  final String? direccion;
  final double? latitud;
  final double? longitud;

  /// Lo que se le muestra al pasajero: nombre, y si no hay, la dirección.
  String get titulo => nombreDescripcion ?? direccion ?? 'Parada $orden';

  /// La dirección como detalle, solo si no es lo mismo que el título.
  String? get detalle => nombreDescripcion != null ? direccion : null;
}
