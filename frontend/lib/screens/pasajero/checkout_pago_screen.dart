import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/format/importe.dart';
import '../../models/pasajero/pago.dart';
import '../../services/checkout_api.dart';

class CheckoutPagoScreen extends StatefulWidget {
  const CheckoutPagoScreen({
    super.key,
    required this.importe,
    required this.clave,
    required this.iniciar,
    required this.consultar,
    required this.abrir,
    required this.contextoVigente,
  });
  final double importe;
  final String clave;
  final IniciarCheckout iniciar;
  final ConsultarPagoPropio consultar;
  final AbrirCheckout abrir;
  final bool Function() contextoVigente;
  @override
  State<CheckoutPagoScreen> createState() => _CheckoutPagoScreenState();
}

class _CheckoutPagoScreenState extends State<CheckoutPagoScreen>
    with WidgetsBindingObserver {
  InicioCheckout? _inicio;
  Pago? _pago;
  bool _ocupado = false;
  bool _salio = false;
  int _secuencia = 0;
  String? _error;

  bool _vigente(int secuencia) =>
      mounted && widget.contextoVigente() && secuencia == _secuencia;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciar();
  }

  @override
  void dispose() {
    _secuencia++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _salio &&
        !_ocupado &&
        widget.contextoVigente()) {
      _salio = false;
      _consultar();
    }
  }

  String _mensaje(Object error) => error is ApiException
      ? error.mensaje
      : 'No pudimos comprobar el resultado. Conservamos la misma solicitud; no repitas el pago.';

  Future<void> _iniciar() async {
    if (_ocupado || !widget.contextoVigente()) return;
    final secuencia = ++_secuencia;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final inicio = await widget.iniciar(widget.importe, widget.clave);
      if (!_vigente(secuencia)) return;
      setState(() {
        _inicio = inicio;
        _pago = inicio.pago;
      });
    } catch (error) {
      if (_vigente(secuencia)) setState(() => _error = _mensaje(error));
    } finally {
      if (_vigente(secuencia)) setState(() => _ocupado = false);
    }
  }

  Future<void> _consultar() async {
    final pago = _pago;
    if (_ocupado || pago == null || !widget.contextoVigente()) return;
    final secuencia = ++_secuencia;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final actualizado = await widget.consultar(pago.idPago);
      if (!_vigente(secuencia)) return;
      if (actualizado.idPago != pago.idPago) {
        throw const FormatException('Pago inconsistente.');
      }
      setState(() => _pago = actualizado);
    } catch (error) {
      if (_vigente(secuencia)) setState(() => _error = _mensaje(error));
    } finally {
      if (_vigente(secuencia)) setState(() => _ocupado = false);
    }
  }

  Future<void> _abrir() async {
    final url = _inicio?.url;
    if (_ocupado ||
        url == null ||
        _pago?.estado != EstadoPago.pendiente ||
        !widget.contextoVigente()) {
      return;
    }
    final secuencia = ++_secuencia;
    setState(() {
      _ocupado = true;
      _error = null;
      _salio = true;
    });
    try {
      final abierta = await widget.abrir(validarUrlCheckout(url.toString()));
      if (_vigente(secuencia) && !abierta) {
        setState(
          () => _error = 'El navegador no pudo abrir Mercado Pago. Podés volver a usar este enlace; no se creó otro pago.',
        );
      }
    } catch (_) {
      if (_vigente(secuencia)) {
        setState(() => _error = 'No se pudo abrir el enlace de pruebas.');
      }
    } finally {
      if (_vigente(secuencia)) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pagar con Mercado Pago')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(importeLegible(widget.importe)),
        if (_ocupado) const LinearProgressIndicator(),
        if (_pago case final pago?) ...[
          Text(
            'Pago ${pago.idPago}: ${pago.estado.etiqueta}',
            key: const Key('checkout-estado'),
          ),
          if (pago.estado == EstadoPago.pendiente)
            const Text(
              'Abrir, abandonar o regresar del checkout no confirma el pago. Consultá su estado en VanFull.',
            ),
          if (pago.estado == EstadoPago.confirmado)
            const Text('El backend confirmó la acreditación.'),
        ],
        if (_inicio?.estado != 'LISTO' &&
            _pago?.estado != EstadoPago.confirmado)
          const Text(
            'El inicio todavía no está comprobado. Reintentar consulta la misma solicitud, sin iniciar otro cobro.',
          ),
        if (_error != null) Text(_error!, key: const Key('checkout-error')),
        if (_inicio?.url != null && _pago?.estado == EstadoPago.pendiente)
          ElevatedButton(
            key: const Key('abrir-checkout'),
            onPressed: _ocupado ? null : _abrir,
            child: const Text('Abrir Mercado Pago'),
          ),
        if (_inicio == null || _inicio?.estado != 'LISTO')
          OutlinedButton(
            key: const Key('reintentar-checkout'),
            onPressed: _ocupado ? null : _iniciar,
            child: const Text('Reintentar inicio de la misma solicitud'),
          ),
        if (_pago != null)
          OutlinedButton(
            key: const Key('consultar-checkout'),
            onPressed: _ocupado ? null : _consultar,
            child: const Text('Consultar estado'),
          ),
        TextButton(
          key: const Key('volver-checkout'),
          onPressed: () => Navigator.of(context).pop(_pago),
          child: const Text('Volver a VanFull'),
        ),
      ],
    ),
  );
}
