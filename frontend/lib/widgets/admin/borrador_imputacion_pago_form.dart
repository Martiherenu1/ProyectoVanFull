import 'package:flutter/material.dart';

import '../../models/admin/borrador_imputacion_pago.dart';

/// Formulario aislado, no montado en el registro real hasta resolver #84.
class BorradorImputacionPagoForm extends StatefulWidget {
  const BorradorImputacionPagoForm({super.key, required this.onChanged});
  final ValueChanged<BorradorImputacionPago> onChanged;
  @override
  State<BorradorImputacionPagoForm> createState() =>
      _BorradorImputacionPagoFormState();
}

class _BorradorImputacionPagoFormState
    extends State<BorradorImputacionPagoForm> {
  TipoPagoBorrador? _tipo;
  String _evidencia = '';
  void _informar() => widget.onChanged(
    BorradorImputacionPago(tipo: _tipo, evidencia: _evidencia),
  );
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('Borrador local: tipo y respaldo no se envían ni se guardan.'),
      DropdownButtonFormField<TipoPagoBorrador>(
        decoration: const InputDecoration(labelText: 'Tipo de pago'),
        items: [
          for (final tipo in TipoPagoBorrador.values)
            DropdownMenuItem(value: tipo, child: Text(tipo.etiqueta)),
        ],
        onChanged: (tipo) {
          setState(() => _tipo = tipo);
          _informar();
        },
      ),
      TextFormField(
        decoration: const InputDecoration(labelText: 'Referencia del respaldo'),
        onChanged: (valor) {
          _evidencia = valor;
          _informar();
        },
      ),
    ],
  );
}
