import 'accion_informar_ausencia.dart';

import 'package:flutter/material.dart';

import '../../core/api/pasajero_api.dart';
import '../../models/pasajero/deuda.dart';
import '../../models/pasajero/disponibilidad_viaje.dart';
import '../../models/pasajero/reserva.dart';
import 'asistente_screen.dart';
import 'buscar_servicio_screen.dart';
import 'confirmar_reserva_screen.dart';
import 'mis_reservas_screen.dart';
import 'pago_screen.dart';
import 'perfil_screen.dart';
import '../../services/checkout_api.dart';

/// Entrada del pasajero: une sus pantallas con la API y la navegación.
/// No decide reglas; solo lleva al pasajero de una pantalla a la siguiente.
class PasajeroShell extends StatefulWidget {
  const PasajeroShell({
    super.key,
    required this.api,
    required this.onSalir,
    this.pantallaUbicacion,
    this.checkout,
    this.abrirCheckout,
    this.contextoPagoVigente,
    this.informarAusencia,
    this.contextoAusenciaVigente,
  });

  final PasajeroApi api;
  final VoidCallback onSalir;
  final CheckoutApi? checkout;
  final AbrirCheckout? abrirCheckout;
  final bool Function()? contextoPagoVigente;
  final InformarAusencia? informarAusencia;
  final bool Function()? contextoAusenciaVigente;

  /// Arma la pantalla de ubicación de un viaje. La compone `main.dart`, que
  /// conoce la sesión y el mapa; sin ella Mis reservas no ofrece «Ver ubicación».
  final Widget Function(int idViaje)? pantallaUbicacion;

  @override
  State<PasajeroShell> createState() => _PasajeroShellState();
}

class _PasajeroShellState extends State<PasajeroShell> {
  static const _buscar = 0;
  static const _reservas = 1;

  int _pestana = _buscar;
  Object _alcanceAusencia = Object();
  int _rutasAbiertas = 0;

  void _invalidarAusencia() => _alcanceAusencia = Object();

  Future<T?> _abrirRuta<T>(Route<T> ruta) async {
    setState(() {
      _invalidarAusencia();
      _rutasAbiertas++;
    });
    try {
      return await Navigator.of(context).push(ruta);
    } finally {
      if (mounted) {
        setState(() {
          _rutasAbiertas--;
          _invalidarAusencia();
        });
      }
    }
  }

  /// Cambia al reservar o cancelar fuera de Mis reservas (el asistente puede
  /// hacerlo), para que la lista se recargue al volver a ella.
  int _versionReservas = 0;

  void _ir(int pestana) {
    setState(() {
      if (pestana != _pestana || pestana == _reservas) _invalidarAusencia();
      if (pestana == _reservas) _versionReservas++;
      _pestana = pestana;
    });
  }

  void _reservar(DisponibilidadViaje viaje) {
    _abrirRuta(
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

  void _verUbicacion(Reserva reserva) {
    final pantalla = widget.pantallaUbicacion!(reserva.idViaje);
    _abrirRuta(MaterialPageRoute<void>(builder: (_) => pantalla));
  }

  void _registrarPago(Deuda deuda) {
    var finalizo = false;
    _abrirRuta(
      MaterialPageRoute<void>(
        builder: (contexto) => PagoScreen(
          saldo: deuda.saldo,
          registrarPago: widget.api.registrarPago,
          iniciarCheckout: widget.checkout?.iniciar,
          consultarPago: widget.checkout?.consultar,
          abrirCheckout: widget.abrirCheckout,
          contextoVigente: widget.contextoPagoVigente,
          onTerminar: (_) {
            finalizo = true;
            Navigator.of(contexto).pop();
            _ir(_reservas);
          },
        ),
      ),
    ).then((_) {
      if (!finalizo &&
          widget.checkout != null &&
          mounted &&
          widget.contextoPagoVigente?.call() != false) {
        setState(() => _versionReservas++);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final alcance = _alcanceAusencia;
    bool ausenciaVigente() =>
        mounted &&
        identical(alcance, _alcanceAusencia) &&
        _pestana == _reservas &&
        _rutasAbiertas == 0 &&
        widget.contextoAusenciaVigente?.call() == true;
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
            versionReservas: _versionReservas,
            informarAusencia: widget.informarAusencia,
            alcanceAusencia: alcance,
            contextoAusenciaVigente: ausenciaVigente,
            cargarReservas: widget.api.cargarReservas,
            cargarDeuda: widget.api.cargarDeuda,
            cancelarReserva: widget.api.cancelarReserva,
            onBuscarServicio: () => _ir(_buscar),
            onRegistrarPago: _registrarPago,
            onVerUbicacion: widget.pantallaUbicacion == null
                ? null
                : _verUbicacion,
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
