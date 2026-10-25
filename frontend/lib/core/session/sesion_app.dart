import 'package:flutter/material.dart';

import '../../screens/admin/viajes_dia_admin_screen.dart';
import '../../screens/comun/login_screen.dart';
import '../navigation/role_router.dart';
import '../theme/app_theme.dart';
import 'sesion_controller.dart';

/// Raíz de la app: sin sesión muestra el login; con sesión, la entrada del rol.
class SesionApp extends StatelessWidget {
  const SesionApp({
    super.key,
    required this.controller,
    this.entradaPasajero,
    this.entradaChofer,
    this.entradaAdministrador,
    this.fechaAdmin,
    this.cargarViajesAdmin,
    this.onViajeAdminSeleccionado,
  });

  final SesionController controller;

  /// Entradas reales aportadas por la composición, sin trasladar sesión ni
  /// transporte a las pantallas de cada rol.
  final Widget Function(SesionController controller)? entradaPasajero;
  final Widget Function(SesionController controller)? entradaChofer;
  final Widget Function(SesionController controller)? entradaAdministrador;

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
        if (sesion != null) {
          return KeyedSubtree(
            key: ValueKey(controller.generacion),
            child: RoleRouter(
              roles: sesion.roles,
              entradaPasajero: entradaPasajero == null
                  ? null
                  : (_) => entradaPasajero!(controller),
              entradaChofer: entradaChofer == null
                  ? null
                  : (_) => entradaChofer!(controller),
              entradaAdministrador: entradaAdministrador == null
                  ? null
                  : (_) => entradaAdministrador!(controller),
              fechaAdmin: fechaAdmin,
              cargarViajesAdmin: cargarViajesAdmin,
              onViajeAdminSeleccionado: onViajeAdminSeleccionado,
            ),
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
}
