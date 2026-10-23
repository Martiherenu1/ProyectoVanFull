import 'package:flutter/material.dart';

import '../../core/format/fecha_legible.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chofer/viaje_resumen.dart';

/// La integración futura deberá consultar los viajes administrativos de esta
/// fecha. La pantalla no crea un cliente HTTP ni administra una sesión.
typedef CargarViajesDelDia = Future<List<ViajeResumen>> Function(
  DateTime fecha,
);

class ViajesDiaAdminScreen extends StatefulWidget {
  const ViajesDiaAdminScreen({
    required this.fecha,
    required this.cargarViajes,
    required this.onViajeSeleccionado,
    super.key,
  });

  final DateTime fecha;
  final CargarViajesDelDia cargarViajes;
  final ValueChanged<int> onViajeSeleccionado;

  @override
  State<ViajesDiaAdminScreen> createState() => _ViajesDiaAdminScreenState();
}

class _ViajesDiaAdminScreenState extends State<ViajesDiaAdminScreen> {
  late DateTime _fecha;
  List<ViajeResumen> _viajes = const [];
  bool _cargando = true;
  bool _error = false;
  int _solicitud = 0;

  @override
  void initState() {
    super.initState();
    _fecha = DateUtils.dateOnly(widget.fecha);
    _cargar();
  }

  @override
  void didUpdateWidget(covariant ViajesDiaAdminScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final fechaNueva = DateUtils.dateOnly(widget.fecha);
    if (oldWidget.cargarViajes != widget.cargarViajes ||
        !DateUtils.isSameDay(fechaNueva, _fecha)) {
      _fecha = fechaNueva;
      _cargar();
    }
  }

  Future<void> _cargar() async {
    final solicitud = ++_solicitud;
    final fecha = _fecha;
    setState(() {
      _cargando = true;
      _error = false;
      _viajes = const [];
    });
    try {
      final viajes = await widget.cargarViajes(fecha);
      if (!mounted || solicitud != _solicitud) return;
      setState(() {
        _viajes = List.unmodifiable(viajes);
        _cargando = false;
      });
    } catch (_) {
      if (!mounted || solicitud != _solicitud) return;
      setState(() {
        _cargando = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.admin,
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Viajes del día')),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  'Fecha: ${fechaLegible(_fecha)}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Expanded(child: _contenido()),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _contenido() {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Cargando viajes'),
      );
    }
    if (_error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No pudimos cargar los viajes. Volvé a intentar.'),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _cargar,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.adminRowHeight),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_viajes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text('No hay viajes registrados para esta fecha.'),
        ),
      );
    }

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: AppSpacing.adminRowHeight,
            dataRowMinHeight: AppSpacing.adminRowHeight,
            dataRowMaxHeight: AppSpacing.adminRowHeight,
            showCheckboxColumn: false,
            columns: const [
              DataColumn(label: Text('Hora')),
              DataColumn(label: Text('Viaje')),
              DataColumn(label: Text('Sentido')),
              DataColumn(label: Text('Estado')),
              DataColumn(label: Text('Servicio')),
              DataColumn(label: Text('Recorrido')),
              DataColumn(label: Text('Vehículo')),
              DataColumn(label: Text('Chofer')),
            ],
            rows: [
              for (final viaje in _viajes)
                DataRow(
                  key: ValueKey('viaje-${viaje.idViaje}'),
                  onSelectChanged: (_) =>
                      widget.onViajeSeleccionado(viaje.idViaje),
                  cells: [
                    DataCell(Text(viaje.horario ?? 'Sin horario')),
                    DataCell(Text(viaje.idViaje.toString())),
                    DataCell(Text(viaje.sentido.etiqueta)),
                    DataCell(Text(viaje.estado.etiqueta)),
                    DataCell(Text('ID ${viaje.idServicio}')),
                    DataCell(Text('ID ${viaje.idRecorrido}')),
                    DataCell(
                      _asignacion(
                        tipo: 'Vehículo',
                        id: viaje.idVehiculo,
                        viaje: viaje.idViaje,
                      ),
                    ),
                    DataCell(
                      _asignacion(
                        tipo: 'Chofer',
                        id: viaje.idChofer,
                        viaje: viaje.idViaje,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _asignacion({
    required String tipo,
    required int? id,
    required int viaje,
  }) {
    if (id != null) return Text('ID $id');
    return Semantics(
      label: '$tipo sin asignar',
      child: Row(
        key: ValueKey('viaje-$viaje-${tipo.toLowerCase()}-pendiente'),
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.pending_outlined, size: 18),
          SizedBox(width: AppSpacing.xs),
          Text('Sin asignar'),
        ],
      ),
    );
  }
}
