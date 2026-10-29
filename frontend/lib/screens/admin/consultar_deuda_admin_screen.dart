import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/pasajero/deuda.dart';
import '../../services/admin/consulta_deuda_admin.dart';
import '../../widgets/admin/resumen_deuda_admin.dart';

/// Preparación parcial CU-015: identificación/consulta visual, sin HTTP ni acciones.
class ConsultarDeudaAdminScreen extends StatefulWidget {
  const ConsultarDeudaAdminScreen({
    super.key,
    required this.consulta,
    required this.alcance,
  });
  final ConsultaDeudaAdmin consulta;

  /// Identidad opaca a renovar al cambiar sesión. No usar credenciales como key.
  final Object alcance;
  @override
  State<ConsultarDeudaAdminScreen> createState() =>
      _ConsultarDeudaAdminScreenState();
}

class _ConsultarDeudaAdminScreenState extends State<ConsultarDeudaAdminScreen> {
  final _cliente = TextEditingController();
  int? _idConsultado;
  Deuda? _deuda;
  String? _error;
  bool _cargando = false;
  int _solicitud = 0;
  @override
  void dispose() {
    _cliente.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ConsultarDeudaAdminScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.consulta, oldWidget.consulta) ||
        !identical(widget.alcance, oldWidget.alcance)) {
      _cliente.clear();
      _limpiar();
    }
  }

  void _limpiar() {
    _solicitud++;
    setState(() {
      _idConsultado = null;
      _deuda = null;
      _error = null;
      _cargando = false;
    });
  }

  Future<void> _consultar() async {
    if (_cargando) return;
    final id = int.tryParse(_cliente.text.trim());
    if (id == null || id <= 0) {
      setState(() => _error = 'Indicá un ID de cliente válido.');
      return;
    }
    final solicitud = ++_solicitud;
    setState(() {
      _idConsultado = id;
      _deuda = null;
      _error = null;
      _cargando = true;
    });
    try {
      final deuda = await widget.consulta.consultar(id);
      if (!mounted || solicitud != _solicitud) return;
      setState(() {
        _deuda = deuda;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted || solicitud != _solicitud) return;
      setState(() {
        _deuda = null;
        _cargando = false;
        _error = e is ApiException
            ? e.mensaje
            : 'No pudimos consultar la deuda. Volvé a intentar.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.admin,
    child: Scaffold(
      appBar: AppBar(title: const Text('Consultar deuda de cliente')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('deuda-id-cliente'),
              controller: _cliente,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ID del cliente'),
              onChanged: (_) => _limpiar(),
              onSubmitted: (_) => _consultar(),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('consultar-deuda-admin'),
              onPressed: _cargando ? null : _consultar,
              child: const Text('Consultar'),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_cargando)
              const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Consultando deuda',
                ),
              )
            else if (_error != null) ...[
              Text(_error!, key: const Key('error-consulta-deuda')),
              TextButton(
                onPressed: _consultar,
                child: const Text('Reintentar'),
              ),
            ] else if (_idConsultado case final id?)
              ResumenDeudaAdmin(idCliente: id, deuda: _deuda)
            else
              const Text('Indicá el cliente que querés consultar.'),
          ],
        ),
      ),
    ),
  );
}
