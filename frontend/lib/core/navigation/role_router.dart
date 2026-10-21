import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'app_role.dart';

/// Decide la portada inicial sin reemplazar la futura integración con login.
class RoleRouter extends StatelessWidget {
  const RoleRouter({required this.roles, super.key});

  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    final resolution = _resolve(roles);

    return MaterialApp(
      title: 'VanFull',
      debugShowCheckedModeBanner: false,
      theme: resolution.role?.theme ?? AppTheme.admin,
      home: resolution.role == null
          ? _PendingRoleScreen(
              title: resolution.title,
              message: resolution.message,
            )
          : _RoleEntryScreen(role: resolution.role!),
    );
  }

  _RoleResolution _resolve(List<String> values) {
    if (values.isEmpty) {
      return const _RoleResolution.pending(
        title: 'Autenticación pendiente',
        message: 'La portada se habilitará cuando exista una sesión.',
      );
    }
    if (values.length > 1) {
      return const _RoleResolution.pending(
        title: 'Selección de rol pendiente',
        message: 'No se seleccionó ningún rol automáticamente.',
      );
    }

    final role = AppRole.fromApiValue(values.single);
    if (role == null) {
      return const _RoleResolution.pending(
        title: 'Rol no reconocido',
        message: 'No se habilitó ninguna sección.',
      );
    }
    return _RoleResolution.ready(role);
  }
}

class _RoleEntryScreen extends StatelessWidget {
  const _RoleEntryScreen({required this.role});

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('VanFull — ${role.label}')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              role.entryTitle,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('${role.useCase} · Entrada temporal'),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              key: ValueKey('role-touch-target-${role.apiValue}'),
              width: double.infinity,
              height: role.touchTargetHeight,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.fromHeight(role.touchTargetHeight),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Funcionalidad pendiente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingRoleScreen extends StatelessWidget {
  const _PendingRoleScreen({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VanFull')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _RoleResolution {
  const _RoleResolution.ready(this.role) : title = '', message = '';

  const _RoleResolution.pending({required this.title, required this.message})
    : role = null;

  final AppRole? role;
  final String title;
  final String message;
}

extension on AppRole {
  ThemeData get theme => switch (this) {
    AppRole.passenger => AppTheme.passenger,
    AppRole.driver => AppTheme.driver,
    AppRole.admin => AppTheme.admin,
  };

  String get label => switch (this) {
    AppRole.passenger => 'Pasajero',
    AppRole.driver => 'Chofer',
    AppRole.admin => 'Administración',
  };

  String get entryTitle => switch (this) {
    AppRole.passenger => 'Buscar servicio',
    AppRole.driver => 'Lista del viaje',
    AppRole.admin => 'Viajes del día',
  };

  String get useCase => switch (this) {
    AppRole.passenger => 'CU-002',
    AppRole.driver => 'CU-029',
    AppRole.admin => 'CU-018',
  };

  double get touchTargetHeight => switch (this) {
    AppRole.passenger => AppSpacing.passengerRowHeight,
    AppRole.driver => AppSpacing.driverRowHeight,
    AppRole.admin => AppSpacing.adminRowHeight,
  };
}
