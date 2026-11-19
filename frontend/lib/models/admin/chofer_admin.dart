final class ChoferAdmin {
  const ChoferAdmin({
    required this.idPersona,
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.direccion,
    required this.telefono,
    required this.email,
    required this.cuil,
    required this.registroConducir,
    required this.fechaVencimientoRegistro,
  });

  factory ChoferAdmin.fromJson(Map<String, dynamic> json) {
    final id = json['id_persona'];
    final nombre = json['nombre'];
    final apellido = json['apellido'];
    final dni = json['dni'];
    final direccion = json['direccion'];
    final telefono = json['telefono'];
    final email = json['email'];
    final cuil = json['cuil'];
    final registro = json['registro_conducir'];
    final fechaRaw = json['fecha_vencimiento_registro'];
    if (id is! int ||
        nombre is! String ||
        apellido is! String ||
        dni is! String ||
        (direccion != null && direccion is! String) ||
        (telefono != null && telefono is! String) ||
        (email != null && email is! String) ||
        (cuil != null && cuil is! String) ||
        (registro != null && registro is! String) ||
        (fechaRaw != null && fechaRaw is! String)) {
      throw const FormatException('Chofer inválido.');
    }
    final fecha = fechaRaw == null ? null : DateTime.tryParse(fechaRaw);
    if (fechaRaw != null &&
        (fecha == null || _fechaIso(fecha) != fechaRaw)) {
      throw const FormatException('Fecha de registro inválida.');
    }
    return ChoferAdmin(
      idPersona: id,
      nombre: nombre,
      apellido: apellido,
      dni: dni,
      direccion: direccion as String?,
      telefono: telefono as String?,
      email: email as String?,
      cuil: cuil as String?,
      registroConducir: registro as String?,
      fechaVencimientoRegistro: fecha,
    );
  }

  final int idPersona;
  final String nombre;
  final String apellido;
  final String dni;
  final String? direccion;
  final String? telefono;
  final String? email;
  final String? cuil;
  final String? registroConducir;
  final DateTime? fechaVencimientoRegistro;
}

final class ChoferAdminCreate {
  const ChoferAdminCreate({
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.direccion,
    required this.telefono,
    required this.email,
    required this.cuil,
    required this.registroConducir,
    required this.fechaVencimientoRegistro,
  });

  final String nombre;
  final String apellido;
  final String dni;
  final String? direccion;
  final String? telefono;
  final String? email;
  final String? cuil;
  final String? registroConducir;
  final DateTime? fechaVencimientoRegistro;

  Map<String, dynamic> toJson() => _aJson(
    nombre: nombre,
    apellido: apellido,
    dni: dni,
    direccion: direccion,
    telefono: telefono,
    email: email,
    cuil: cuil,
    registroConducir: registroConducir,
    fechaVencimientoRegistro: fechaVencimientoRegistro,
  );
}

final class ChoferAdminUpdate {
  const ChoferAdminUpdate({
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.direccion,
    required this.telefono,
    required this.email,
    required this.cuil,
    required this.registroConducir,
    required this.fechaVencimientoRegistro,
  });

  final String nombre;
  final String apellido;
  final String dni;
  final String? direccion;
  final String? telefono;
  final String? email;
  final String? cuil;
  final String? registroConducir;
  final DateTime? fechaVencimientoRegistro;

  Map<String, dynamic> toJson() => _aJson(
    nombre: nombre,
    apellido: apellido,
    dni: dni,
    direccion: direccion,
    telefono: telefono,
    email: email,
    cuil: cuil,
    registroConducir: registroConducir,
    fechaVencimientoRegistro: fechaVencimientoRegistro,
  );
}

Map<String, dynamic> _aJson({
  required String nombre,
  required String apellido,
  required String dni,
  required String? direccion,
  required String? telefono,
  required String? email,
  required String? cuil,
  required String? registroConducir,
  required DateTime? fechaVencimientoRegistro,
}) => {
  'nombre': nombre,
  'apellido': apellido,
  'dni': dni,
  'direccion': direccion,
  'telefono': telefono,
  'email': email,
  'cuil': cuil,
  'registro_conducir': registroConducir,
  'fecha_vencimiento_registro': fechaVencimientoRegistro == null
      ? null
      : _fechaIso(fechaVencimientoRegistro),
};

String _fechaIso(DateTime fecha) =>
    '${fecha.year.toString().padLeft(4, '0')}-'
    '${fecha.month.toString().padLeft(2, '0')}-'
    '${fecha.day.toString().padLeft(2, '0')}';
