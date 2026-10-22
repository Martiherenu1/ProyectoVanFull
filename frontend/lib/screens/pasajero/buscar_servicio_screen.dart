import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../models/chofer/viaje_resumen.dart' show SentidoViaje;
import '../../models/pasajero/disponibilidad_viaje.dart';
import '../../models/pasajero/parada.dart';

/// El adaptador común deberá consultar GET /servicios/disponibilidad con la
/// fecha y el sentido explícitos. No se envía `destino`: el backend lo rechaza
/// hasta que se resuelva el Issue #8.
typedef CargarDisponibilidad = Future<List<DisponibilidadViaje>> Function(
  DateTime fecha,
  SentidoViaje sentido,
);

/// Consulta GET /recorridos/{id}/paradas.
typedef CargarParadas = Future<List<Parada>> Function(int idRecorrido);

/// CU-002. La pantalla no crea clientes HTTP ni administra la sesión.
class BuscarServicioScreen extends StatefulWidget {
  const BuscarServicioScreen({
    super.key,
    required this.cargarDisponibilidad,
    required this.cargarParadas,
    required this.onReservar,
    this.fechaInicial,
  });

  final CargarDisponibilidad cargarDisponibilidad;
  final CargarParadas cargarParadas;

  /// El pasajero eligió un viaje con lugar: sigue la pantalla de reserva.
  final ValueChanged<DisponibilidadViaje> onReservar;

  /// Solo inicializa la selección. Por defecto, el día local del dispositivo.
  final DateTime? fechaInicial;

  @override
  State<BuscarServicioScreen> createState() => _BuscarServicioScreenState();
}

class _BuscarServicioScreenState extends State<BuscarServicioScreen> {
  late DateTime _fecha;
  SentidoViaje _sentido = SentidoViaje.ida;
  List<DisponibilidadViaje> _viajes = const [];
  bool _cargando = true;
  bool _error = false;
  int _solicitud = 0;
  int? _viajeAbierto;
  final Map<int, Future<List<Parada>>> _paradas = {};

  @override
  void initState() {
    super.initState();
    _fecha = DateUtils.dateOnly(widget.fechaInicial ?? DateTime.now());
    _cargar();
  }

  @override
  void didUpdateWidget(covariant BuscarServicioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cargarParadas != widget.cargarParadas) _paradas.clear();
    if (oldWidget.cargarDisponibilidad != widget.cargarDisponibilidad) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    final solicitud = ++_solicitud;
    final fecha = _fecha;
    final sentido = _sentido;
    setState(() {
      _cargando = true;
      _error = false;
      _viajes = const [];
      _viajeAbierto = null;
    });
    try {
      final viajes = await widget.cargarDisponibilidad(fecha, sentido);
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

  Future<void> _elegirFecha(BuildContext context) async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final tope = hoy.add(const Duration(days: 365));
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: _fecha.isBefore(hoy) ? _fecha : hoy,
      lastDate: _fecha.isAfter(tope) ? _fecha : tope,
      helpText: 'Elegí la fecha del viaje',
      cancelText: 'Cancelar',
      confirmText: 'Buscar',
    );
    if (!mounted || elegida == null || DateUtils.isSameDay(elegida, _fecha)) {
      return;
    }
    _fecha = DateUtils.dateOnly(elegida);
    await _cargar();
  }

  void _elegirSentido(SentidoViaje sentido) {
    if (sentido == _sentido) return;
    _sentido = sentido;
    _cargar();
  }

  void _alternarViaje(DisponibilidadViaje viaje) {
    setState(() {
      if (_viajeAbierto == viaje.idViaje) {
        _viajeAbierto = null;
        return;
      }
      _viajeAbierto = viaje.idViaje;
      _paradas.putIfAbsent(
        viaje.idRecorrido,
        () => _pedirParadas(viaje.idRecorrido),
      );
    });
  }

  void _reintentarParadas(int idRecorrido) {
    setState(() {
      _paradas[idRecorrido] = _pedirParadas(idRecorrido);
    });
  }

  Future<List<Parada>> _pedirParadas(int idRecorrido) {
    final paradas = widget.cargarParadas(idRecorrido);
    // El FutureBuilder se engancha en el frame siguiente: si falla antes,
    // el error se mostraría igual pero Dart lo reportaría como no manejado.
    paradas.ignore();
    return paradas;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.passenger,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Buscar servicio')),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _filtros(context),
                _dato(context),
                Expanded(child: _contenido(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filtros(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('seleccionar-fecha'),
            onPressed: () => _elegirFecha(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.touchTarget),
              alignment: Alignment.centerLeft,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
              ),
            ),
            icon: const Icon(Icons.calendar_today),
            label: Text('Fecha: ${_fechaLegible(_fecha)}'),
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<SentidoViaje>(
            key: const ValueKey('seleccionar-sentido'),
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.touchTarget),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
              ),
            ),
            segments: [
              for (final sentido in SentidoViaje.values)
                ButtonSegment(value: sentido, label: Text(sentido.etiqueta)),
            ],
            selected: {_sentido},
            onSelectionChanged: (seleccion) => _elegirSentido(seleccion.single),
          ),
        ],
      ),
    );
  }

  /// El dato dominante de la pantalla: cuántos viajes hay ese día.
  Widget _dato(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cantidad = _cargando || _error ? '–' : '${_viajes.length}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VIAJES · ${_sentido.etiqueta.toUpperCase()} · '
            '${_fechaLegible(_fecha)}',
            style: textTheme.labelSmall,
          ),
          Text(
            cantidad,
            key: const ValueKey('cantidad-viajes'),
            style: textTheme.displayLarge,
          ),
        ],
      ),
    );
  }

  Widget _contenido(BuildContext context) {
    if (_cargando) return const _Esqueleto();
    if (_error) {
      return _Mensaje(
        texto: 'No pudimos cargar los viajes. Volvé a intentar.',
        accion: 'Reintentar',
        onAccion: _cargar,
      );
    }
    if (_viajes.isEmpty) {
      return _Mensaje(
        texto:
            'No hay viajes ${_sentido.etiqueta.toLowerCase()} para el '
            '${_fechaLegible(_fecha)}. Probá con otra fecha.',
        accion: 'Cambiar fecha',
        onAccion: () => _elegirFecha(context),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: _viajes.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final viaje = _viajes[index];
        final abierto = _viajeAbierto == viaje.idViaje;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilaViaje(
              viaje: viaje,
              abierto: abierto,
              onTap: () => _alternarViaje(viaje),
            ),
            if (abierto)
              _DetalleViaje(
                viaje: viaje,
                paradas: _paradas[viaje.idRecorrido]!,
                onReintentar: () => _reintentarParadas(viaje.idRecorrido),
                onReservar: () => widget.onReservar(viaje),
              ),
          ],
        );
      },
    );
  }
}

class _FilaViaje extends StatelessWidget {
  const _FilaViaje({
    required this.viaje,
    required this.abierto,
    required this.onTap,
  });

  final DisponibilidadViaje viaje;
  final bool abierto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cupo = viaje.cupoDisponible;
    final sinCupo = cupo == 0;
    return InkWell(
      key: ValueKey('viaje-${viaje.idViaje}'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSpacing.passengerRowHeight,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                viaje.horario ?? 'Sin horario',
                style: AppTypography.data,
              ),
            ),
            Text(
              switch (cupo) {
                null => 'Cupo a confirmar',
                0 => 'Sin cupo',
                1 => '1 lugar',
                _ => '$cupo lugares',
              },
              style: AppTypography.data.copyWith(
                color: sinCupo ? AppColors.alertDark : null,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(abierto ? Icons.expand_less : Icons.expand_more),
          ],
        ),
      ),
    );
  }
}

class _DetalleViaje extends StatelessWidget {
  const _DetalleViaje({
    required this.viaje,
    required this.paradas,
    required this.onReintentar,
    required this.onReservar,
  });

  final DisponibilidadViaje viaje;
  final Future<List<Parada>> paradas;
  final VoidCallback onReintentar;
  final VoidCallback onReservar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sinCupo = viaje.cupoDisponible == 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('PARADAS', style: textTheme.labelSmall),
          const SizedBox(height: AppSpacing.sm),
          FutureBuilder<List<Parada>>(
            future: paradas,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Row(
                  children: [
                    const Expanded(
                      child: Text('No pudimos cargar las paradas.'),
                    ),
                    TextButton(
                      key: const ValueKey('reintentar-paradas'),
                      onPressed: onReintentar,
                      child: const Text('Reintentar'),
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: LinearProgressIndicator(
                    semanticsLabel: 'Cargando paradas',
                  ),
                );
              }
              final lista = [...snapshot.data!]
                ..sort((a, b) => a.orden.compareTo(b.orden));
              if (lista.isEmpty) {
                return const Text('Este recorrido todavía no tiene paradas.');
              }
              return Column(
                children: [
                  for (final parada in lista) _FilaParada(parada: parada),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            key: const ValueKey('reservar-viaje'),
            onPressed: sinCupo ? null : onReservar,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.touchTarget),
            ),
            child: Text(
              sinCupo ? 'Sin cupo en este viaje' : 'Reservar este viaje',
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaParada extends StatelessWidget {
  const _FilaParada({required this.parada});

  final Parada parada;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppSpacing.passengerRowHeight,
      ),
      child: Row(
        children: [
          SizedBox(
            width: AppSpacing.xxl,
            child: Text('${parada.orden}', style: AppTypography.data),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(parada.titulo),
                if (parada.detalle != null)
                  Text(parada.detalle!, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Filas con la forma real del contenido mientras carga (brief §8).
class _Esqueleto extends StatelessWidget {
  const _Esqueleto();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Semantics(
      label: 'Cargando viajes',
      child: ExcludeSemantics(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          itemCount: 5,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (_, _) => SizedBox(
            height: AppSpacing.passengerRowHeight,
            child: Row(
              children: [
                ColoredBox(
                  color: color,
                  child: const SizedBox(width: 56, height: 14),
                ),
                const Spacer(),
                ColoredBox(
                  color: color,
                  child: const SizedBox(width: 88, height: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.texto,
    required this.accion,
    required this.onAccion,
  });

  final String texto;
  final String accion;
  final VoidCallback onAccion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(texto),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: onAccion,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.touchTarget),
            ),
            child: Text(accion),
          ),
        ],
      ),
    );
  }
}

String _fechaLegible(DateTime fecha) =>
    '${fecha.day.toString().padLeft(2, '0')}/'
    '${fecha.month.toString().padLeft(2, '0')}/'
    '${fecha.year.toString().padLeft(4, '0')}';
