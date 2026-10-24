import 'package:flutter/material.dart';

import '../../core/api/pasajero_api.dart';
import '../../models/pasajero/disponibilidad_viaje.dart';
import 'asistente_screen.dart';
import 'buscar_servicio_screen.dart';
import 'confirmar_reserva_screen.dart';
import 'mis_reservas_screen.dart';
import 'perfil_screen.dart';

/// Entrada del pasajero: une las cuatro pantallas con la API y la navegación.
/// No decide reglas; solo lleva al pasajero de una pantalla a la siguiente.
class PasajeroShell extends StatefulWidget {
  const PasajeroShell({super.key, required this.api, required this.onSalir});

  final PasajeroApi api;
  final VoidCallback onSalir;

  @override
  State<PasajeroShell> createState() => _PasajeroShellState();
}

class _PasajeroShellState extends State<PasajeroShell> {
  static const _buscar = 0;
  static const _reservas = 1;

  int _pestana = _buscar;

  /// Cambia al reservar o cancelar fuera de Mis reservas (el asistente puede
  /// hacerlo), para que la lista se recargue al volver a ella.
  int _versionReservas = 0;

  void _ir(int pestana) {
    setState(() {
      if (pestana == _reservas) _versionReservas++;
      _pestana = pestana;
    });
  }

  void _reservar(DisponibilidadViaje viaje) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (contexto) => ConfirmarReservaScreen(
          viaje: viaje,
          cargarParadas: widget.api.cargarParadas,
          crearReserva: widget.api.crearReserva,
          onTerminar: (_) {
            Navigator.of(contexto).pop();
            _ir(_reservas);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _pestana,
        children: [
          BuscarServicioScreen(
            cargarDisponibilidad: widget.api.cargarDisponibilidad,
            cargarParadas: widget.api.cargarParadas,
            onReservar: _reservar,
          ),
          MisReservasScreen(
            key: ValueKey(_versionReservas),
            cargarReservas: widget.api.cargarReservas,
            cargarDeuda: widget.api.cargarDeuda,
            cancelarReserva: widget.api.cancelarReserva,
            onBuscarServicio: () => _ir(_buscar),
          ),
          AsistenteScreen(enviarMensaje: widget.api.enviarMensaje),
          PerfilScreen(
            cargarPerfil: widget.api.cargarPerfil,
            modificarPerfil: widget.api.modificarPerfil,
            onSalir: widget.onSalir,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestana,
        onDestinationSelected: _ir,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            label: 'Mis reservas',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Asistente',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }
}
