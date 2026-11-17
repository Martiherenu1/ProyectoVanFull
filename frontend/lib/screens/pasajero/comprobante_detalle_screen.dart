import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/format/fecha_legible.dart';
import '../../core/format/importe.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/pasajero/comprobante_propio.dart';

/// Consulta GET /pasajeros/me/comprobantes/{id_comprobante}.
typedef CargarComprobante = Future<ComprobantePropio> Function(
  int idComprobante,
);

/// Detalle de un comprobante propio (CU-035). Muestra solo lo que el origen
/// tiene: la tabla no guarda número, fecha de emisión ni datos fiscales, así que
/// no se presentan. Un comprobante ajeno o inexistente llega como el mismo 404
/// (A2) y se dice sin confirmar cuál de los dos es.
class ComprobanteDetalleScreen extends StatefulWidget {
  const ComprobanteDetalleScreen({
    super.key,
    required this.idComprobante,
    required this.cargarComprobante,
  });

  final int idComprobante;
  final CargarComprobante cargarComprobante;

  @override
  State<ComprobanteDetalleScreen> createState() =>
      _ComprobanteDetalleScreenState();
}

class _ComprobanteDetalleScreenState extends State<ComprobanteDetalleScreen> {
  ComprobantePropio? _comprobante;
  bool _cargando = true;
  bool _noDisponible = false;
  bool _error = false;
  int _solicitud = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant ComprobanteDetalleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idComprobante != widget.idComprobante ||
        oldWidget.cargarComprobante != widget.cargarComprobante) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    final solicitud = ++_solicitud;
    setState(() {
      _cargando = true;
      _noDisponible = false;
      _error = false;
    });
    try {
      final comprobante = await widget.cargarComprobante(widget.idComprobante);
      if (!mounted || solicitud != _solicitud) return;
      setState(() {
        _comprobante = comprobante;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted || solicitud != _solicitud) return;
      setState(() {
        _cargando = false;
        _noDisponible =
            error is ApiException &&
            error.statusCode == 404 &&
            error.codigo == 'COMPROBANTE_NO_ENCONTRADO';
        _error = !_noDisponible;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.passenger,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Comprobante')),
          body: SafeArea(child: _contenido(context)),
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context) {
    if (_cargando) return const _Esqueleto();
    if (_noDisponible) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Este comprobante no está disponible.',
          key: ValueKey('comprobante-no-disponible'),
        ),
      );
    }
    if (_error) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No pudimos cargar el comprobante. Volvé a intentar.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.alertDark),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              key: const ValueKey('reintentar-comprobante'),
              onPressed: _cargar,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.touchTarget),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    return _detalle(context, _comprobante!);
  }

  Widget _detalle(BuildContext context, ComprobantePropio comprobante) {
    final textTheme = Theme.of(context).textTheme;
    final fecha = comprobante.fechaHora;
    final importe = comprobante.importe;
    final medio = comprobante.medioPagoLegible;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          comprobante.tipo.etiqueta.toUpperCase(),
          style: textTheme.labelSmall,
        ),
        Text(
          importe == null ? 'Sin importe' : importeLegible(importe),
          key: const ValueKey('importe-comprobante'),
          style: textTheme.displayLarge,
        ),
        const SizedBox(height: AppSpacing.xl),
        _dato(
          context,
          'FECHA',
          fecha == null ? 'Sin fecha' : fechaHoraLegible(fecha),
          'fecha-comprobante',
        ),
        if (medio != null)
          _dato(context, 'MEDIO DE PAGO', medio, 'medio-comprobante'),
        _dato(context, 'ORIGEN', _origen(comprobante), 'origen-comprobante'),
        _dato(
          context,
          'REFERENCIA',
          '${comprobante.idComprobante}',
          'referencia-comprobante',
        ),
      ],
    );
  }

  /// El origen es el que el contrato informa; no se deduce del tipo.
  String _origen(ComprobantePropio comprobante) {
    if (comprobante.idPago != null) return 'Pago N.º ${comprobante.idPago}';
    if (comprobante.idContratacion != null) {
      return 'Contratación N.º ${comprobante.idContratacion}';
    }
    if (comprobante.idMovimientoCuenta != null) {
      return 'Movimiento de cuenta N.º ${comprobante.idMovimientoCuenta}';
    }
    return 'Sin origen informado';
  }

  Widget _dato(
    BuildContext context,
    String etiqueta,
    String valor,
    String clave,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: textTheme.labelSmall),
          Text(valor, key: ValueKey(clave), style: textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// Barras con la forma del detalle mientras carga (brief §8).
class _Esqueleto extends StatelessWidget {
  const _Esqueleto();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    Widget barra(double ancho, double alto) => ColoredBox(
      color: color,
      child: SizedBox(width: ancho, height: alto),
    );
    return Semantics(
      label: 'Cargando el comprobante',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              barra(72, 12),
              const SizedBox(height: AppSpacing.sm),
              barra(180, 40),
              const SizedBox(height: AppSpacing.xl),
              for (var i = 0; i < 3; i++) ...[
                barra(96, 12),
                const SizedBox(height: AppSpacing.xs),
                barra(160, 16),
                const SizedBox(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
