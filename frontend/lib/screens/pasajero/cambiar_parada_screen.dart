import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/format/fecha_legible.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../models/pasajero/parada.dart';
import '../../models/pasajero/reserva.dart';
import 'buscar_servicio_screen.dart' show CargarParadas;

/// POST /reservas/{id}/cambio-parada con `orden_parada`. Ante un 400 o 409 con
/// el cuerpo de error del contrato el adaptador lanza [ReservaRechazada]; el
/// 404 y cualquier otra falla (red, 5xx) se lanzan tal cual.
typedef CambiarParada = Future<Reserva> Function(
  int idReserva,
  int ordenParada,
);

/// CU-005. La pantalla no crea clientes HTTP ni decide si hay «disponibilidad
/// compatible» (RN-020): lo rechaza el backend y se muestra su motivo. Si el
/// cambio no procede, la parada original se conserva (A1) y así se le dice.
class CambiarParadaScreen extends StatefulWidget {
  const CambiarParadaScreen({
    super.key,
    required this.reserva,
    required this.cargarParadas,
    required this.cambiarParada,
    required this.onTerminar,
  });

  /// La reserva propia cuya parada se cambia.
  final Reserva reserva;
  final CargarParadas cargarParadas;
  final CambiarParada cambiarParada;

  /// El pasajero vio el cambio confirmado y sigue con la app.
  final ValueChanged<Reserva> onTerminar;

  @override
  State<CambiarParadaScreen> createState() => _CambiarParadaScreenState();
}

class _CambiarParadaScreenState extends State<CambiarParadaScreen> {
  late Future<List<Parada>> _paradas;
  Parada? _paradaElegida;
  bool _enviando = false;
  _Aviso? _aviso;
  Reserva? _resultado;

  @override
  void initState() {
    super.initState();
    _paradas = _pedirParadas();
  }

  @override
  void didUpdateWidget(covariant CambiarParadaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cargarParadas != widget.cargarParadas ||
        oldWidget.reserva.idRecorrido != widget.reserva.idRecorrido) {
      _paradaElegida = null;
      _paradas = _pedirParadas();
    }
  }

  Future<List<Parada>> _pedirParadas() {
    final paradas = widget.cargarParadas(widget.reserva.idRecorrido);
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
      final reserva = await widget.cambiarParada(
        widget.reserva.idReserva,
        orden,
      );
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _resultado = reserva;
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
    if (error is ReservaRechazada) {
      return switch (error.codigo) {
        'PARADA_NO_VALIDA' => const _Aviso(
          'Esa parada no pertenece al recorrido de tu viaje. '
          'Tu parada no cambió: elegí otra.',
        ),
        'PARADA_SIN_CAMBIOS' => const _Aviso(
          'Ya subís en esa parada. Elegí otra.',
        ),
        'RESERVA_NO_MODIFICABLE' => const _Aviso(
          'Esta reserva está cancelada: no se puede cambiar la parada.',
          definitivo: true,
        ),
        'VIAJE_NO_MODIFICABLE' => const _Aviso(
          'El viaje ya no está programado: no se puede cambiar la parada. '
          'Tu parada no cambió.',
          definitivo: true,
        ),
        _ => _Aviso(error.mensaje),
      };
    }
    if (error is ApiException && error.statusCode == 404) {
      return const _Aviso(
        'No encontramos esta reserva. Volvé a Mis reservas.',
        definitivo: true,
      );
    }
    // Sin respuesta del servidor no sabemos si el cambio se aplicó: si se
    // reintenta y ya estaba aplicado, el backend contesta PARADA_SIN_CAMBIOS.
    return const _Aviso(
      'No pudimos confirmar el cambio. Revisá Mis reservas o volvé a intentar.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.passenger,
      child: Builder(
        builder: (context) {
          final resultado = _resultado;
          return Scaffold(
            appBar: AppBar(
              title: Text(
                resultado == null ? 'Cambiar parada' : 'Parada cambiada',
              ),
              automaticallyImplyLeading: resultado == null,
            ),
            body: SafeArea(
              child: resultado == null
                  ? _formulario(context)
                  : _Resultado(
                      reserva: resultado,
                      parada: _paradaElegida,
                      onTerminar: () => widget.onTerminar(resultado),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _formulario(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reserva = widget.reserva;
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
                '${reserva.sentido.etiqueta.toUpperCase()} · '
                '${fechaLegible(reserva.fecha)}',
                style: textTheme.labelSmall,
              ),
              Text(
                reserva.horario ?? 'Sin horario',
                key: const ValueKey('horario-reserva'),
                style: textTheme.displayLarge,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('¿DÓNDE SUBÍS AHORA?', style: textTheme.labelSmall),
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
                        _FilaParada(
                          parada: parada,
                          actual: parada.orden == reserva.ordenParada,
                          elegida: parada.orden == _paradaElegida?.orden,
                          onTap: _enviando || bloqueado
                              ? null
                              : () => setState(() {
                                  _paradaElegida = parada;
                                  _aviso = null;
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
              key: const ValueKey('aviso-cambio-parada'),
              style: textTheme.bodyMedium?.copyWith(color: AppColors.alertDark),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ElevatedButton(
            key: const ValueKey('confirmar-cambio-parada'),
            onPressed: _paradaElegida == null || _enviando || bloqueado
                ? null
                : _confirmar,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.touchTarget),
            ),
            child: Text(
              _enviando
                  ? 'Cambiando…'
                  : _paradaElegida == null
                  ? 'Elegí la nueva parada'
                  : 'Cambiar parada',
            ),
          ),
        ),
      ],
    );
  }
}

/// Texto de un rechazo. `definitivo`: reintentar no cambia el resultado, así
/// que se bloquea el botón.
class _Aviso {
  const _Aviso(this.texto, {this.definitivo = false});

  final String texto;
  final bool definitivo;
}

class _FilaParada extends StatelessWidget {
  const _FilaParada({
    required this.parada,
    required this.actual,
    required this.elegida,
    required this.onTap,
  });

  final Parada parada;

  /// La parada que la reserva ya tiene: se muestra pero no se puede elegir.
  final bool actual;
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
        onTap: actual ? null : onTap,
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
              if (actual)
                Text(
                  'Tu parada actual',
                  key: const ValueKey('parada-actual'),
                  style: textTheme.bodySmall,
                )
              else
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
            'Cambiaste tu parada',
            key: const ValueKey('estado-cambio-parada'),
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            parada == null
                ? 'Ahora subís en la parada ${reserva.ordenParada}.'
                : 'Ahora subís en ${parada!.titulo}.',
            key: const ValueKey('parada-nueva'),
          ),
          const Spacer(),
          ElevatedButton(
            key: const ValueKey('terminar-cambio-parada'),
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
