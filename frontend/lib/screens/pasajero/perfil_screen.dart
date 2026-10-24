import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/pasajero/perfil.dart';

/// GET /pasajeros/me.
typedef CargarPerfil = Future<Perfil> Function();

/// PATCH /pasajeros/me con los campos que cambiaron (`email`, `telefono`,
/// `direccion`). Los rechazos del contrato llegan como [ApiException].
typedef ModificarPerfil = Future<Perfil> Function(Map<String, String> cambios);

/// CU-001 en la pestaña Cuenta. Nombre, apellido y DNI se muestran sin edición
/// (RN-026); correo, teléfono y dirección se editan y el backend decide si el
/// cambio vale. No hay verificación del contacto ni foto: #25 sigue abierto.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({
    super.key,
    required this.cargarPerfil,
    required this.modificarPerfil,
    required this.onSalir,
  });

  final CargarPerfil cargarPerfil;
  final ModificarPerfil modificarPerfil;
  final VoidCallback onSalir;

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();

  Perfil? _perfil;
  bool _cargando = true;
  bool _errorCarga = false;
  bool _guardando = false;
  String? _aviso;
  bool _guardado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _email.dispose();
    _telefono.dispose();
    _direccion.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = false;
    });
    try {
      final perfil = await widget.cargarPerfil();
      if (!mounted) return;
      setState(() {
        _mostrar(perfil);
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = true;
      });
    }
  }

  void _mostrar(Perfil perfil) {
    _perfil = perfil;
    _email.text = perfil.email ?? '';
    _telefono.text = perfil.telefono ?? '';
    _direccion.text = perfil.direccion ?? '';
  }

  /// Los campos cuyo texto difiere del perfil cargado, sin espacios de más.
  Map<String, String> get _cambios {
    final perfil = _perfil;
    if (perfil == null) return const {};
    return {
      if (_email.text.trim() != (perfil.email ?? ''))
        'email': _email.text.trim(),
      if (_telefono.text.trim() != (perfil.telefono ?? ''))
        'telefono': _telefono.text.trim(),
      if (_direccion.text.trim() != (perfil.direccion ?? ''))
        'direccion': _direccion.text.trim(),
    };
  }

  /// El backend no admite vaciar un dato: omitirlo lo deja como está.
  bool get _hayVacios => _cambios.values.any((valor) => valor.isEmpty);

  Future<void> _guardar() async {
    final cambios = _cambios;
    if (cambios.isEmpty || _hayVacios || _guardando) return;
    setState(() {
      _guardando = true;
      _aviso = null;
      _guardado = false;
    });
    try {
      final perfil = await widget.modificarPerfil(cambios);
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _guardado = true;
        _mostrar(perfil);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _aviso = _avisoDe(error);
      });
    }
  }

  String _avisoDe(Object error) {
    if (error is ApiException &&
        (error.statusCode == 400 || error.statusCode == 403)) {
      return error.mensaje;
    }
    return 'No pudimos guardar los cambios. Volvé a intentar.';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.passenger,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Cuenta')),
          body: SafeArea(child: _contenido(context)),
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context) {
    if (_cargando) {
      return Center(
        child: Semantics(
          label: 'Cargando tu perfil',
          child: const CircularProgressIndicator(),
        ),
      );
    }
    if (_errorCarga) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No pudimos cargar tu perfil. Volvé a intentar.'),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              key: const ValueKey('reintentar-perfil'),
              onPressed: _cargar,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.touchTarget),
              ),
              child: const Text('Reintentar'),
            ),
            const Spacer(),
            _botonSalir(),
          ],
        ),
      );
    }
    return _formulario(context, _perfil!);
  }

  Widget _formulario(BuildContext context, Perfil perfil) {
    final textTheme = Theme.of(context).textTheme;
    final listo = _cambios.isNotEmpty && !_hayVacios;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('NOMBRE', style: textTheme.labelSmall),
        Text(
          '${perfil.nombre} ${perfil.apellido}',
          key: const ValueKey('nombre-perfil'),
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('DNI', style: textTheme.labelSmall),
        Text(perfil.dni, key: const ValueKey('dni-perfil')),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Si tu nombre o tu DNI están mal, los corrige administración.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xl),
        _campo('email-perfil', 'CORREO', _email, TextInputType.emailAddress),
        _campo('telefono-perfil', 'TELÉFONO', _telefono, TextInputType.phone),
        _campo(
          'direccion-perfil',
          'DIRECCIÓN',
          _direccion,
          TextInputType.streetAddress,
        ),
        if (_aviso != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              _aviso!,
              key: const ValueKey('aviso-perfil'),
              style: textTheme.bodyMedium?.copyWith(color: AppColors.alertDark),
            ),
          ),
        if (_guardado && _cambios.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text('Cambios guardados.', key: const ValueKey('guardado')),
          ),
        ElevatedButton(
          key: const ValueKey('guardar-perfil'),
          onPressed: listo && !_guardando ? _guardar : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, AppSpacing.touchTarget),
          ),
          child: Text(_guardando ? 'Guardando…' : 'Guardar cambios'),
        ),
        const SizedBox(height: AppSpacing.xl),
        _botonSalir(),
      ],
    );
  }

  Widget _campo(
    String clave,
    String etiqueta,
    TextEditingController controlador,
    TextInputType teclado,
  ) {
    final vacio = controlador.text.trim().isEmpty;
    final cambiado = _cambios.isNotEmpty && _campoCambiado(controlador);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: TextField(
        key: ValueKey(clave),
        controller: controlador,
        enabled: !_guardando,
        keyboardType: teclado,
        decoration: InputDecoration(
          labelText: etiqueta,
          errorText: vacio && cambiado ? 'No puede quedar vacío.' : null,
        ),
        onChanged: (_) => setState(() {
          _aviso = null;
          _guardado = false;
        }),
      ),
    );
  }

  bool _campoCambiado(TextEditingController controlador) {
    final cambios = _cambios;
    if (identical(controlador, _email)) return cambios.containsKey('email');
    if (identical(controlador, _telefono)) {
      return cambios.containsKey('telefono');
    }
    return cambios.containsKey('direccion');
  }

  Widget _botonSalir() => SizedBox(
    height: AppSpacing.touchTarget,
    width: double.infinity,
    child: OutlinedButton(
      key: const ValueKey('cerrar-sesion'),
      onPressed: widget.onSalir,
      child: const Text('Cerrar sesión'),
    ),
  );
}
