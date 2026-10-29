import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/format/importe.dart';
import '../../models/admin/pago_admin.dart';
import '../../models/pasajero/pago.dart';
import '../../services/admin/pagos_admin_api.dart';

class PagosPendientesScreen extends StatefulWidget {
  const PagosPendientesScreen({
    super.key,
    required this.cargar,
    required this.decidir,
  });
  final Future<List<PagoAdmin>> Function() cargar;
  final Future<PagoAdmin> Function(int, DecisionPago) decidir;
  @override
  State<PagosPendientesScreen> createState() => _PagosPendientesScreenState();
}

class _PagosPendientesScreenState extends State<PagosPendientesScreen> {
  List<PagoAdmin> _pagos = [];
  bool _cargando = true;
  bool _decidiendo = false;
  String? _error;
  String? _resultado;
  int _solicitud = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant PagosPendientesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cargar != widget.cargar ||
        oldWidget.decidir != widget.decidir) {
      _decidiendo = false;
      _resultado = null;
      _cargar();
    }
  }

  String _mensaje(Object e) => e is ApiException
      ? e.mensaje
      : 'No pudimos completar la operación. Volvé a intentar.';

  Future<void> _cargar() async {
    final solicitud = ++_solicitud;
    setState(() {
      _cargando = true;
      _error = null;
      _pagos = [];
    });
    try {
      final pagos = await widget.cargar();
      if (!mounted || solicitud != _solicitud) return;
      setState(() {
        _pagos = pagos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted || solicitud != _solicitud) return;
      setState(() {
        _error = _mensaje(e);
        _cargando = false;
      });
    }
  }

  Future<void> _decidir(PagoAdmin pago, DecisionPago decision) async {
    if (_decidiendo || _cargando) return;
    final solicitud = _solicitud;
    final enviar = widget.decidir;
    setState(() {
      _decidiendo = true;
      _error = null;
      _resultado = null;
    });
    final accion = decision == DecisionPago.confirmar
        ? 'Confirmar'
        : 'Rechazar';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$accion pago ${pago.idPago}'),
        content: Text(
          'Cliente ${pago.idCliente} · ${importeLegible(pago.importe)}\n¿Deseás continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            key: const Key('confirmar-decision-pago'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(accion),
          ),
        ],
      ),
    );
    if (!mounted || solicitud != _solicitud) return;
    if (ok != true) {
      setState(() => _decidiendo = false);
      return;
    }
    try {
      final actualizado = await enviar(pago.idPago, decision);
      if (!mounted || solicitud != _solicitud) return;
      setState(() {
        _resultado =
            'Pago ${actualizado.idPago}: ${actualizado.estado.etiqueta}.';
      });
      await _cargar();
    } catch (e) {
      if (!mounted || solicitud != _solicitud) return;
      setState(() => _error = _mensaje(e));
    } finally {
      if (mounted && widget.decidir == enviar) {
        setState(() => _decidiendo = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pagos pendientes'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _cargando || _decidiendo ? null : _cargar,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_error!, key: const Key('error-pagos')),
          ),
        if (_resultado != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(_resultado!)),
        if (_cargando)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  TextButton(
                    onPressed: _decidiendo ? null : _cargar,
                    child: const Text('Reintentar'),
                  ),
                if (_pagos.isEmpty && _error == null)
                  const Text('No hay pagos pendientes.'),
                for (final pago in _pagos)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pago ${pago.idPago} · Cliente ${pago.idCliente}',
                          ),
                          Text(
                            '${importeLegible(pago.importe)} · ${pago.medioPago}',
                          ),
                          Text('Fecha: ${pago.fechaHora.toLocal()}'),
                          Text('Estado: ${pago.estado.etiqueta}'),
                          if (pago.estado == EstadoPago.pendiente)
                            Wrap(
                              spacing: 12,
                              children: [
                                FilledButton(
                                  key: ValueKey(
                                    'confirmar-pago-${pago.idPago}',
                                  ),
                                  onPressed: _decidiendo
                                      ? null
                                      : () => _decidir(
                                          pago,
                                          DecisionPago.confirmar,
                                        ),
                                  child: const Text('Confirmar'),
                                ),
                                OutlinedButton(
                                  key: ValueKey('rechazar-pago-${pago.idPago}'),
                                  onPressed: _decidiendo
                                      ? null
                                      : () => _decidir(
                                          pago,
                                          DecisionPago.rechazar,
                                        ),
                                  child: const Text('Rechazar'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}
