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
    });
    try {
      final m = await widget.cargar(widget.viaje);
      if (mounted && v == _version) {
        setState(() {
          _mensaje = m;
        });
      }
    } catch (_) {
      if (mounted && v == _version) {
        setState(() {
          _mensaje = null;
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
      if (_mensaje != null) Text(_mensaje!),
      TextButton(
        onPressed: _leer,
        child: const Text('Actualizar información del viaje'),
      ),
    ],
  );
}
