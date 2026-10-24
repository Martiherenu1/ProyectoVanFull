import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'detalle_viaje_chofer_screen.dart';
import 'viajes_chofer_screen.dart';

/// Navegación de consulta CU-029; las fuentes y la sesión son externas.
///
/// El contenedor conserva las mismas fuentes entre reconstrucciones y reemplaza
/// la key (o desmonta este widget) al cambiar de sesión. Debe resolver 401/403
/// antes de propagar el error a las pantallas; aquí no hay política de acceso.
/// [onSalir] solo delega la salida: no borra tokens ni cierra transportes.
class ChoferShell extends StatefulWidget {
  const ChoferShell({
    required this.cargarViajes,
    required this.cargarDetalle,
    required this.onSalir,
    this.fechaInicial,
    super.key,
  });

  final CargarViajesChofer cargarViajes;
  final CargarDetalleViajeChofer cargarDetalle;
  final VoidCallback onSalir;
  final DateTime? fechaInicial;

  @override
  State<ChoferShell> createState() => _ChoferShellState();
}

class _ChoferShellState extends State<ChoferShell> {
  final _navigator = GlobalKey<NavigatorState>();
  final _fuentes = ValueNotifier(0);
  bool _detalleAbierto = false;

  @override
  void didUpdateWidget(covariant ChoferShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cargarViajes != widget.cargarViajes ||
        oldWidget.cargarDetalle != widget.cargarDetalle) {
      _fuentes.value++;
    }
  }

  @override
  void dispose() {
    _fuentes.dispose();
    super.dispose();
  }

  Future<void> _abrirDetalle(int idViaje) async {
    if (_detalleAbierto) return;
    _detalleAbierto = true;
    await _navigator.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) => ListenableBuilder(
          listenable: _fuentes,
          builder: (_, _) => DetalleViajeChoferScreen(
            idViaje: idViaje,
            cargarDetalle: widget.cargarDetalle,
          ),
        ),
      ),
    );
    _detalleAbierto = false;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: NavigatorPopHandler<Object?>(
      onPopWithResult: (_) => _navigator.currentState!.pop(),
      child: Navigator(
        key: _navigator,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => ListenableBuilder(
            listenable: _fuentes,
            builder: (_, _) => ViajesChoferScreen(
              cargarViajes: widget.cargarViajes,
              fechaInicial: widget.fechaInicial,
              onViajeSeleccionado: _abrirDetalle,
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(AppSpacing.md),
      child: OutlinedButton.icon(
        onPressed: widget.onSalir,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.driverTouchTarget),
        ),
        icon: const Icon(Icons.logout),
        label: const Text('Cerrar sesión'),
      ),
    ),
  );
}
