import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/format/fecha_legible.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/pasajero/reserva.dart';
import '../../services/admin/consulta_reservas_admin.dart';

/// Preparación de CU-027/RF-043: sin conexión HTTP ni acciones de escritura.
class ConsultarReservasAdminScreen extends StatefulWidget {
  const ConsultarReservasAdminScreen({
    super.key,
    required this.consulta,
    required this.alcance,
  });
  final ConsultaReservasAdmin consulta;

  /// Identidad opaca de la sesión/vista suministrada por el futuro integrador.
  /// Nunca usar el token como identidad visible ni reutilizarla entre cuentas.
  final Object alcance;
  @override
  State<ConsultarReservasAdminScreen> createState() =>
      _ConsultarReservasAdminScreenState();
}

class _ConsultarReservasAdminScreenState
    extends State<ConsultarReservasAdminScreen> {
  List<Reserva> _reservas = const [];
  Reserva? _seleccionada;
  bool _cargando = true;
  String? _error;
  int _solicitud = 0;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant ConsultarReservasAdminScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.consulta, widget.consulta) ||
        !identical(oldWidget.alcance, widget.alcance)) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    final solicitud = ++_solicitud;
    setState(() {
      _reservas = const [];
      _seleccionada = null;
      _cargando = true;
      _error = null;
    });
    try {
      final reservas = await widget.consulta.listar();
      if (!mounted || solicitud != _solicitud) return;
      setState(() {
        _reservas = List.unmodifiable(reservas);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted || solicitud != _solicitud) return;
      setState(() {
        _cargando = false;
        _error = e is ApiException
            ? e.mensaje
            : 'No pudimos consultar las reservas. Volvé a intentar.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.admin,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          _seleccionada == null
              ? 'Consultar reservas'
              : 'Reserva ${_seleccionada!.idReserva}',
        ),
        leading: _seleccionada == null
            ? null
            : BackButton(onPressed: () => setState(() => _seleccionada = null)),
        actions: [
          IconButton(
            tooltip: 'Actualizar reservas',
            onPressed: _cargando ? null : _cargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: _contenido()),
    ),
  );
  Widget _contenido() {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Consultando reservas',
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, key: const Key('error-consulta-reservas')),
              TextButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    final reserva = _seleccionada;
    if (reserva != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          key: ValueKey('detalle-reserva-${reserva.idReserva}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reserva: ${reserva.idReserva}'),
            Text('Viaje: ${reserva.idViaje}'),
            Text('Recorrido: ${reserva.idRecorrido}'),
            Text('Orden de parada de ascenso: ${reserva.ordenParada}'),
            Text('Fecha: ${fechaLegible(reserva.fecha)}'),
            Text('Horario: ${reserva.horario ?? 'Sin horario'}'),
            Text('Sentido: ${reserva.sentido.etiqueta}'),
            Text(
              'Estado: ${reserva.estado.etiqueta} (${reserva.estado.valorApi})',
            ),
          ],
        ),
      );
    }
    if (_reservas.isEmpty) {
      return const Center(child: Text('No hay reservas para mostrar.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _reservas.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final reserva = _reservas[index];
        return ListTile(
          key: ValueKey('reserva-${reserva.idReserva}'),
          title: Text(
            'Reserva ${reserva.idReserva} · Viaje ${reserva.idViaje}',
          ),
          subtitle: Text(
            '${fechaLegible(reserva.fecha)} · ${reserva.horario ?? 'Sin horario'} · ${reserva.estado.etiqueta} (${reserva.estado.valorApi})',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => setState(() => _seleccionada = reserva),
        );
      },
    );
  }
}
