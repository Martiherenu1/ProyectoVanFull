import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/format/fecha_legible.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin/viaje_admin_resumen.dart';
import '../../models/admin/viaje_update.dart';
import '../../models/chofer/viaje_resumen.dart';

/// La integración futura deberá consultar los viajes administrativos de esta
/// fecha. La pantalla no crea un cliente HTTP ni administra una sesión.
typedef CargarViajesDelDia = Future<List<ViajeResumen>> Function(
  DateTime fecha,
);
typedef ActualizarViaje = Future<ViajeResumen> Function(
  int idViaje,
  ViajeUpdate solicitud,
);

class ViajesDiaAdminScreen extends StatefulWidget {
  const ViajesDiaAdminScreen({
    required this.fecha,
    required this.cargarViajes,
    required this.onViajeSeleccionado,
    this.actualizarViaje,
    super.key,
  });

  final DateTime fecha;
  final CargarViajesDelDia cargarViajes;
  final ValueChanged<int> onViajeSeleccionado;
  final ActualizarViaje? actualizarViaje;

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

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      helpText: 'Seleccionar fecha de viajes',
    );
    if (!mounted || fecha == null || DateUtils.isSameDay(fecha, _fecha)) {
      return;
    }
    _fecha = DateUtils.dateOnly(fecha);
    await _cargar();
  }

  void _seleccionarViaje(ViajeResumen viaje) {
    widget.onViajeSeleccionado(viaje.idViaje);
    showDialog<void>(
      context: context,
      builder: (context) => _DetalleViajeAdminDialog(
        viaje: viaje,
        actualizarViaje: widget.actualizarViaje,
        onActualizado: (_) => _cargar(),
      ),
    );
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
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.sm,
                  children: [
                    Text(
                      'Fecha: ${fechaLegible(_fecha)}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('seleccionar-fecha-viajes'),
                      onPressed: _seleccionarFecha,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, AppSpacing.adminRowHeight),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Cambiar fecha'),
                    ),
                  ],
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
                  onSelectChanged: (_) => _seleccionarViaje(viaje),
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

class _DetalleViajeAdminDialog extends StatefulWidget {
  const _DetalleViajeAdminDialog({
    required this.viaje,
    required this.actualizarViaje,
    required this.onActualizado,
  });

  final ViajeResumen viaje;
  final ActualizarViaje? actualizarViaje;
  final Future<void> Function(ViajeResumen viaje) onActualizado;

  @override
  State<_DetalleViajeAdminDialog> createState() =>
      _DetalleViajeAdminDialogState();
}

class _DetalleViajeAdminDialogState extends State<_DetalleViajeAdminDialog> {
  late ViajeResumen _viaje = widget.viaje;

  Future<void> _editar() async {
    final actualizado = await showDialog<ViajeResumen>(
      context: context,
      builder: (context) => _EditarViajeAdminDialog(
        viaje: _viaje,
        actualizarViaje: widget.actualizarViaje!,
      ),
    );
    if (!mounted || actualizado == null) return;
    setState(() => _viaje = actualizado);
    await widget.onActualizado(actualizado);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Viaje ${_viaje.idViaje}'),
    content: SingleChildScrollView(
      child: Column(
        key: ValueKey('detalle-viaje-${_viaje.idViaje}'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dato('Fecha', fechaLegible(_viaje.fecha)),
          _dato('Horario', _viaje.horario ?? 'Sin horario'),
          _dato('Estado', _viaje.estado.etiqueta),
          _dato('Sentido', _viaje.sentido.etiqueta),
          _dato('Servicio', 'ID ${_viaje.idServicio}'),
          _dato('Recorrido', 'ID ${_viaje.idRecorrido}'),
          _dato('Capacidad', _capacidad(_viaje)?.toString() ?? 'Sin definir'),
          _dato(
            'Vehículo',
            _viaje.idVehiculo == null
                ? 'Sin asignar'
                : 'ID ${_viaje.idVehiculo}',
          ),
          _dato(
            'Chofer',
            _viaje.idChofer == null ? 'Sin asignar' : 'ID ${_viaje.idChofer}',
          ),
        ],
      ),
    ),
    actions: [
      if (_viaje.estado == EstadoViaje.programado &&
          widget.actualizarViaje != null)
        FilledButton(
          key: const Key('editar-viaje'),
          onPressed: _editar,
          child: const Text('Editar'),
        ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cerrar'),
      ),
    ],
  );

  Widget _dato(String etiqueta, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text('$etiqueta: $valor'),
  );

  static int? _capacidad(ViajeResumen viaje) =>
      viaje is ViajeAdminResumen ? viaje.capacidadPlanificada : null;
}

class _EditarViajeAdminDialog extends StatefulWidget {
  const _EditarViajeAdminDialog({
    required this.viaje,
    required this.actualizarViaje,
  });

  final ViajeResumen viaje;
  final ActualizarViaje actualizarViaje;

  @override
  State<_EditarViajeAdminDialog> createState() =>
      _EditarViajeAdminDialogState();
}

class _EditarViajeAdminDialogState extends State<_EditarViajeAdminDialog> {
  final _formulario = GlobalKey<FormState>();
  late final _fecha = TextEditingController(
    text: _fechaIso(widget.viaje.fecha),
  );
  late final _horario = TextEditingController(text: widget.viaje.horario);
  late final _capacidad = TextEditingController(
    text: widget.viaje is ViajeAdminResumen
        ? (widget.viaje as ViajeAdminResumen).capacidadPlanificada?.toString()
        : null,
  );
  late final _chofer = TextEditingController(
    text: widget.viaje.idChofer?.toString(),
  );
  late final _vehiculo = TextEditingController(
    text: widget.viaje.idVehiculo?.toString(),
  );
  late SentidoViaje _sentido = widget.viaje.sentido;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _fecha.dispose();
    _horario.dispose();
    _capacidad.dispose();
    _chofer.dispose();
    _vehiculo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando || !_formulario.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final actualizado = await widget.actualizarViaje(
        widget.viaje.idViaje,
        ViajeUpdate(
          fecha: _leerFecha(_fecha.text.trim())!,
          horario: _textoOpcional(_horario.text),
          sentido: _sentido,
          capacidadPlanificada: _enteroOpcional(_capacidad.text),
          idChofer: _enteroOpcional(_chofer.text),
          idVehiculo: _enteroOpcional(_vehiculo.text),
        ),
      );
      if (mounted) Navigator.of(context).pop(actualizado);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = error.mensaje;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = 'No pudimos actualizar el viaje. Volvé a intentar.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Editar viaje ${widget.viaje.idViaje}'),
    content: SingleChildScrollView(
      child: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _campoTexto(
              key: const Key('editar-fecha'),
              controller: _fecha,
              label: 'Fecha (AAAA-MM-DD)',
              validator: _validarFecha,
            ),
            _campoTexto(
              key: const Key('editar-horario'),
              controller: _horario,
              label: 'Horario (opcional)',
            ),
            DropdownButtonFormField<SentidoViaje>(
              key: const Key('editar-sentido'),
              initialValue: _sentido,
              decoration: const InputDecoration(labelText: 'Sentido'),
              items: [
                for (final sentido in SentidoViaje.values)
                  DropdownMenuItem(
                    value: sentido,
                    child: Text(sentido.etiqueta),
                  ),
              ],
              onChanged: _guardando
                  ? null
                  : (valor) {
                      if (valor != null) setState(() => _sentido = valor);
                    },
            ),
            _campoEntero(
              key: const Key('editar-capacidad'),
              controller: _capacidad,
              label: 'Capacidad planificada (opcional)',
            ),
            _campoEntero(
              key: const Key('editar-chofer'),
              controller: _chofer,
              label: 'Chofer (ID, opcional)',
            ),
            _campoEntero(
              key: const Key('editar-vehiculo'),
              controller: _vehiculo,
              label: 'Vehículo (ID, opcional)',
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                key: const Key('actualizacion-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _guardando ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('guardar-viaje'),
        onPressed: _guardando ? null : _guardar,
        child: Text(_guardando ? 'Guardando…' : 'Guardar'),
      ),
    ],
  );

  Widget _campoTexto({
    required Key key,
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextFormField(
      key: key,
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: validator,
      enabled: !_guardando,
    ),
  );

  Widget _campoEntero({
    required Key key,
    required TextEditingController controller,
    required String label,
  }) => _campoTexto(
    key: key,
    controller: controller,
    label: label,
    validator: (valor) {
      final texto = valor?.trim() ?? '';
      return texto.isNotEmpty && int.tryParse(texto) == null
          ? 'Ingresá un número entero.'
          : null;
    },
  );

  static String? _validarFecha(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Campo obligatorio.';
    return _leerFecha(texto) == null ? 'Usá el formato AAAA-MM-DD.' : null;
  }

  static DateTime? _leerFecha(String texto) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(texto)) return null;
    final fecha = DateTime.tryParse(texto);
    if (fecha == null || _fechaIso(fecha) != texto) return null;
    return fecha;
  }

  static String _fechaIso(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';

  static int? _enteroOpcional(String valor) {
    final texto = valor.trim();
    return texto.isEmpty ? null : int.parse(texto);
  }

  static String? _textoOpcional(String valor) {
    final texto = valor.trim();
    return texto.isEmpty ? null : texto;
  }
}
