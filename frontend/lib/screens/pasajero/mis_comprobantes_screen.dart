import 'package:flutter/material.dart';

import '../../core/format/fecha_legible.dart';
import '../../core/format/importe.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../models/pasajero/comprobante_propio.dart';

/// Consulta GET /pasajeros/me/comprobantes.
typedef CargarComprobantes = Future<List<ComprobantePropio>> Function();

/// CU-035 (consulta). La pantalla no filtra qué comprobantes son del pasajero
/// ni inventa lo que el origen no tiene (RN-028): lo decide el backend. La
/// descarga y los comprobantes de la organización no existen todavía.
class MisComprobantesScreen extends StatefulWidget {
  const MisComprobantesScreen({
    super.key,
    required this.cargarComprobantes,
    required this.onAbrir,
  });

  final CargarComprobantes cargarComprobantes;

  /// Abre el detalle de un comprobante (GET /pasajeros/me/comprobantes/{id}).
  final ValueChanged<ComprobantePropio> onAbrir;

  @override
  State<MisComprobantesScreen> createState() => _MisComprobantesScreenState();
}

class _MisComprobantesScreenState extends State<MisComprobantesScreen> {
  List<ComprobantePropio> _comprobantes = const [];
  bool _cargando = true;
  bool _error = false;
  int _solicitud = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant MisComprobantesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cargarComprobantes != widget.cargarComprobantes) _cargar();
  }

  Future<void> _cargar() async {
    final solicitud = ++_solicitud;
    setState(() {
      _cargando = true;
      _error = false;
    });
    try {
      final comprobantes = await widget.cargarComprobantes();
      if (!mounted || solicitud != _solicitud) return;
      setState(() {
        _comprobantes = List.unmodifiable(comprobantes);
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
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.passenger,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Mis comprobantes')),
          body: SafeArea(child: _contenido(context)),
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context) {
    if (_cargando) return const _Esqueleto();
    if (_error) {
      return _Mensaje(
        texto: 'No pudimos cargar tus comprobantes. Volvé a intentar.',
        accion: 'Reintentar',
        onAccion: _cargar,
      );
    }
    if (_comprobantes.isEmpty) {
      return _Mensaje(
        texto:
            'Todavía no tenés comprobantes. '
            'Cuando se emita uno, lo vas a ver acá.',
        accion: 'Actualizar',
        onAccion: _cargar,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: _comprobantes.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) => _FilaComprobante(
        comprobante: _comprobantes[index],
        onTap: () => widget.onAbrir(_comprobantes[index]),
      ),
    );
  }
}

class _FilaComprobante extends StatelessWidget {
  const _FilaComprobante({required this.comprobante, required this.onTap});

  final ComprobantePropio comprobante;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fecha = comprobante.fechaHora;
    final medio = comprobante.medioPagoLegible;
    final importe = comprobante.importe;
    return InkWell(
      key: ValueKey('comprobante-${comprobante.idComprobante}'),
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
                  Text(comprobante.tipo.etiqueta, style: AppTypography.data),
                  Text(
                    [
                      fecha == null ? 'Sin fecha' : fechaHoraLegible(fecha),
                      ?medio,
                    ].join(' · '),
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              importe == null ? 'Sin importe' : importeLegible(importe),
              style: AppTypography.data,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right),
          ],
        ),
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
      label: 'Cargando comprobantes',
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
                  child: const SizedBox(width: 72, height: 14),
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
            key: const ValueKey('accion-comprobantes'),
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
