import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/format/importe.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/pasajero/pago.dart';

/// POST /pagos sin `id_cliente`: el backend usa la cuenta del pasajero. Los
/// rechazos del contrato llegan como [ApiException]; el resto, tal cual.
typedef RegistrarPago = Future<Pago> Function(double importe, MedioPago medio);

/// Pantalla 5 del PC1 (CU-014). El pasajero informa cuánto pagó y cómo; la
/// pantalla no confirma nada ni toca el saldo: el pago queda pendiente hasta
/// que lo confirme administración (CU-016, RN-015).
class PagoScreen extends StatefulWidget {
  const PagoScreen({
    super.key,
    required this.registrarPago,
    required this.onTerminar,
    this.saldo,
  });

  final RegistrarPago registrarPago;

  /// El pasajero vio su pago registrado y vuelve.
  final ValueChanged<Pago> onTerminar;

  /// Lo que debe hoy, para sugerirlo como importe. Es solo una sugerencia.
  final double? saldo;

  @override
  State<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends State<PagoScreen> {
  late final TextEditingController _importe;
  MedioPago? _medio;
  bool _enviando = false;
  _Aviso? _aviso;
  Pago? _pago;

  @override
  void initState() {
    super.initState();
    final saldo = widget.saldo;
    _importe = TextEditingController(
      text: saldo != null && saldo > 0 ? importeEditable(saldo) : '',
    );
  }

  @override
  void dispose() {
    _importe.dispose();
    super.dispose();
  }

  double? get _importeValido {
    final importe = leerImporte(_importe.text);
    return importe != null && importe > 0 ? importe : null;
  }

  Future<void> _registrar() async {
    final importe = _importeValido;
    final medio = _medio;
    if (importe == null || medio == null || _enviando) return;
    setState(() {
      _enviando = true;
      _aviso = null;
    });
    try {
      final pago = await widget.registrarPago(importe, medio);
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _pago = pago;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _aviso = _avisoDe(error);
      });
    }
  }

  _Aviso _avisoDe(Object error) {
    if (error is ApiException) {
      return switch (error.codigo) {
        'CLIENTE_NO_ENCONTRADO' ||
        'CUENTA_CORRIENTE_NO_ENCONTRADA' => const _Aviso(
          'Tu cuenta todavía no admite pagos. Consultá con administración.',
          definitivo: true,
        ),
        _ when error.statusCode == 400 => _Aviso(error.mensaje),
        _ => const _Aviso('No pudimos registrar el pago. Volvé a intentar.'),
      };
    }
    return const _Aviso('No pudimos registrar el pago. Volvé a intentar.');
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.passenger,
      child: Builder(
        builder: (context) {
          final pago = _pago;
          return Scaffold(
            appBar: AppBar(
              title: Text(
                pago == null ? 'Registrar un pago' : 'Pago registrado',
              ),
              automaticallyImplyLeading: pago == null,
            ),
            body: SafeArea(
              child: pago == null
                  ? _formulario(context)
                  : _Resultado(
                      pago: pago,
                      onTerminar: () => widget.onTerminar(pago),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _formulario(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final aviso = _aviso;
    final bloqueado = aviso?.definitivo ?? false;
    final listo = _importeValido != null && _medio != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('¿CUÁNTO PAGASTE?', style: textTheme.labelSmall),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('importe-pago'),
                controller: _importe,
                enabled: !_enviando,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: textTheme.headlineMedium,
                decoration: InputDecoration(
                  prefixText: r'$ ',
                  errorText: _importe.text.isNotEmpty && _importeValido == null
                      ? 'Escribí un importe mayor a cero, con hasta dos decimales.'
                      : null,
                ),
                onChanged: (_) => setState(() {
                  if (!bloqueado) _aviso = null;
                }),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('¿CÓMO PAGASTE?', style: textTheme.labelSmall),
              const SizedBox(height: AppSpacing.sm),
              for (final medio in MedioPago.values)
                _FilaMedio(
                  medio: medio,
                  elegido: medio == _medio,
                  onTap: _enviando
                      ? null
                      : () => setState(() {
                          _medio = medio;
                          if (!bloqueado) _aviso = null;
                        }),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Administración revisa el pago y lo confirma. Hasta entonces '
                'tu saldo no cambia.',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (aviso != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              aviso.texto,
              key: const ValueKey('aviso-pago'),
              style: textTheme.bodyMedium?.copyWith(color: AppColors.alertDark),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ElevatedButton(
            key: const ValueKey('registrar-pago'),
            onPressed: !listo || _enviando || bloqueado ? null : _registrar,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.touchTarget),
            ),
            child: Text(_enviando ? 'Registrando…' : 'Registrar pago'),
          ),
        ),
      ],
    );
  }
}

/// Texto de un rechazo. `definitivo`: reintentar con los mismos datos no
/// cambia el resultado, así que se bloquea el botón.
class _Aviso {
  const _Aviso(this.texto, {this.definitivo = false});

  final String texto;
  final bool definitivo;
}

class _FilaMedio extends StatelessWidget {
  const _FilaMedio({
    required this.medio,
    required this.elegido,
    required this.onTap,
  });

  final MedioPago medio;
  final bool elegido;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: elegido,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        key: ValueKey('medio-${medio.valorApi}'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.passengerRowHeight,
          ),
          child: Row(
            children: [
              Expanded(child: Text(medio.etiqueta)),
              Icon(
                elegido
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: elegido ? Theme.of(context).colorScheme.primary : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Resultado extends StatelessWidget {
  const _Resultado({required this.pago, required this.onTerminar});

  final Pago pago;
  final VoidCallback onTerminar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pendiente = pago.estado == EstadoPago.pendiente;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('IMPORTE', style: textTheme.labelSmall),
          Text(
            importeLegible(pago.importe),
            key: const ValueKey('importe-registrado'),
            style: textTheme.displayLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Pago ${pago.estado.etiqueta.toLowerCase()}',
            key: const ValueKey('estado-pago'),
            style: textTheme.titleLarge?.copyWith(
              color: pendiente ? AppColors.waitDark : null,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (pendiente)
            const Text(
              'Administración lo confirma y recién ahí se descuenta de tu '
              'saldo.',
            ),
          const Spacer(),
          ElevatedButton(
            key: const ValueKey('terminar-pago'),
            onPressed: onTerminar,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.touchTarget),
            ),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }
}
