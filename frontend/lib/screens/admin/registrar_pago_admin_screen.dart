import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/format/importe.dart';
import '../../models/pasajero/pago.dart';

typedef RegistrarPagoAdmin = Future<Pago> Function({
  required int idCliente,
  required double importe,
  required MedioPago medio,
});

class RegistrarPagoAdminScreen extends StatefulWidget {
  const RegistrarPagoAdminScreen({super.key, required this.registrar});
  final RegistrarPagoAdmin registrar;
  @override
  State<RegistrarPagoAdminScreen> createState() =>
      _RegistrarPagoAdminScreenState();
}

class _RegistrarPagoAdminScreenState extends State<RegistrarPagoAdminScreen> {
  final _cliente = TextEditingController();
  final _importe = TextEditingController();
  MedioPago? _medio;
  bool _enviando = false;
  String? _error;
  Pago? _pago;
  int? _destinatario;
  @override
  void dispose() {
    _cliente.dispose();
    _importe.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (_enviando || _pago != null) return;
    final cliente = int.tryParse(_cliente.text.trim());
    final importe = leerImporte(_importe.text);
    final medio = _medio;
    if (cliente == null ||
        cliente <= 0 ||
        importe == null ||
        !importe.isFinite ||
        importe < 0 ||
        medio == null) {
      setState(
        () => _error = 'Indicá un cliente válido, importe y medio de pago.',
      );
      return;
    }
    final registrar = widget.registrar;
    setState(() {
      _enviando = true;
      _error = null;
    });
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar pago'),
        content: Text(
          'Cliente $cliente\n${importeLegible(importe)} · ${medio.etiqueta}\nEl registro no confirma el pago.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            key: const Key('confirmar-registro-pago'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok != true) {
      setState(() => _enviando = false);
      return;
    }
    try {
      final pago = await registrar(
        idCliente: cliente,
        importe: importe,
        medio: medio,
      );
      if (!mounted || widget.registrar != registrar) return;
      setState(() {
        _pago = pago;
        _destinatario = cliente;
        _enviando = false;
      });
    } catch (e) {
      if (!mounted || widget.registrar != registrar) return;
      setState(() {
        _enviando = false;
        _error = e is ApiException ? e.mensaje : 'No pudimos registrar el pago. Verificá su estado antes de reintentar.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Registrar pago')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_pago case final pago?) ...[
            Text(
              'Pago ${pago.idPago} registrado para el cliente $_destinatario.',
            ),
            Text('Estado: ${pago.estado.etiqueta}'),
            Text('Importe registrado: ${importeLegible(pago.importe)}'),
            const Text(
              'La confirmación o rechazo se realiza por el circuito de validación de pagos.',
            ),
          ] else ...[
            const Text(
              'Registro parcial para transferencia o billetera. Requiere un cliente con cuenta corriente existente.',
            ),
            const Text(
              'Efectivo, señas/acuerdos especiales y respaldo aún no disponibles en este registro.',
            ),
            TextField(
              key: const Key('pago-id-cliente'),
              controller: _cliente,
              enabled: !_enviando,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ID del cliente destinatario',
              ),
            ),
            TextField(
              key: const Key('pago-importe'),
              controller: _importe,
              enabled: !_enviando,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Importe recibido'),
            ),
            DropdownButtonFormField<MedioPago>(
              key: const Key('pago-medio'),
              decoration: const InputDecoration(labelText: 'Medio de pago'),
              items: [
                for (final medio in [
                  MedioPago.transferencia,
                  MedioPago.billetera,
                ])
                  DropdownMenuItem(value: medio, child: Text(medio.etiqueta)),
              ],
              onChanged: _enviando
                  ? null
                  : (medio) => setState(() => _medio = medio),
            ),
            if (_error != null)
              Text(_error!, key: const Key('error-registro-pago')),
            FilledButton(
              key: const Key('registrar-pago-admin'),
              onPressed: _enviando ? null : _registrar,
              child: Text(_enviando ? 'Registrando…' : 'Registrar pago'),
            ),
          ],
        ],
      ),
    ),
  );
}
