import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chofer/operacion_asignada.dart';

/// null indica detalle no disponible. El adaptador común traducirá el 404;
/// los demás fallos se comunican mediante un Future fallido, sin exponer su texto.
/// No distingue viaje ajeno de inexistente ni reemplaza permisos del backend.
typedef CargarDetalleViajeChofer = Future<OperacionAsignada?> Function(
  int idViaje,
);

class DetalleViajeChoferScreen extends StatefulWidget {
  const DetalleViajeChoferScreen({
    required this.idViaje,
    required this.cargarDetalle,
    super.key,
  });

  final int idViaje;
  final CargarDetalleViajeChofer cargarDetalle;

  @override
  State<DetalleViajeChoferScreen> createState() =>
      _DetalleViajeChoferScreenState();
}

class _DetalleViajeChoferScreenState extends State<DetalleViajeChoferScreen> {
  OperacionAsignada? _detalle;
  bool _cargando = true;
  bool _error = false;
  int _solicitud = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant DetalleViajeChoferScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idViaje != widget.idViaje ||
        oldWidget.cargarDetalle != widget.cargarDetalle) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    final solicitud = ++_solicitud;
    final idViaje = widget.idViaje;
    setState(() {
      _cargando = true;
      _error = false;
      _detalle = null;
    });
    try {
      final detalle = await widget.cargarDetalle(idViaje);
      if (!mounted || solicitud != _solicitud) return;
      // Una fuente mal conectada no debe mostrar información de otro viaje.
      if (detalle != null && detalle.viaje.idViaje != idViaje) {
        throw const FormatException('Detalle de otro viaje');
      }
      setState(() {
        _detalle = detalle;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted || solicitud != _solicitud) return;
      setState(() {
        _error = true;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.driver,
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Detalle del viaje')),
        body: SafeArea(child: _contenido(context)),
      ),
    ),
  );

  Widget _contenido(BuildContext context) {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Cargando detalle del viaje',
        ),
      );
    }
    if (_error || _detalle == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error
                    ? 'No pudimos cargar el detalle.'
                    : 'Detalle no disponible.',
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _cargar,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.driverTouchTarget),
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    final detalle = _detalle!;
    final viaje = detalle.viaje;
    final fecha =
        '${viaje.fecha.day.toString().padLeft(2, '0')}/'
        '${viaje.fecha.month.toString().padLeft(2, '0')}/${viaje.fecha.year}';
    final c = detalle.cantidades;
    return ListView(
      key: ValueKey('detalle-${viaje.idViaje}'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _titulo(context, 'Viaje ${viaje.idViaje}'),
        _fila('Fecha: $fecha · ${viaje.horario ?? 'Sin horario'}'),
        _fila('${viaje.sentido.etiqueta} · ${viaje.estado.etiqueta}'),
        _fila(
          'Servicio ID ${viaje.idServicio} · Recorrido ID ${viaje.idRecorrido}',
        ),
        _fila(
          'Vehículo: ${viaje.idVehiculo == null ? 'Sin asignar' : 'ID ${viaje.idVehiculo}'} · '
          'Chofer: ${viaje.idChofer == null ? 'Sin asignar' : 'ID ${viaje.idChofer}'}',
        ),
        _fila(
          'Capacidad planificada: ${detalle.capacidadPlanificada?.toString() ?? 'Sin informar'}',
        ),
        _titulo(context, 'Cantidades independientes'),
        _fila('Reservas consolidadas: ${c.consolidadas}'),
        _fila('Reservas provisionales: ${c.provisionales}'),
        _fila('Total de reservas: ${c.totalReservas}'),
        _fila('Integrantes de nómina: ${c.totalNomina}'),
        _fila('Abordajes registrados en reservas: ${c.abordajesRegistrados}'),
        _titulo(context, 'Paradas del recorrido'),
        if (detalle.paradas.isEmpty) _fila('No hay paradas informadas.'),
        // Se conserva el orden recibido, sin invertirlo por el sentido del viaje.
        for (final parada in detalle.paradas)
          _fila(
            'Parada ${parada.orden}: ${parada.nombreDescripcion ?? 'Sin descripción'}',
            key: ValueKey('parada-${parada.idParada}'),
          ),
        _titulo(context, 'Pasajeros con reserva'),
        if (detalle.pasajerosConReserva.isEmpty)
          _fila('No hay pasajeros con reserva informados.'),
        for (final pasajero in detalle.pasajerosConReserva)
          _filaPasajero(pasajero),
        _titulo(context, 'Nómina independiente'),
        if (detalle.integrantesNomina.isEmpty)
          _fila('No hay integrantes de nómina informados.'),
        for (final integrante in detalle.integrantesNomina)
          _fila(
            '${integrante.nombre} ${integrante.apellido}\nDNI: ${integrante.dni}',
            key: ValueKey('integrante-${integrante.idIntegranteNomina}'),
          ),
      ],
    );
  }

  Widget _titulo(BuildContext context, String texto) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: Text(texto, style: Theme.of(context).textTheme.headlineSmall),
  );

  Widget _fila(String texto, {Key? key}) => ConstrainedBox(
    key: key,
    constraints: const BoxConstraints(minHeight: AppSpacing.driverRowHeight),
    child: Align(alignment: Alignment.centerLeft, child: Text(texto)),
  );

  Widget _filaPasajero(PasajeroOperacion p) => ConstrainedBox(
    key: ValueKey('reserva-${p.idReserva}'),
    constraints: const BoxConstraints(minHeight: AppSpacing.driverRowHeight),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // fotografia es una referencia, no una URL contratada. No se descarga
          // contenido ni se inventa una imagen; su resolución queda al adaptador.
          Semantics(
            container: true,
            image: true,
            label: p.fotografia == null
                ? 'Sin fotografía'
                : 'Fotografía referenciada, sin visualización',
            child: const Icon(
              Icons.person_outline,
              size: AppSpacing.driverTouchTarget,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.nombre} ${p.apellido}'),
                Text('DNI: ${p.dni}'),
                Text(
                  'Reserva ${p.idReserva} · ${p.estado.etiqueta} · Parada reservada ${p.ordenParada}',
                ),
                Text(
                  p.abordajeRegistrado
                      ? 'Abordaje registrado'
                      : 'Sin abordaje registrado',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
