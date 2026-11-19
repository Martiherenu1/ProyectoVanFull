import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../models/pasajero/parada.dart';

class DescensosViajeDialog extends StatefulWidget {
  const DescensosViajeDialog({
    super.key,
    required this.paradas,
    required this.iniciales,
    required this.guardar,
  });

  final List<Parada> paradas;
  final Set<int> iniciales;
  final Future<void> Function(Set<int>) guardar;

  @override
  State<DescensosViajeDialog> createState() => _DescensosViajeDialogState();
}

class _DescensosViajeDialogState extends State<DescensosViajeDialog> {
  late final Set<int> _elegidas = {...widget.iniciales};
  bool _guardando = false;
  String? _error;

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.guardar(Set.unmodifiable(_elegidas));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = error is ApiException ? error.mensaje : 'No se pudo guardar.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Descensos habilitados'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final parada in widget.paradas)
            CheckboxListTile(
              title: Text(parada.titulo),
              value: _elegidas.contains(parada.orden),
              onChanged: _guardando ? null : (activa) {
                setState(() {
                  if (activa == true) {
                    _elegidas.add(parada.orden);
                  } else {
                    _elegidas.remove(parada.orden);
                  }
                });
              },
            ),
          if (_error case final error?) Text(error),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _guardando ? null : () => Navigator.of(context).pop(),
        child: const Text('Cerrar'),
      ),
      FilledButton(
        onPressed: _guardando ? null : _guardar,
        child: Text(_guardando ? 'Guardando…' : 'Guardar'),
      ),
    ],
  );
}
