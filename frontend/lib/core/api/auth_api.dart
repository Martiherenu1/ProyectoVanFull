import '../session/sesion.dart';
import 'api_client.dart';
import 'api_error.dart';

/// Adaptador de /auth sobre el cliente común.
class AuthApi {
  const AuthApi(this._cliente);

  final ApiClient _cliente;

  /// POST /auth/login. El 401 CREDENCIALES_INVALIDAS pasa a [CredencialesInvalidas];
  /// cualquier otra falla se lanza tal cual y la pantalla la muestra como red.
  Future<Sesion> iniciarSesion(String identificador, String password) async {
    try {
      final cuerpo = await _cliente.post(
        'auth/login',
        body: {'identificador_acceso': identificador, 'password': password},
      );
      return Sesion.fromJson(cuerpo! as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 401) throw const CredencialesInvalidas();
      rethrow;
    }
  }

  /// POST /auth/logout (204).
  Future<void> cerrarSesion() async {
    await _cliente.post('auth/logout');
  }
}
