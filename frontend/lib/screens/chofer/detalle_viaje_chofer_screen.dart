import 'package:flutter/material.dart';

import '../../controllers/chofer/ejecucion_viaje_controller.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chofer/operacion_asignada.dart';

import 'acciones_viaje_chofer.dart';

// Conserva la interfaz de carga publicada por CU-029.
export '../../controllers/chofer/ejecucion_viaje_controller.dart'
    show CargarDetalleViajeChofer;

class DetalleViajeChoferScreen extends StatefulWidget {
  const DetalleViajeChoferScreen({
    required this.idViaje,
    required this.cargarDetalle,
    this.acciones,
    this.comprobarUbicacionInicio,
    this.controlador,
    super.key,
  });

  final int idViaje;
  final CargarDetalleViajeChofer cargarDetalle;
  final AccionesEjecucionViaje? acciones;
  final ComprobarUbicacionInicio? comprobarUbicacionInicio;

  /// Prestado: su propietario inicia consultas, actualiza fuentes y lo dispone.
  /// Debe corresponder a idViaje. Sin él, el detalle conserva la propiedad local.
  final EjecucionViajeController? controlador;

  @override
  State<DetalleViajeChoferScreen> createState() =>
      _DetalleViajeChoferScreenState();
}

class _DetalleViajeChoferScreenState extends State<DetalleViajeChoferScreen> {
  late EjecucionViajeController _controlador;
  late bool _propio;

  @override
  void initState() {
    super.initState();
    _vincular();
  }

  void _vincular() {
    _propio = widget.controlador == null;
    _controlador =
        widget.controlador ??
        EjecucionViajeController(
          idViaje: widget.idViaje,
          cargarDetalle: widget.cargarDetalle,
          acciones: widget.acciones,
          comprobarUbicacionInicio: widget.comprobarUbicacionInicio,
        );
    _controlador.addListener(_actualizar);
    if (_propio) _controlador.consultar();
  }

  void _desvincular() {
    _controlador.removeListener(_actualizar);
    if (_propio) _controlador.dispose();
  }

  void _actualizar() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant DetalleViajeChoferScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controlador != widget.controlador) {
      _desvincular();
      _vincular();
      return;
    }
    if (!_propio) return;
    if (oldWidget.idViaje != widget.idViaje ||
        oldWidget.cargarDetalle != widget.cargarDetalle ||
        oldWidget.acciones != widget.acciones ||
        oldWidget.comprobarUbicacionInicio != widget.comprobarUbicacionInicio) {
      _controlador.actualizarContexto(
        idViaje: widget.idViaje,
        cargarDetalle: widget.cargarDetalle,
        acciones: widget.acciones,
        comprobarUbicacionInicio: widget.comprobarUbicacionInicio,
      );
    }
  }

  @override
  void dispose() {
    _desvincular();
    super.dispose();
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
    if (_controlador.fase == FaseDetalleViaje.cargando) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Cargando detalle del viaje',
        ),
      );
    }
    if (_controlador.fase != FaseDetalleViaje.listo) {
      if (widget.acciones != null ||
          _controlador.operacionPendiente != null ||
          _controlador.viajeConfirmado != null) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AccionesViajeChofer(controlador: _controlador),
          ),
        );
      }
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _controlador.fase == FaseDetalleViaje.error
                    ? 'No pudimos cargar el detalle.'
                    : 'Detalle no disponible.',
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _controlador.consultar,
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
    final detalle = _controlador.detalle!;
    final viaje = detalle.viaje;
    final fecha =
        '${viaje.fecha.day.toString().padLeft(2, '0')}/'
        '${viaje.fecha.month.toString().padLeft(2, '0')}/${viaje.fecha.year}';
    final c = detalle.cantidades;
    return ListView(
      key: ValueKey('detalle-${viaje.idViaje}'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (widget.acciones != null)
          AccionesViajeChofer(controlador: _controlador),
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
    padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
    child: Text(texto, style: Theme.of(context).textTheme.headlineSmall),
  );

  Widget _fila(String texto, {Key? key}) => Padding(
    key: key,
    // Solo datos de lectura; los controles conservan sus targets de 64 px.
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
