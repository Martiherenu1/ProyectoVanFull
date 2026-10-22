import 'package:flutter/material.dart';

import '../../core/format/fecha_legible.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../models/pasajero/disponibilidad_viaje.dart';
import '../../models/pasajero/parada.dart';
import '../../models/pasajero/reserva.dart';
import 'buscar_servicio_screen.dart' show CargarParadas;

/// El adaptador común deberá hacer POST /reservas con `id_viaje` y
/// `orden_parada`. Ante un 400 o 409 con el cuerpo de error del contrato,
/// lanza [ReservaRechazada]; cualquier otra falla (red, 5xx) se lanza tal cual.
typedef CrearReserva = Future<Reserva> Function(int idViaje, int ordenParada);

/// CU-003. La pantalla no crea clientes HTTP ni decide cupo ni reglas: lo que
/// rechaza el backend (RN-001, RN-031) se muestra con su motivo concreto.
/// No muestra tarifa: el cálculo del importe está pendiente (Issue #9).
class ConfirmarReservaScreen extends StatefulWidget {
  const ConfirmarReservaScreen({
    super.key,
    required this.viaje,
    required this.cargarParadas,
    required this.crearReserva,
    required this.onTerminar,
  });

  /// El viaje elegido en Buscar servicio.
  final DisponibilidadViaje viaje;
  final CargarParadas cargarParadas;
  final CrearReserva crearReserva;

  /// El pasajero vio su reserva creada y sigue con la app.
  final ValueChanged<Reserva> onTerminar;

  @override
  State<ConfirmarReservaScreen> createState() => _ConfirmarReservaScreenState();
}

class _ConfirmarReservaScreenState extends State<ConfirmarReservaScreen> {
  late Future<List<Parada>> _paradas;
  Parada? _paradaElegida;
  bool _enviando = false;
  _Aviso? _aviso;
  Reserva? _reserva;

  @override
  void initState() {
    super.initState();
    _paradas = _pedirParadas();
  }

  @override
  void didUpdateWidget(covariant ConfirmarReservaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cargarParadas != widget.cargarParadas ||
        oldWidget.viaje.idRecorrido != widget.viaje.idRecorrido) {
      _paradaElegida = null;
      _paradas = _pedirParadas();
    }
  }

  Future<List<Parada>> _pedirParadas() {
    final paradas = widget.cargarParadas(widget.viaje.idRecorrido);
    // El FutureBuilder se engancha en el frame siguiente: si falla antes,
    // el error se mostraría igual pero Dart lo reportaría como no manejado.
    paradas.ignore();
    return paradas;
  }

  void _reintentarParadas() {
    setState(() {
      _paradas = _pedirParadas();
    });
  }

  Future<void> _confirmar() async {
    final orden = _paradaElegida?.orden;
    if (orden == null || _enviando) return;
    setState(() {
      _enviando = true;
      _aviso = null;
    });
    try {
      final reserva = await widget.crearReserva(widget.viaje.idViaje, orden);
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _reserva = reserva;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _aviso = _avisoDe(error);
      });
    }
  }

  _Aviso _avisoDe(Object error) {
    final viaje = widget.viaje;
    final cuando = viaje.horario == null ? 'este viaje' : 'el ${viaje.horario}';
    if (error is ReservaRechazada) {
      return switch (error.codigo) {
        'CUPO_NO_DISPONIBLE' => _Aviso(
          'Sin cupo en $cuando. Volvé a buscar y elegí otro viaje.',
          definitivo: true,
        ),
        'RESERVA_DUPLICADA_DEL_DIA' => _Aviso(
          'Ya tenés una reserva de ${viaje.sentido.etiqueta.toLowerCase()} '
          'para el ${fechaLegible(viaje.fecha)}.',
          definitivo: true,
        ),
        'RESERVA_CANCELADA_PREVIA' => const _Aviso(
          'Ya cancelaste una reserva en este viaje y no se puede reactivar.',
          definitivo: true,
        ),
        'VIAJE_NO_RESERVABLE' => const _Aviso(
          'Este viaje ya no admite reservas.',
          definitivo: true,
        ),
        'PARADA_NO_VALIDA' => const _Aviso(
          'Esa parada no pertenece a este viaje. Elegí otra.',
        ),
        _ => _Aviso(error.mensaje),
      };
    }
    return const _Aviso('No pudimos crear la reserva. Volvé a intentar.');
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.passenger,
      child: Builder(
        builder: (context) {
          final reserva = _reserva;
          return Scaffold(
            appBar: AppBar(
              title: Text(
                reserva == null ? 'Confirmar reserva' : 'Reserva creada',
              ),
              automaticallyImplyLeading: reserva == null,
            ),
            body: SafeArea(
              child: reserva == null
                  ? _formulario(context)
                  : _Resultado(
                      reserva: reserva,
                      parada: _paradaElegida,
                      onTerminar: () => widget.onTerminar(reserva),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _formulario(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final viaje = widget.viaje;
    final aviso = _aviso;
    final bloqueado = aviso?.definitivo ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                '${viaje.sentido.etiqueta.toUpperCase()} · '
                '${fechaLegible(viaje.fecha)}',
                style: textTheme.labelSmall,
              ),
              Text(
                viaje.horario ?? 'Sin horario',
                key: const ValueKey('horario-viaje'),
                style: textTheme.displayLarge,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('¿DÓNDE SUBÍS?', style: textTheme.labelSmall),
              const SizedBox(height: AppSpacing.sm),
              FutureBuilder<List<Parada>>(
                future: _paradas,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Row(
                      children: [
                        const Expanded(
                          child: Text('No pudimos cargar las paradas.'),
                        ),
                        TextButton(
                          key: const ValueKey('reintentar-paradas'),
                          onPressed: _reintentarParadas,
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
                    return const Text(
                      'Este recorrido todavía no tiene paradas.',
                    );
                  }
                  return Column(
                    children: [
                      for (final parada in lista)
                        _FilaParadaElegible(
                          parada: parada,
                          elegida: parada.orden == _paradaElegida?.orden,
                          onTap: _enviando
                              ? null
                              : () => setState(() {
                                  _paradaElegida = parada;
                                  if (!(_aviso?.definitivo ?? false)) {
                                    _aviso = null;
                                  }
                                }),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        if (aviso != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              aviso.texto,
              key: const ValueKey('aviso-reserva'),
              style: textTheme.bodyMedium?.copyWith(color: AppColors.alertDark),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ElevatedButton(
            key: const ValueKey('confirmar-reserva'),
            onPressed: _paradaElegida == null || _enviando || bloqueado
                ? null
                : _confirmar,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.touchTarget),
            ),
            child: Text(
              _enviando
                  ? 'Reservando…'
                  : _paradaElegida == null
                  ? 'Elegí dónde subís'
                  : 'Confirmar reserva',
            ),
          ),
        ),
      ],
    );
  }
}

/// Texto de un rechazo. `definitivo`: reintentar con los mismos datos no
/// cambia el resultado, así que se bloquea el botón.
class _Aviso {
  const _Aviso(this.texto, {this.definitivo = false});

  final String texto;
  final bool definitivo;
}

class _FilaParadaElegible extends StatelessWidget {
  const _FilaParadaElegible({
    required this.parada,
    required this.elegida,
    required this.onTap,
  });

  final Parada parada;
  final bool elegida;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      selected: elegida,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        key: ValueKey('parada-${parada.orden}'),
        onTap: onTap,
        child: ConstrainedBox(
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
              Icon(
                elegida
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: elegida ? Theme.of(context).colorScheme.primary : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Resultado extends StatelessWidget {
  const _Resultado({
    required this.reserva,
    required this.parada,
    required this.onTerminar,
  });

  final Reserva reserva;

  /// La parada elegida; `null` solo si el widget se reconstruyó sin ella.
  final Parada? parada;
  final VoidCallback onTerminar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${reserva.sentido.etiqueta.toUpperCase()} · '
            '${fechaLegible(reserva.fecha)}',
            style: textTheme.labelSmall,
          ),
          Text(reserva.horario ?? 'Sin horario', style: textTheme.displayLarge),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Reserva ${reserva.estado.etiqueta.toLowerCase()}',
            key: const ValueKey('estado-reserva'),
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            parada == null
                ? 'Subís en la parada ${reserva.ordenParada}.'
                : 'Subís en ${parada!.titulo}.',
            key: const ValueKey('parada-reserva'),
          ),
          const Spacer(),
          ElevatedButton(
            key: const ValueKey('terminar-reserva'),
            onPressed: onTerminar,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.touchTarget),
            ),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }
}
