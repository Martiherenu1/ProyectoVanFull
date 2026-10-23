import 'package:flutter/foundation.dart';

import 'sesion.dart';

enum ErrorLogin { credenciales, red }

/// Guarda la sesión solo en memoria: al cerrar la app hay que volver a entrar.
class SesionController extends ChangeNotifier {
  SesionController({required this.iniciarSesion, this.cerrarSesion});

  final IniciarSesion iniciarSesion;
  final CerrarSesion? cerrarSesion;

  Sesion? _sesion;
  bool _ingresando = false;
  ErrorLogin? _error;

  Sesion? get sesion => _sesion;
  bool get ingresando => _ingresando;
  ErrorLogin? get error => _error;

  /// Para el `AccessTokenProvider` del cliente HTTP.
  String? get token => _sesion?.accessToken;

  Future<void> ingresar(String identificador, String password) async {
    if (_ingresando) return;
    _ingresando = true;
    _error = null;
    notifyListeners();
    try {
      _sesion = await iniciarSesion(identificador.trim(), password);
    } on CredencialesInvalidas {
      _error = ErrorLogin.credenciales;
    } catch (_) {
      _error = ErrorLogin.red;
    } finally {
      _ingresando = false;
      notifyListeners();
    }
  }

  /// El token se descarta aunque el servidor no responda.
  Future<void> salir() async {
    final cerrar = cerrarSesion;
    _sesion = null;
    _error = null;
    notifyListeners();
    if (cerrar == null) return;
    try {
      await cerrar();
    } catch (_) {}
  }
}
