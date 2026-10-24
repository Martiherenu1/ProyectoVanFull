import 'package:flutter/material.dart';

import '../../screens/admin/viajes_dia_admin_screen.dart';
import '../../screens/comun/login_screen.dart';
import '../navigation/app_role.dart';
import '../navigation/role_router.dart';
import '../theme/app_theme.dart';
import 'sesion_controller.dart';

/// Raíz de la app: sin sesión muestra el login; con sesión, la entrada del rol.
class SesionApp extends StatelessWidget {
  const SesionApp({
    super.key,
    required this.controller,
    this.entradaPasajero,
    this.fechaAdmin,
    this.cargarViajesAdmin,
    this.onViajeAdminSeleccionado,
  });

  final SesionController controller;

  /// Entrada real del pasajero. Mientras chofer y administración no tengan la
  /// suya, esos roles siguen en la portada temporal de [RoleRouter].
  final Widget Function(SesionController controller)? entradaPasajero;

  /// Dependencias de Viajes del día (administración), que [RoleRouter] recibe
  /// de quien arma la app. Sin ellas la pantalla muestra su estado de error.
  final DateTime? fechaAdmin;
  final CargarViajesDelDia? cargarViajesAdmin;
  final ValueChanged<int>? onViajeAdminSeleccionado;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final sesion = controller.sesion;
        final entrada = entradaPasajero;
        if (sesion != null) {
          if (entrada != null && _esPasajero(sesion.roles)) {
            return MaterialApp(
              title: 'VanFull',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.passenger,
              home: entrada(controller),
            );
          }
          return RoleRouter(
            roles: sesion.roles,
            fechaAdmin: fechaAdmin,
            cargarViajesAdmin: cargarViajesAdmin,
            onViajeAdminSeleccionado: onViajeAdminSeleccionado,
          );
        }
        return MaterialApp(
          title: 'VanFull',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.passenger,
          home: LoginScreen(controller: controller),
        );
      },
    );
  }

  bool _esPasajero(List<String> roles) =>
      roles.length == 1 &&
      AppRole.fromApiValue(roles.single) == AppRole.passenger;
}
