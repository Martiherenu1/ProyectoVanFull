/// Cuenta de administrador que gestiona el dueño (CU-032).
final class Administrador {
  const Administrador({
    required this.idCuentaAcceso,
    required this.idPersona,
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.identificadorAcceso,
    required this.estado,
    this.email,
    this.telefono,
  });

  factory Administrador.fromJson(Map<String, dynamic> json) => Administrador(
    idCuentaAcceso: json['id_cuenta_acceso'] as int,
    idPersona: json['id_persona'] as int,
    nombre: json['nombre'] as String,
    apellido: json['apellido'] as String,
    dni: json['dni'] as String,
    email: json['email'] as String?,
    telefono: json['telefono'] as String?,
    identificadorAcceso: json['identificador_acceso'] as String,
    estado: json['estado'] as String,
  );

  static const estadoActivo = 'activo';

  final int idCuentaAcceso;
  final int idPersona;
  final String nombre;
  final String apellido;
  final String dni;
  final String? email;
  final String? telefono;
  final String identificadorAcceso;
  final String estado;

  bool get activo => estado == estadoActivo;
  String get nombreCompleto => '$apellido, $nombre';
}

/// Datos del alta. Los opcionales vacíos no se envían.
final class AdministradorCreate {
  const AdministradorCreate({
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.identificadorAcceso,
    required this.contrasena,
    this.email,
    this.telefono,
  });

  final String nombre;
  final String apellido;
  final String dni;
  final String identificadorAcceso;
  final String contrasena;
  final String? email;
  final String? telefono;

  Map<String, Object?> toJson() => {
    'nombre': nombre,
    'apellido': apellido,
    'dni': dni,
    'identificador_acceso': identificadorAcceso,
    'contrasena': contrasena,
    if (email != null && email!.isNotEmpty) 'email': email,
    if (telefono != null && telefono!.isNotEmpty) 'telefono': telefono,
  };
}
