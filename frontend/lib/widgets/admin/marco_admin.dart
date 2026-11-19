import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

enum DestinoAdmin {
  viajes('Viajes'),
  historial('Historial'),
  reservas('Reservas'),
  recorridos('Recorridos'),
  vehiculos('Vehículos'),
  choferes('Choferes'),
  abonos('Abonos'),
  tarifas('Tarifas'),
  registrarPago('Registrar pago'),
  pagosPendientes('Pagos pendientes'),
  deuda('Deuda'),
  administradores('Administradores');

  const DestinoAdmin(this.etiqueta);

  final String etiqueta;

  Key get clave => Key(switch (this) {
    DestinoAdmin.viajes => 'admin-viajes',
    DestinoAdmin.historial => 'admin-historial-viajes',
    DestinoAdmin.reservas => 'admin-consultar-reservas',
    DestinoAdmin.deuda => 'admin-consultar-deuda',
    DestinoAdmin.registrarPago => 'admin-registrar-pago',
    DestinoAdmin.pagosPendientes => 'admin-pagos-pendientes',
    _ => 'admin-$name',
  });
}

/// Recibe exclusivamente las acciones que la composición habilita.
class MarcoAdmin extends StatelessWidget {
  const MarcoAdmin({
    required this.activo,
    required this.acciones,
    required this.onSalir,
    required this.child,
    super.key,
  });

  final DestinoAdmin activo;
  final Map<DestinoAdmin, VoidCallback> acciones;
  final VoidCallback onSalir;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final escritorio = constraints.maxWidth >= 1024;
      if (escritorio) {
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                SizedBox(width: 216, child: _menu(context, modal: false)),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
          ),
        );
      }

      return Scaffold(
        appBar: AppBar(title: const _MarcaAdmin()),
        drawer: Drawer(
          child: SafeArea(
            child: Builder(builder: (context) => _menu(context, modal: true)),
          ),
        ),
        body: child,
      );
    },
  );

  Widget _menu(BuildContext context, {required bool modal}) {
    void ejecutar(VoidCallback accion) {
      if (modal) Scaffold.of(context).closeDrawer();
      accion();
    }

    const grupos = {
      'Operación': [
        DestinoAdmin.viajes,
        DestinoAdmin.historial,
        DestinoAdmin.reservas,
      ],
      'Catálogos': [
        DestinoAdmin.recorridos,
        DestinoAdmin.vehiculos,
        DestinoAdmin.choferes,
        DestinoAdmin.administradores,
      ],
      'Cobros': [
        DestinoAdmin.abonos,
        DestinoAdmin.tarifas,
        DestinoAdmin.registrarPago,
        DestinoAdmin.pagosPendientes,
        DestinoAdmin.deuda,
      ],
    };

    return Material(
      color: AppColors.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Align(alignment: Alignment.centerLeft, child: _MarcaAdmin()),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final grupo in grupos.entries)
                    if (grupo.value.any(acciones.containsKey)) ...[
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Text(grupo.key, style: AppTypography.micro),
                      ),
                      for (final destino in grupo.value)
                        if (acciones[destino] case final accion?)
                          ListTile(
                            key: destino.clave,
                            selected: destino == activo,
                            selectedColor: AppColors.ink900,
                            selectedTileColor: AppColors.ink100,
                            title: Text(destino.etiqueta),
                            onTap: () => ejecutar(accion),
                          ),
                    ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            key: const Key('admin-salir'),
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () => ejecutar(onSalir),
          ),
        ],
      ),
    );
  }
}

class _MarcaAdmin extends StatelessWidget {
  const _MarcaAdmin();

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/marca/vanfull-logo.png',
    width: 100,
    height: 36,
    fit: BoxFit.contain,
    semanticLabel: 'VanFull',
  );
}
