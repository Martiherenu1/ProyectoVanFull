import 'package:flutter/material.dart';

import 'core/navigation/role_router.dart';
import 'screens/admin/viajes_dia_admin_screen.dart';

void main() {
  runApp(const VanFullApp());
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
