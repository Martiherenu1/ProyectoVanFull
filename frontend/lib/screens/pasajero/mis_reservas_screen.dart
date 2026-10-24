import 'package:flutter/material.dart';

import '../../core/format/fecha_legible.dart';
import '../../core/format/importe.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../models/pasajero/deuda.dart';
import '../../models/pasajero/reserva.dart';

/// El adaptador común deberá consultar GET /pasajeros/me/reservas.
typedef CargarReservas = Future<List<Reserva>> Function();

/// Consulta GET /pasajeros/me/deuda.
typedef CargarDeuda = Future<Deuda> Function();

/// POST /reservas/{id}/cancelacion. Ante un 409 con el cuerpo de error del
/// contrato, el adaptador lanza [ReservaRechazada]; cualquier otra falla se
/// lanza tal cual.
typedef CancelarReserva = Future<ResultadoCancelacion> Function(int idReserva);

/// CU-010 y CU-006, con la cancelación de CU-004. La pantalla no crea clientes
/// HTTP ni calcula el saldo ni decide qué se puede cancelar: lo rechaza el
/// backend y se muestra su motivo.
class MisReservasScreen extends StatefulWidget {
  const MisReservasScreen({
    super.key,
    required this.cargarReservas,
    required this.cargarDeuda,
    required this.cancelarReserva,
    required this.onBuscarServicio,
    this.onRegistrarPago,
  });

  final CargarReservas cargarReservas;
  final CargarDeuda cargarDeuda;
  final CancelarReserva cancelarReserva;

  /// Sin reservas, el pasajero sigue a Buscar servicio.
  final VoidCallback onBuscarServicio;

  /// Lleva a la pantalla de Pago con el saldo cargado. Sin él no hay botón.
  final ValueChanged<Deuda>? onRegistrarPago;

  @override
  State<MisReservasScreen> createState() => _MisReservasScreenState();
}

class _MisReservasScreenState extends State<MisReservasScreen> {
  List<Reserva> _reservas = const [];
  bool _cargandoReservas = true;
  bool _errorReservas = false;
  int _solicitudReservas = 0;

  Deuda? _deuda;
  bool _cargandoDeuda = true;
  bool _errorDeuda = false;
  int _solicitudDeuda = 0;

  int? _reservaAbierta;
  final Set<int> _cancelando = {};
  final Map<int, String> _avisos = {};
  final Map<int, String> _motivos = {};

  @override
  void initState() {
    super.initState();
    _cargarReservas();
    _cargarDeuda();
  }

  @override
  void didUpdateWidget(covariant MisReservasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cargarReservas != widget.cargarReservas) _cargarReservas();
    if (oldWidget.cargarDeuda != widget.cargarDeuda) _cargarDeuda();
  }

  Future<void> _cargarReservas() async {
    final solicitud = ++_solicitudReservas;
    setState(() {
      _cargandoReservas = true;
      _errorReservas = false;
      _reservaAbierta = null;
    });
    try {
      final reservas = await widget.cargarReservas();
      if (!mounted || solicitud != _solicitudReservas) return;
      setState(() {
        _reservas = List.unmodifiable(reservas);
        _cargandoReservas = false;
        _avisos.clear();
        _motivos.clear();
      });
    } catch (_) {
      if (!mounted || solicitud != _solicitudReservas) return;
      setState(() {
        _cargandoReservas = false;
        _errorReservas = true;
      });
    }
  }

  Future<void> _cargarDeuda() async {
    final solicitud = ++_solicitudDeuda;
    setState(() {
      _cargandoDeuda = true;
      _errorDeuda = false;
    });
    try {
      final deuda = await widget.cargarDeuda();
      if (!mounted || solicitud != _solicitudDeuda) return;
      setState(() {
        _deuda = deuda;
        _cargandoDeuda = false;
      });
    } catch (_) {
      if (!mounted || solicitud != _solicitudDeuda) return;
      setState(() {
        _cargandoDeuda = false;
        _errorDeuda = true;
      });
    }
  }

  Future<void> _cancelar(Reserva reserva) async {
    final confirmada = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar la reserva?'),
        content: Text(
          '${reserva.sentido.etiqueta} del ${fechaLegible(reserva.fecha)}'
          '${reserva.horario == null ? '' : ' a las ${reserva.horario}'}.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('conservar-reserva'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Conservar'),
          ),
          TextButton(
            key: const ValueKey('confirmar-cancelacion'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );
    if (confirmada != true || !mounted) return;

    final id = reserva.idReserva;
    setState(() {
      _cancelando.add(id);
      _avisos.remove(id);
    });
    try {
      final resultado = await widget.cancelarReserva(id);
      if (!mounted) return;
      setState(() {
        _cancelando.remove(id);
        _reservas = [
          for (final r in _reservas) r.idReserva == id ? resultado.reserva : r,
        ];
        _motivos[id] = resultado.motivo;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cancelando.remove(id);
        _avisos[id] = _avisoDeCancelacion(error);
      });
    }
  }

  String _avisoDeCancelacion(Object error) {
    if (error is ReservaRechazada) {
      return switch (error.codigo) {
        'RESERVA_NO_CANCELABLE' => 'Esta reserva ya estaba cancelada.',
        'VIAJE_NO_CANCELABLE' =>
          'El viaje ya no está programado: no se puede cancelar.',
        _ => error.mensaje,
      };
    }
    return 'No pudimos cancelar la reserva. Volvé a intentar.';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.passenger,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Mis reservas')),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _saldo(context),
                const SizedBox(height: AppSpacing.lg),
                Expanded(child: _contenido(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// El dato dominante de la pantalla: cuánto debe el pasajero, o «Al día».
  Widget _saldo(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final deuda = _deuda;
    final Widget dato;
    if (_cargandoDeuda) {
      dato = Text(
        '–',
        key: const ValueKey('saldo'),
        style: textTheme.displayLarge,
      );
    } else if (_errorDeuda || deuda == null) {
      dato = Row(
        children: [
          const Expanded(child: Text('No pudimos cargar tu saldo.')),
          TextButton(
            key: const ValueKey('reintentar-saldo'),
            onPressed: _cargarDeuda,
            child: const Text('Reintentar'),
          ),
        ],
      );
    } else if (deuda.estado == EstadoDeuda.alDia) {
      dato = Text(
        'Al día',
        key: const ValueKey('saldo'),
        style: textTheme.displayLarge,
      );
    } else {
      dato = Text(
        importeLegible(deuda.saldo),
        key: const ValueKey('saldo'),
        style: textTheme.displayLarge?.copyWith(color: AppColors.alertDark),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SALDO', style: textTheme.labelSmall),
          dato,
          if (widget.onRegistrarPago != null && deuda != null && !_errorDeuda)
            TextButton(
              key: const ValueKey('ir-a-pago'),
              onPressed: _cargandoDeuda
                  ? null
                  : () => widget.onRegistrarPago!(deuda),
              child: const Text('Registrar un pago'),
            ),
        ],
      ),
    );
  }

  Widget _contenido(BuildContext context) {
    if (_cargandoReservas) return const _Esqueleto();
    if (_errorReservas) {
      return _Mensaje(
        texto: 'No pudimos cargar tus reservas. Volvé a intentar.',
        accion: 'Reintentar',
        onAccion: _cargarReservas,
      );
    }
    if (_reservas.isEmpty) {
      return _Mensaje(
        texto: 'Todavía no tenés reservas.',
        accion: 'Buscar servicio',
        onAccion: widget.onBuscarServicio,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: _reservas.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final reserva = _reservas[index];
        final id = reserva.idReserva;
        final abierta = _reservaAbierta == id;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilaReserva(
              reserva: reserva,
              abierta: abierta,
              onTap: () =>
                  setState(() => _reservaAbierta = abierta ? null : id),
            ),
            if (_motivos[id] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  _motivos[id]!,
                  key: ValueKey('motivo-$id'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (abierta && reserva.estado != EstadoReserva.cancelada)
              _AccionCancelar(
                idReserva: id,
                cancelando: _cancelando.contains(id),
                aviso: _avisos[id],
                onCancelar: () => _cancelar(reserva),
              ),
          ],
        );
      },
    );
  }
}

class _FilaReserva extends StatelessWidget {
  const _FilaReserva({
    required this.reserva,
    required this.abierta,
    required this.onTap,
  });

  final Reserva reserva;
  final bool abierta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cancelada = reserva.estado == EstadoReserva.cancelada;
    return InkWell(
      key: ValueKey('reserva-${reserva.idReserva}'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSpacing.passengerRowHeight,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reserva.horario ?? 'Sin horario',
                    style: AppTypography.data,
                  ),
                  Text(
                    '${reserva.sentido.etiqueta} · '
                    '${fechaLegible(reserva.fecha)}',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              reserva.estado.etiqueta,
              style: AppTypography.data.copyWith(
                color: cancelada ? AppColors.alertDark : null,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(abierta ? Icons.expand_less : Icons.expand_more),
          ],
        ),
      ),
    );
  }
}

class _AccionCancelar extends StatelessWidget {
  const _AccionCancelar({
    required this.idReserva,
    required this.cancelando,
    required this.aviso,
    required this.onCancelar,
  });

  final int idReserva;
  final bool cancelando;
  final String? aviso;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (aviso != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                aviso!,
                key: ValueKey('aviso-$idReserva'),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.alertDark),
              ),
            ),
          OutlinedButton(
            key: ValueKey('cancelar-$idReserva'),
            onPressed: cancelando ? null : onCancelar,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.touchTarget),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
              ),
            ),
            child: Text(cancelando ? 'Cancelando…' : 'Cancelar reserva'),
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
      label: 'Cargando reservas',
      child: ExcludeSemantics(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          itemCount: 4,
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
