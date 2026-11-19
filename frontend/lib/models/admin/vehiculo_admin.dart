final class VehiculoAdmin {
  const VehiculoAdmin({
    required this.idVehiculo,
    required this.patente,
    required this.marca,
    required this.modelo,
    required this.capacidad,
    required this.disponibilidad,
  });

  factory VehiculoAdmin.fromJson(Map<String, dynamic> json) {
    final id = json['id_vehiculo'];
    final patente = json['patente'];
    final marca = json['marca'];
    final modelo = json['modelo'];
    final capacidad = json['capacidad'];
    final disponibilidad = json['disponibilidad'];
    if (id is! int ||
        patente is! String ||
        (marca != null && marca is! String) ||
        (modelo != null && modelo is! String) ||
        capacidad is! int ||
        capacidad < 1 ||
        disponibilidad is! bool) {
      throw const FormatException('Vehículo inválido.');
    }
    return VehiculoAdmin(
      idVehiculo: id,
      patente: patente,
      marca: marca as String?,
      modelo: modelo as String?,
      capacidad: capacidad,
      disponibilidad: disponibilidad,
    );
  }

  final int idVehiculo;
  final String patente;
  final String? marca;
  final String? modelo;
  final int capacidad;
  final bool disponibilidad;
}

final class VehiculoCreate {
  const VehiculoCreate({
    required this.patente,
    required this.marca,
    required this.modelo,
    required this.capacidad,
    required this.disponibilidad,
  });

  final String patente;
  final String? marca;
  final String? modelo;
  final int capacidad;
  final bool disponibilidad;

  Map<String, dynamic> toJson() => {
    'patente': patente,
    'marca': marca,
    'modelo': modelo,
    'capacidad': capacidad,
    'disponibilidad': disponibilidad,
  };
}

final class VehiculoUpdate {
  const VehiculoUpdate({
    required this.patente,
    required this.marca,
    required this.modelo,
    required this.capacidad,
    required this.disponibilidad,
  });

  final String patente;
  final String? marca;
  final String? modelo;
  final int capacidad;
  final bool disponibilidad;

  Map<String, dynamic> toJson() => {
    'patente': patente,
    'marca': marca,
    'modelo': modelo,
    'capacidad': capacidad,
    'disponibilidad': disponibilidad,
  };
}
