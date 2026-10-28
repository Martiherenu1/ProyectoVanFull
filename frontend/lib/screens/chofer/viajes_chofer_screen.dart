import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chofer/viaje_resumen.dart';

/// El adaptador común deberá consultar CU-029 con esta fecha explícita.
/// La pantalla no crea clientes HTTP ni administra la sesión.
typedef CargarViajesChofer = Future<List<ViajeResumen>> Function(
  DateTime fecha,
);

class ViajesChoferScreen extends StatefulWidget {
  const ViajesChoferScreen({
    super.key,
    required this.cargarViajes,
    required this.onViajeSeleccionado,
    this.fechaInicial,
    this.invalidado = false,
    this.revisionRecarga = 0,
    this.onViajesAceptados,
  });

  final CargarViajesChofer cargarViajes;
  final ValueChanged<int> onViajeSeleccionado;
  final ValueChanged<List<ViajeResumen>>? onViajesAceptados;

  /// Solo inicializa la selección. Por defecto, el día local del dispositivo;
  /// se envía explícitamente, sin asumir la fecha por defecto del servidor.
  final DateTime? fechaInicial;

  /// Retira filas y descarta consultas previas sin iniciar otra consulta.
  final bool invalidado;

  /// Solicita otra lectura sin remontar la pantalla ni cambiar la fecha.
  final int revisionRecarga;

  @override
  State<ViajesChoferScreen> createState() => _ViajesChoferScreenState();
}

class _ViajesChoferScreenState extends State<ViajesChoferScreen> {
  late DateTime _fecha;
  List<ViajeResumen> _viajes = const [];
  bool _cargando = true;
  bool _error = false;
  int _solicitud = 0;

  @override
  void initState() {
    super.initState();
    _fecha = DateUtils.dateOnly(widget.fechaInicial ?? DateTime.now());
    if (widget.invalidado) {
      _cargando = false;
    } else {
      _cargar();
    }
  }

  @override
  void didUpdateWidget(covariant ViajesChoferScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.invalidado) {
      _solicitud++;
      _viajes = const [];
      _cargando = false;
      _error = false;
    } else if (oldWidget.invalidado ||
        oldWidget.revisionRecarga != widget.revisionRecarga ||
        oldWidget.cargarViajes != widget.cargarViajes) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    if (widget.invalidado) return;
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
      widget.onViajesAceptados?.call(_viajes);
    } catch (_) {
      if (!mounted || solicitud != _solicitud) return;
      setState(() {
        _cargando = false;
        _error = true;
      });
    }
  }

  Future<void> _elegirFecha(BuildContext context) async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      helpText: 'Elegí la fecha de los viajes',
      cancelText: 'Cancelar',
      confirmText: 'Consultar',
    );
    if (!mounted || elegida == null || DateUtils.isSameDay(elegida, _fecha)) {
      return;
    }
    _fecha = DateUtils.dateOnly(elegida);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.driver,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Mis viajes')),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: OutlinedButton.icon(
                    key: const ValueKey('seleccionar-fecha'),
                    onPressed: () => _elegirFecha(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, AppSpacing.driverTouchTarget),
                    ),
                    icon: const Icon(Icons.calendar_today),
                    label: Text('Fecha: ${_fechaLegible(_fecha)}'),
                  ),
                ),
                Expanded(child: _contenido()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido() {
    if (widget.invalidado) {
      return const Center(child: Text('El listado necesita actualizarse.'));
    }
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
                  minimumSize: const Size(0, AppSpacing.driverTouchTarget),
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
          child: Text('No tenés viajes asignados para esta fecha.'),
        ),
      );
    }
    // Conservar el orden del backend: horario, NULL al final e ID.
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: _viajes.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final viaje = _viajes[index];
        return ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.driverRowHeight,
          ),
          child: ListTile(
            key: ValueKey('viaje-${viaje.idViaje}'),
            minTileHeight: AppSpacing.driverRowHeight,
            title: Text(viaje.horario ?? 'Sin horario'),
            subtitle: Text(
              'Viaje ${viaje.idViaje} · ${viaje.sentido.etiqueta} · '
              '${viaje.estado.etiqueta}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.onViajeSeleccionado(viaje.idViaje),
          ),
        );
      },
    );
  }
}

String _fechaLegible(DateTime fecha) =>
    '${fecha.day.toString().padLeft(2, '0')}/'
    '${fecha.month.toString().padLeft(2, '0')}/'
    '${fecha.year.toString().padLeft(4, '0')}';
