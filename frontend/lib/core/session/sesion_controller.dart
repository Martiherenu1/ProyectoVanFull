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
  int _generacion = 0;

  Sesion? get sesion => _sesion;

  /// Cambia con cada ingreso, salida o invalidación. Quien monta pantallas con
  /// fuentes de datos de la sesión la usa como key para no mezclar una cuenta
  /// con la siguiente.
  int get generacion => _generacion;
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
      _generacion++;
    } on CredencialesInvalidas {
      _error = ErrorLogin.credenciales;
    } catch (_) {
      _error = ErrorLogin.red;
    } finally {
      _ingresando = false;
      notifyListeners();
    }
  }

  /// El servidor rechazó [token]. Solo cierra la sesión si ese token sigue
  /// siendo el vigente: un 401 tardío de una cuenta anterior no toca la actual.
  void invalidar(String token) {
    if (_sesion?.accessToken != token) return;
    _sesion = null;
    _generacion++;
    notifyListeners();
  }

  /// La salida local es inmediata y no depende de la red: el logout viaja con
  /// el token de la sesión saliente y su falla se ignora.
  Future<void> salir() async {
    final saliente = _sesion;
    _sesion = null;
    _error = null;
    _generacion++;
    notifyListeners();
    final cerrar = cerrarSesion;
    if (saliente == null || cerrar == null) return;
    try {
      await cerrar(saliente.accessToken);
    } catch (_) {}
  }
}
