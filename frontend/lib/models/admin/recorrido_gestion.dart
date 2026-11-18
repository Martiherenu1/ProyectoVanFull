/// Parada del catálogo, tal como la gestiona administración (CU-019).
final class ParadaCatalogo {
  const ParadaCatalogo({
    required this.idParada,
    this.nombre,
    this.direccion,
    this.latitud,
    this.longitud,
  });

  factory ParadaCatalogo.fromJson(Map<String, dynamic> json) => ParadaCatalogo(
    idParada: json['id_parada'] as int,
    nombre: json['nombre_descripcion'] as String?,
    direccion: json['direccion'] as String?,
    latitud: (json['latitud'] as num?)?.toDouble(),
    longitud: (json['longitud'] as num?)?.toDouble(),
  );

  final int idParada;
  final String? nombre;
  final String? direccion;
  final double? latitud;
  final double? longitud;

  String get etiqueta => nombre ?? 'Parada $idParada';
}

/// Alta de una parada. Latitud y longitud van juntas o ninguna.
final class ParadaCatalogoCreate {
  const ParadaCatalogoCreate({
    required this.nombre,
    this.direccion,
    this.latitud,
    this.longitud,
  });

  final String nombre;
  final String? direccion;
  final double? latitud;
  final double? longitud;

  Map<String, Object?> toJson() => {
    'nombre_descripcion': nombre,
    if (direccion != null && direccion!.isNotEmpty) 'direccion': direccion,
    if (latitud != null && longitud != null) ...{
      'latitud': latitud,
      'longitud': longitud,
    },
  };
}

/// Parada dentro de un recorrido. [comprometida] es solo lectura (RN-021).
final class ParadaDeRecorrido {
  const ParadaDeRecorrido({
    required this.orden,
    required this.idParada,
    required this.comprometida,
    this.nombre,
  });

  factory ParadaDeRecorrido.fromJson(Map<String, dynamic> json) =>
      ParadaDeRecorrido(
        orden: json['orden'] as int,
        idParada: json['id_parada'] as int,
        nombre: json['nombre_descripcion'] as String?,
        comprometida: json['comprometida'] as bool,
      );

  final int orden;
  final int idParada;
  final String? nombre;
  final bool comprometida;

  String get etiqueta => nombre ?? 'Parada $idParada';
}

final class RecorridoGestion {
  const RecorridoGestion({required this.idRecorrido, required this.paradas});

  factory RecorridoGestion.fromJson(Map<String, dynamic> json) =>
      RecorridoGestion(
        idRecorrido: json['id_recorrido'] as int,
        paradas: (json['paradas'] as List)
            .map((e) => ParadaDeRecorrido.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  final int idRecorrido;
  final List<ParadaDeRecorrido> paradas;
}
