/// Lectura de PerfilPasajero (CU-001). Nombre, apellido y DNI no se editan por
/// autoservicio (RN-026); correo, teléfono y dirección sí.
class Perfil {
  const Perfil({
    required this.nombre,
    required this.apellido,
    required this.dni,
    this.email,
    this.telefono,
    this.direccion,
  });

  factory Perfil.fromJson(Map<String, dynamic> json) => Perfil(
    nombre: json['nombre'] as String,
    apellido: json['apellido'] as String,
    dni: json['dni'] as String,
    email: json['email'] as String?,
    telefono: json['telefono'] as String?,
    direccion: json['direccion'] as String?,
  );

  final String nombre;
  final String apellido;
  final String dni;
  final String? email;
  final String? telefono;
  final String? direccion;
}
