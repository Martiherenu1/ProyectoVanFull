import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/admin/historial_viaje.dart';

typedef ListarHistorial = Future<List<HistorialViaje>> Function(
  HistorialFiltros filtros,
);
typedef DetalleHistorial = Future<HistorialViajeDetalle> Function(int idViaje);

const _estados = {
  'programado': 'Programado',
  'en_curso': 'En curso',
  'finalizado': 'Finalizado',
  'cancelado': 'Cancelado',
};

/// CU-026: administración y dueño consultan viajes anteriores.
///
/// Solo lectura. Muestra cantidades de reservas, abordajes y ausencias, nunca
/// datos de los pasajeros. El plazo de retención está pendiente (v1.3).
class HistorialViajesScreen extends StatefulWidget {
  const HistorialViajesScreen({
    required this.listar,
    required this.detalle,
    super.key,
  });

  final ListarHistorial listar;
  final DetalleHistorial detalle;

  @override
  State<HistorialViajesScreen> createState() => _HistorialViajesScreenState();
}

class _HistorialViajesScreenState extends State<HistorialViajesScreen> {
  DateTime? _desde;
  DateTime? _hasta;
  String? _estado;
  String? _sentido;
  List<HistorialViaje>? _items;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  Future<void> _buscar() async {
    setState(() {
      _items = null;
      _error = false;
    });
    try {
      final items = await widget.listar(
        HistorialFiltros(
          desde: _desde,
          hasta: _hasta,
          estado: _estado,
          sentido: _sentido,
        ),
      );
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _elegirFecha({required bool esDesde}) async {
    final inicial = (esDesde ? _desde : _hasta) ?? DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (elegida == null || !mounted) return;
    setState(() => esDesde ? _desde = elegida : _hasta = elegida);
  }

  bool get _rangoInvertido =>
      _desde != null && _hasta != null && _desde!.isAfter(_hasta!);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Historial de viajes')),
    body: Column(
      children: [
        _filtros(),
        const Divider(height: 1),
        Expanded(child: _cuerpo()),
      ],
    ),
  );

  Widget _filtros() => Padding(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          key: const Key('historial-desde'),
          onPressed: () => _elegirFecha(esDesde: true),
          child: Text(_desde == null ? 'Desde' : 'Desde ${fechaIso(_desde!)}'),
        ),
        OutlinedButton(
          key: const Key('historial-hasta'),
          onPressed: () => _elegirFecha(esDesde: false),
          child: Text(_hasta == null ? 'Hasta' : 'Hasta ${fechaIso(_hasta!)}'),
        ),
        DropdownButton<String?>(
          key: const Key('historial-estado'),
          value: _estado,
          hint: const Text('Estado'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todos')),
            for (final e in _estados.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => _estado = v),
        ),
        DropdownButton<String?>(
          key: const Key('historial-sentido'),
          value: _sentido,
          hint: const Text('Sentido'),
          items: const [
            DropdownMenuItem(value: null, child: Text('Ambos')),
            DropdownMenuItem(value: 'IDA', child: Text('Ida')),
            DropdownMenuItem(value: 'VUELTA', child: Text('Vuelta')),
          ],
          onChanged: (v) => setState(() => _sentido = v),
        ),
        FilledButton(
          key: const Key('historial-buscar'),
          onPressed: _rangoInvertido ? null : _buscar,
          child: const Text('Buscar'),
        ),
        if (_rangoInvertido)
          Text(
            'La fecha «Desde» no puede ser posterior a «Hasta».',
            key: const Key('historial-rango-invalido'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );

  Widget _cuerpo() {
    if (_error) {
      return Center(
        key: const Key('historial-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No se pudo cargar el historial.'),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const Key('historial-reintentar'),
              onPressed: _buscar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    final items = _items;
    if (items == null) {
      return const Center(
        key: Key('historial-cargando'),
        child: CircularProgressIndicator(),
      );
    }
    if (items.isEmpty) {
      return const Center(
        key: Key('historial-vacio'),
        child: Text('No se encontraron registros.'),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _fila(items[i]),
    );
  }

  Widget _fila(HistorialViaje v) => ListTile(
    key: Key('historial-viaje-${v.idViaje}'),
    title: Text(
      '${v.fecha}${v.horario == null ? '' : ' ${v.horario}'} · '
      '${v.sentido == 'IDA' ? 'Ida' : 'Vuelta'}',
    ),
    subtitle: Text(
      '${_estados[v.estado] ?? v.estado} · ${v.tipoServicio}'
      '${v.chofer == null ? '' : ' · ${v.chofer!.nombreCompleto}'}',
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _DetalleViaje(idViaje: v.idViaje, detalle: widget.detalle),
      ),
    ),
  );
}

class _DetalleViaje extends StatefulWidget {
  const _DetalleViaje({required this.idViaje, required this.detalle});

  final int idViaje;
  final DetalleHistorial detalle;

  @override
  State<_DetalleViaje> createState() => _DetalleViajeState();
}

class _DetalleViajeState extends State<_DetalleViaje> {
  HistorialViajeDetalle? _datos;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _datos = null;
      _error = null;
    });
    try {
      final datos = await widget.detalle(widget.idViaje);
      if (mounted) setState(() => _datos = datos);
    } catch (e) {
      if (mounted) setState(() => _error = _mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Viaje ${widget.idViaje}')),
    body: _cuerpo(),
  );

  Widget _cuerpo() {
    final error = _error;
    if (error != null) {
      return Center(
        key: const Key('detalle-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const Key('detalle-reintentar'),
              onPressed: _cargar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    final d = _datos;
    if (d == null) {
      return const Center(
        key: Key('detalle-cargando'),
        child: CircularProgressIndicator(),
      );
    }
    final v = d.viaje;
    final c = d.conteos;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _dato('Fecha', '${v.fecha}${v.horario == null ? '' : ' ${v.horario}'}'),
        _dato('Sentido', v.sentido == 'IDA' ? 'Ida' : 'Vuelta'),
        _dato('Estado', _estados[v.estado] ?? v.estado),
        _dato('Servicio', v.tipoServicio),
        _dato('Chofer', v.chofer?.nombreCompleto ?? 'Sin asignar'),
        _dato('Vehículo', v.patente ?? 'Sin asignar'),
        if (d.capacidadPlanificada != null)
          _dato('Capacidad planificada', '${d.capacidadPlanificada}'),
        const SizedBox(height: AppSpacing.lg),
        Text('Paradas', style: Theme.of(context).textTheme.titleMedium),
        for (final p in d.paradas)
          ListTile(
            key: Key('detalle-parada-${p.orden}'),
            dense: true,
            leading: Text('${p.orden}'),
            title: Text(p.etiqueta),
          ),
        const SizedBox(height: AppSpacing.lg),
        Text('Movimiento', style: Theme.of(context).textTheme.titleMedium),
        _dato('Reservas consolidadas', '${c.consolidadas}'),
        _dato('Reservas provisionales', '${c.provisionales}'),
        _dato('Reservas canceladas', '${c.canceladas}'),
        _dato('Abordajes', '${c.abordajes}'),
        _dato('Ausencias', '${c.ausencias}'),
      ],
    );
  }

  Widget _dato(String etiqueta, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        Expanded(child: Text(etiqueta)),
        Text(valor, key: Key('dato-$etiqueta')),
      ],
    ),
  );
}

String _mensajeError(Object e) => switch (e) {
  ApiException(codigo: 'VIAJE_NO_ENCONTRADO') =>
    'Ese viaje ya no figura en el historial.',
  ApiException(statusCode: 403) => 'No tenés permiso para ver el historial.',
  ApiException(:final mensaje) => mensaje,
  _ => 'No se pudo cargar el viaje.',
};
