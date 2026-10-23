import 'package:flutter/foundation.dart';

/// El identificador o la contraseña no son correctos (401 CREDENCIALES_INVALIDAS).
/// El adaptador común debe lanzarla; cualquier otro error se muestra como fallo de red.
class CredencialesInvalidas implements Exception {
  const CredencialesInvalidas();
}

/// Respuesta de POST /auth/login (`TokenResponse`).
@immutable
class Sesion {
  const Sesion({required this.accessToken, required this.roles});

  factory Sesion.fromJson(Map<String, dynamic> json) => Sesion(
    accessToken: json['access_token'] as String,
    roles: List.unmodifiable((json['roles'] as List).cast<String>()),
  );

  final String accessToken;
  final List<String> roles;
}

/// POST /auth/login. Lanza [CredencialesInvalidas] ante el 401.
typedef IniciarSesion = Future<Sesion> Function(
  String identificador,
  String password,
);

/// POST /auth/logout. El backend no tiene lista negra: alcanza con descartar el token.
typedef CerrarSesion = Future<void> Function();
