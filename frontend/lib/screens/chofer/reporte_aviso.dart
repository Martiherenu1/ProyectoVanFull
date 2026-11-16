import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/chofer/avisos_api.dart';

typedef RegistrarAviso = Future<int> Function(
  int viaje,
  String clave,
  String clase,
  String detalle,
);
typedef RecuperarAviso = Future<int> Function(int viaje, String clave);

/// Correlación temporal; pertenece al shell de una única sesión, nunca global.
class ReferenciaAviso {
  const ReferenciaAviso(this.viaje, String clave) : _clave = clave;
  final int viaje;
  final String _clave;
  // Una representación para conservar, comparar y retirar la referencia.
  String get clave => _clave.trim().toLowerCase();
}

class ReporteAviso extends StatefulWidget {
  const ReporteAviso({
    super.key,
    required this.viaje,
    required this.registrar,
    required this.recuperar,
    this.onIncierto,
    this.onConfirmado,
  });
  final int viaje;
  final RegistrarAviso registrar;
  final RecuperarAviso recuperar;
  final ValueChanged<ReferenciaAviso>? onIncierto;
  final ValueChanged<ReferenciaAviso>? onConfirmado;
  @override
  State<ReporteAviso> createState() => _ReporteAvisoState();
}

class _ReporteAvisoState extends State<ReporteAviso> {
  final _texto = TextEditingController();
  String _clase = 'demora';
  String? _clave;
  String _mensaje = '';
  bool _ocupado = false, _incierto = false;
  int _generacion = 0;

  String _nuevaClave() {
    final r = Random.secure();
    final bytes = List.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  @override
  void didUpdateWidget(covariant ReporteAviso oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viaje != widget.viaje) {
      _generacion++;
      _clave = null;
      _incierto = false;
      _ocupado = false;
      _mensaje = '';
      _texto.clear();
    }
  }

  Future<void> _enviar(bool consultar) async {
    if (_ocupado || (!consultar && _texto.text.trim().isEmpty)) return;
    _clave ??= _nuevaClave();
    final g = _generacion;
    final teniaIncertidumbre = _incierto;
    setState(() {
      _ocupado = true;
    });
    try {
      final id = consultar
          ? await widget.recuperar(widget.viaje, _clave!)
          : await widget.registrar(
              widget.viaje,
              _clave!,
              _clase,
              _texto.text.trim(),
            );
      if (!mounted || g != _generacion) return;
      widget.onConfirmado?.call(ReferenciaAviso(widget.viaje, _clave!));
      setState(() {
        _mensaje = 'Aviso registrado (#$id). Comunicación no evaluada.';
        _incierto = false;
        _clave = null;
        _texto.clear();
      });
    } catch (e) {
      if (!mounted || g != _generacion) return;
      setState(() {
        _incierto = consultar || teniaIncertidumbre || e is! AvisoRechazado;
        _mensaje = _incierto
            ? 'No pudimos confirmar el resultado. Podés consultar o volver al viaje sin confirmar.'
            : 'El registro fue rechazado. Revisá el viaje o tu sesión.';
        if (!_incierto) _clave = null;
      });
      if (_incierto) {
        widget.onIncierto?.call(ReferenciaAviso(widget.viaje, _clave!));
      }
    } finally {
      if (mounted && g == _generacion) {
        setState(() {
          _ocupado = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _generacion++;
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Informar demora o problema'),
        DropdownButton<String>(
          itemHeight: 64,
          isExpanded: true,
          value: _clase,
          items: const [
            DropdownMenuItem(value: 'demora', child: Text('Demora relevante')),
            DropdownMenuItem(
              value: 'problema',
              child: Text('Problema interno'),
            ),
          ],
          onChanged: _ocupado || _incierto
              ? null
              : (v) => setState(() {
                  _clase = v!;
                }),
        ),
        TextField(
          controller: _texto,
          enabled: !_ocupado && !_incierto,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Descripción interna para la empresa',
          ),
        ),
        if (_clave != null)
          SelectableText('Viaje ${widget.viaje}. Clave: $_clave'),
        if (_mensaje.isNotEmpty) Text(_mensaje),
        if (_ocupado) const LinearProgressIndicator(),
        if (_incierto) ...[
          const Text(
            'El resultado sigue sin confirmar. Salir no cancela ni rechaza el aviso. '
            'Viaje y clave se conservan durante esta sesión para consultar después '
            'en «Resultado propio».',
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 64)),
            onPressed: _ocupado ? null : () => Navigator.of(context).maybePop(),
            child: const Text('Volver al viaje sin confirmar'),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 64)),
            onPressed: _ocupado ? null : () => _enviar(true),
            child: const Text('Consultar resultado'),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 64)),
            onPressed: _ocupado ? null : () => _enviar(false),
            child: const Text('Repetir el mismo reporte'),
          ),
        ] else
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(64, 64)),
            onPressed: _ocupado ? null : () => _enviar(false),
            child: const Text('Registrar aviso'),
          ),
      ],
    ),
  );
}
