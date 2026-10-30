import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_spacing.dart';

/// Operación ya ligada a una sesión. No recibe identidad del pasajero.
typedef InformarAusencia = Future<void> Function(int idViaje);

/// Acción aislada para una reserva propia consolidada. El integrador debe
/// cambiar [alcance] con la sesión y proporcionar su guardia de vigencia.
/// Solo conserva feedback transitorio; no representa el estado persistido.
class AccionInformarAusencia extends StatefulWidget {
  const AccionInformarAusencia({
    super.key,
    required this.idViaje,
    required this.alcance,
    required this.contextoVigente,
    required this.informar,
  });

  final int idViaje;
  final Object alcance;
  final bool Function() contextoVigente;
  final InformarAusencia informar;

  @override
  State<AccionInformarAusencia> createState() => _AccionInformarAusenciaState();
}

class _AccionInformarAusenciaState extends State<AccionInformarAusencia> {
  bool _ocupado = false;
  String? _mensaje;
  int _version = 0;
  DialogRoute<bool>? _dialogo;

  void _retirarConfirmacion() {
    final dialogo = _dialogo;
    _dialogo = null;
    if (dialogo == null) return;
    // Retirar solo nuestra ruta, nunca hacer pop de una pantalla nueva.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (dialogo.isActive) dialogo.navigator?.removeRoute(dialogo);
    });
  }

  @override
  void dispose() {
    _retirarConfirmacion();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AccionInformarAusencia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.alcance, widget.alcance) ||
        oldWidget.idViaje != widget.idViaje) {
      _retirarConfirmacion();
      _version++;
      _ocupado = false;
      _mensaje = null;
    }
  }

  Future<void> _informar() async {
    if (_ocupado || !widget.contextoVigente()) return;
    final version = _version;
    final vigente = widget.contextoVigente;
    final informar = widget.informar;
    final viaje = widget.idViaje;
    bool actual() => mounted && version == _version && vigente();
    setState(() {
      _ocupado = true;
      _mensaje = null;
    });
    try {
      final dialogo = DialogRoute<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Informar ausencia?'),
          content: const Text(
            'Al informar tu ausencia se libera tu lugar. Tu reserva no se '
            'cancela. Recuperar el lugar no está incluido en esta acción.',
          ),
          actions: [
            TextButton(
              key: const ValueKey('no-informar-ausencia'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Volver'),
            ),
            TextButton(
              key: const ValueKey('confirmar-ausencia'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Informar ausencia'),
            ),
          ],
        ),
      );
      _dialogo = dialogo;
      final confirmada = await Navigator.of(
        context,
        rootNavigator: true,
      ).push(dialogo);
      if (identical(_dialogo, dialogo)) _dialogo = null;
      if (!actual() || confirmada != true) return;
      await informar(viaje);
      if (!actual()) return;
      setState(() => _mensaje = 'Tu aviso de ausencia está registrado.');
    } catch (error) {
      if (!actual()) return;
      setState(() {
        _mensaje =
            error is ApiException &&
                const [400, 401, 403, 404, 409].contains(error.statusCode)
            ? error.mensaje
            : 'No pudimos confirmar si el aviso quedó registrado. '
                  'Podés volver a informar la ausencia: si ya existe, '
                  'no se duplicará.';
      });
    } finally {
      if (actual()) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_mensaje != null)
        Text(_mensaje!, key: const ValueKey('resultado-ausencia')),
      OutlinedButton(
        key: const ValueKey('informar-ausencia'),
        onPressed: _ocupado || !widget.contextoVigente() ? null : _informar,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.touchTarget),
        ),
        child: Text(_ocupado ? 'Procesando…' : 'Informar ausencia'),
      ),
    ],
  );
}
