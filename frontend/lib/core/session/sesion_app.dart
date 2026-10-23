import 'package:flutter/material.dart';

import '../../screens/comun/login_screen.dart';
import '../navigation/role_router.dart';
import '../theme/app_theme.dart';
import 'sesion_controller.dart';

/// Raíz de la app: sin sesión muestra el login; con sesión, la entrada del rol.
class SesionApp extends StatelessWidget {
  const SesionApp({super.key, required this.controller});

  final SesionController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final sesion = controller.sesion;
        if (sesion != null) return RoleRouter(roles: sesion.roles);
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
