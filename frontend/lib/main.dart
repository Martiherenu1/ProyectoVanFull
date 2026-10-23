import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'core/api/auth_api.dart';
import 'core/api/http_api_client.dart';
import 'core/api/pasajero_api.dart';
import 'core/navigation/role_router.dart';
import 'core/session/sesion_app.dart';
import 'core/session/sesion_controller.dart';
import 'screens/admin/viajes_dia_admin_screen.dart';
import 'screens/pasajero/pasajero_shell.dart';

/// URL base de la API, con el prefijo `/api`. En el emulador de Android el
/// host es `10.0.2.2`: `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api`.
const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000/api',
);

void main() {
  late final SesionController sesion;
  final cliente = HttpApiClient(
    baseUri: Uri.parse(_apiBaseUrl),
    transport: http.Client(),
    accessTokenProvider: () => sesion.token,
  );
  final auth = AuthApi(cliente);
  sesion = SesionController(
    iniciarSesion: auth.iniciarSesion,
    cerrarSesion: auth.cerrarSesion,
  );
  final pasajero = PasajeroApi(cliente);

  // Administración sigue sin fuente de datos: no existe `GET /viajes`, así que
  // Viajes del día muestra su estado de error en vez de datos simulados.
  runApp(
    SesionApp(
      controller: sesion,
      entradaPasajero: (controller) =>
          PasajeroShell(api: pasajero, onSalir: controller.salir),
    ),
  );
}

class VanFullApp extends StatelessWidget {
  const VanFullApp({
    this.roles = const [],
    this.fechaAdmin,
    this.cargarViajesAdmin,
    this.onViajeAdminSeleccionado,
    super.key,
  });

  final List<String> roles;
  final DateTime? fechaAdmin;
  final CargarViajesDelDia? cargarViajesAdmin;
  final ValueChanged<int>? onViajeAdminSeleccionado;

  @override
  Widget build(BuildContext context) {
    return RoleRouter(
      roles: roles,
      fechaAdmin: fechaAdmin,
      cargarViajesAdmin: cargarViajesAdmin,
      onViajeAdminSeleccionado: onViajeAdminSeleccionado,
    );
  }
}
