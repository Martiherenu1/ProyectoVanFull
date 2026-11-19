/// Modalidades de abono que acepta el contrato.
const modalidadesAbono = {
  'IDA': 'Solo ida',
  'VUELTA': 'Solo vuelta',
  'IDA_VUELTA': 'Ida y vuelta',
};

/// `YYYY-MM` con mes entre 01 y 12, como lo exige la API.
final _formatoPeriodo = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

bool periodoValido(String valor) => _formatoPeriodo.hasMatch(valor);

final class PeriodoAbono {
  const PeriodoAbono({
    required this.idPeriodoAbono,
    required this.periodo,
    required this.estado,
  });

  factory PeriodoAbono.fromJson(Map<String, dynamic> json) => PeriodoAbono(
    idPeriodoAbono: json['id_periodo_abono'] as int,
    periodo: json['periodo'] as String,
    estado: json['estado'] as String,
  );

  final int idPeriodoAbono;
  final String periodo;
  final String estado;
}

/// Abono mensual tal como lo gestiona administración (CU-028).
final class AbonoGestion {
  const AbonoGestion({
    required this.idAbonoMensual,
    required this.idPasajero,
    required this.nombre,
    required this.apellido,
    required this.idServicio,
    required this.tipoServicio,
    required this.estado,
    required this.periodos,
    this.modalidad,
    this.diasSemanales,
    this.importeAcordado,
  });

  factory AbonoGestion.fromJson(Map<String, dynamic> json) => AbonoGestion(
    idAbonoMensual: json['id_abono_mensual'] as int,
    idPasajero: json['id_pasajero'] as int,
    nombre: json['nombre'] as String,
    apellido: json['apellido'] as String,
    idServicio: json['id_servicio'] as int,
    tipoServicio: json['tipo_servicio'] as String,
    modalidad: json['modalidad'] as String?,
    diasSemanales: json['dias_semanales'] as String?,
    importeAcordado: (json['importe_acordado'] as num?)?.toDouble(),
    estado: json['estado'] as String,
    periodos: (json['periodos'] as List)
        .map((e) => PeriodoAbono.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
  );

  final int idAbonoMensual;
  final int idPasajero;
  final String nombre;
  final String apellido;
  final int idServicio;
  final String tipoServicio;
  final String? modalidad;
  final String? diasSemanales;
  final double? importeAcordado;
  final String estado;
  final List<PeriodoAbono> periodos;

  String get pasajero => '$nombre $apellido';
}

/// Servicio al que se puede contratar un abono.
final class ServicioAbono {
  const ServicioAbono({required this.idServicio, required this.tipo});

  factory ServicioAbono.fromJson(Map<String, dynamic> json) => ServicioAbono(
    idServicio: json['id_servicio'] as int,
    tipo: json['tipo_servicio'] as String,
  );

  final int idServicio;
  final String tipo;

  /// Solo hay abono para servicios universitarios y laborales.
  bool get admiteAbono => tipo == 'UNIVERSITARIO' || tipo == 'LABORAL';
}

final class AbonoGestionCreate {
  const AbonoGestionCreate({
    required this.idPasajero,
    required this.idServicio,
    required this.modalidad,
    required this.diasSemanales,
    this.importeAcordado,
    this.periodo,
  });

  final int idPasajero;
  final int idServicio;
  final String modalidad;
  final String diasSemanales;
  final double? importeAcordado;
  final String? periodo;

  Map<String, Object?> toJson() => {
    'id_pasajero': idPasajero,
    'id_servicio': idServicio,
    'modalidad': modalidad,
    'dias_semanales': diasSemanales,
    'importe_acordado': ?importeAcordado,
    'periodo': ?periodo,
  };
}
