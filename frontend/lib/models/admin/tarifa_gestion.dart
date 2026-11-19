/// Tarifa tal como la gestiona el dueño (CU-031).
///
/// `tipo` y `fechaVigencia` se muestran sin interpretarlos: la v1.3 del CU deja
/// pendientes la estructura de parámetros, las vigencias y el historial.
final class TarifaGestion {
  const TarifaGestion({
    required this.idTarifa,
    required this.nombre,
    required this.importe,
    required this.fechaCreacion,
    this.tipo,
    this.fechaVigencia,
  });

  factory TarifaGestion.fromJson(Map<String, dynamic> json) => TarifaGestion(
    idTarifa: json['id_tarifa'] as int,
    nombre: json['nombre'] as String,
    tipo: json['tipo'] as String?,
    importe: (json['importe'] as num).toDouble(),
    fechaCreacion: json['fecha_creacion'] as String,
    fechaVigencia: json['fecha_vigencia'] as String?,
  );

  final int idTarifa;
  final String nombre;
  final String? tipo;
  final double importe;
  final String fechaCreacion;
  final String? fechaVigencia;
}

/// Alta. Los opcionales vacíos no se envían.
final class TarifaGestionCreate {
  const TarifaGestionCreate({
    required this.nombre,
    required this.importe,
    this.tipo,
    this.fechaVigencia,
  });

  final String nombre;
  final double importe;
  final String? tipo;
  final String? fechaVigencia;

  Map<String, Object?> toJson() => {
    'nombre': nombre,
    'importe': importe,
    if (tipo != null && tipo!.isNotEmpty) 'tipo': tipo,
    if (fechaVigencia != null && fechaVigencia!.isNotEmpty)
      'fecha_vigencia': fechaVigencia,
  };
}
