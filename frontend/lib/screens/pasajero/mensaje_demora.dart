import 'package:flutter/material.dart';

typedef CargarMensajeDemora = Future<String?> Function(int viaje);

/// Mensaje fechado del servidor. No interpreta eventos ni afirma demora activa.
class MensajeDemora extends StatefulWidget {
  const MensajeDemora({super.key, required this.viaje, required this.cargar});
  final int viaje;
  final CargarMensajeDemora cargar;
  @override
  State<MensajeDemora> createState() => _MensajeDemoraState();
}

class _MensajeDemoraState extends State<MensajeDemora> {
  String? _mensaje;
  bool _cargando = true;
  bool _error = false;
  int _version = 0;
  @override
  void initState() {
    super.initState();
    _leer();
  }

  @override
  void didUpdateWidget(covariant MensajeDemora oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viaje != widget.viaje || oldWidget.cargar != widget.cargar) {
      _leer();
    }
  }

  Future<void> _leer() async {
    final v = ++_version;
    setState(() {
      _mensaje = null;
      _cargando = true;
      _error = false;
    });
    try {
      final m = await widget.cargar(widget.viaje);
      if (mounted && v == _version) {
        setState(() {
          _mensaje = m;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted && v == _version) {
        setState(() {
          _mensaje = null;
          _cargando = false;
          _error = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _version++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_cargando)
        const Text('Consultando reportes de demora…')
      else if (_error) ...[
        const Text(
          'No pudimos consultar los reportes de demora. '
          'La situación actual no está confirmada.',
        ),
        TextButton(onPressed: _leer, child: const Text('Reintentar consulta')),
      ] else if (_mensaje == null)
        const Text('No hay reportes de demora para mostrar.')
      else ...[
        Text(_mensaje!),
        TextButton(
          onPressed: _leer,
          child: const Text('Actualizar reporte de demora'),
        ),
      ],
    ],
  );
}
