import 'package:flutter/material.dart';

import 'reporte_aviso.dart';

/// Recuperación por autor: independiente del listado/asignación vigente.
class RecuperarAvisoScreen extends StatefulWidget {
  const RecuperarAvisoScreen({
    super.key,
    required this.recuperar,
    this.referencias = const [],
    this.onConfirmado,
  });
  final RecuperarAviso recuperar;
  final List<ReferenciaAviso> referencias;
  final ValueChanged<ReferenciaAviso>? onConfirmado;
  @override
  State<RecuperarAvisoScreen> createState() => _RecuperarAvisoScreenState();
}

class _RecuperarAvisoScreenState extends State<RecuperarAvisoScreen> {
  final _viaje = TextEditingController(), _clave = TextEditingController();
  bool _ocupado = false;
  String _mensaje = '';
  @override
  void dispose() {
    _viaje.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final id = int.tryParse(_viaje.text);
    final clave = _clave.text.trim().toLowerCase();
    if (_ocupado || id == null || id <= 0 || clave.isEmpty) return;
    setState(() {
      _ocupado = true;
      _mensaje = '';
    });
    try {
      final aviso = await widget.recuperar(id, clave);
      if (mounted) {
        setState(() {
          _mensaje = 'Aviso registrado (#$aviso).';
        });
        widget.onConfirmado?.call(ReferenciaAviso(id, clave));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _mensaje = 'Resultado no disponible. No demuestra que el reporte haya sido rechazado.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _ocupado = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recuperar resultado propio')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final referencia in widget.referencias)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, 64)),
              onPressed: _ocupado
                  ? null
                  : () {
                      setState(() {
                        _viaje.text = '${referencia.viaje}';
                        _clave.text = referencia.clave;
                        _mensaje = 'El resultado sigue sin confirmar. Consultar no reenvía el reporte.';
                      });
                    },
              child: Text(
                'Recuperar aviso sin confirmar del viaje ${referencia.viaje}',
              ),
            ),
          TextField(
            controller: _viaje,
            enabled: !_ocupado,
            decoration: const InputDecoration(labelText: 'Número de viaje'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _clave,
            enabled: !_ocupado,
            decoration: const InputDecoration(labelText: 'Clave de solicitud'),
          ),
          Text(_mensaje),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(64, 64)),
            onPressed: _ocupado ? null : _buscar,
            child: const Text('Consultar resultado'),
          ),
        ],
      ),
    ),
  );
}
