import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/admin/administrador.dart';

typedef ListarAdministradores = Future<List<Administrador>> Function();
typedef CrearAdministrador = Future<Administrador> Function(
  AdministradorCreate datos,
);
typedef ModificarAdministrador = Future<Administrador> Function(
  int id,
  Map<String, Object?> cambios,
);
typedef DeshabilitarAdministrador = Future<Administrador> Function(int id);

/// CU-032: el dueño lista, da de alta, modifica y deshabilita administradores.
/// Deshabilitar no borra: la cuenta deja de poder iniciar sesión (RF-041).
class AdministradoresAdminScreen extends StatefulWidget {
  const AdministradoresAdminScreen({
    required this.listar,
    required this.crear,
    required this.modificar,
    required this.deshabilitar,
    super.key,
  });

  final ListarAdministradores listar;
  final CrearAdministrador crear;
  final ModificarAdministrador modificar;
  final DeshabilitarAdministrador deshabilitar;

  @override
  State<AdministradoresAdminScreen> createState() =>
      _AdministradoresAdminScreenState();
}

class _AdministradoresAdminScreenState
    extends State<AdministradoresAdminScreen> {
  List<Administrador>? _items;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _items = null;
      _error = false;
    });
    try {
      final items = await widget.listar();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _abrirFormulario([Administrador? existente]) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoAdministrador(
        existente: existente,
        crear: widget.crear,
        modificar: widget.modificar,
      ),
    );
    if (guardado == true) await _cargar();
  }

  Future<void> _deshabilitar(Administrador a) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Deshabilitar administrador'),
        content: Text(
          '${a.nombreCompleto} no va a poder iniciar sesión. '
          'No se borra ningún dato.',
        ),
        actions: [
          TextButton(
            key: const Key('administradores-cancelar-deshabilitar'),
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('administradores-confirmar-deshabilitar'),
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Deshabilitar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      await widget.deshabilitar(a.idCuentaAcceso);
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_mensajeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Administradores')),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('administradores-nuevo'),
      onPressed: _abrirFormulario,
      icon: const Icon(Icons.add),
      label: const Text('Nuevo administrador'),
    ),
    body: _cuerpo(),
  );

  Widget _cuerpo() {
    if (_error) {
      return Center(
        key: const Key('administradores-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No se pudo cargar la lista de administradores.'),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const Key('administradores-reintentar'),
              onPressed: _cargar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    final items = _items;
    if (items == null) {
      return const Center(
        key: Key('administradores-cargando'),
        child: CircularProgressIndicator(),
      );
    }
    if (items.isEmpty) {
      return const Center(
        key: Key('administradores-vacio'),
        child: Text('Todavía no hay administradores.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _fila(items[i]),
    );
  }

  Widget _fila(Administrador a) => ListTile(
    key: Key('administrador-${a.idCuentaAcceso}'),
    title: Text(a.nombreCompleto),
    subtitle: Text(
      'DNI ${a.dni} · ${a.identificadorAcceso} · '
      '${a.activo ? 'Activo' : 'Deshabilitado'}',
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: Key('administrador-editar-${a.idCuentaAcceso}'),
          tooltip: 'Modificar',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _abrirFormulario(a),
        ),
        if (a.activo)
          IconButton(
            key: Key('administrador-deshabilitar-${a.idCuentaAcceso}'),
            tooltip: 'Deshabilitar',
            icon: const Icon(Icons.block),
            onPressed: () => _deshabilitar(a),
          ),
      ],
    ),
  );
}

String _mensajeError(Object e) => switch (e) {
  ApiException(codigo: 'DNI_DUPLICADO') => 'Ya hay una persona con ese DNI.',
  ApiException(codigo: 'IDENTIFICADOR_EN_USO') =>
    'Ese identificador de acceso ya está en uso.',
  ApiException(codigo: 'ADMINISTRADOR_YA_DESHABILITADO') =>
    'La cuenta ya estaba deshabilitada.',
  ApiException(statusCode: 403) =>
    'Solo el dueño puede gestionar administradores.',
  ApiException(:final mensaje) => mensaje,
  _ => 'No se pudo completar la operación. Probá de nuevo.',
};

class _DialogoAdministrador extends StatefulWidget {
  const _DialogoAdministrador({
    required this.existente,
    required this.crear,
    required this.modificar,
  });

  final Administrador? existente;
  final CrearAdministrador crear;
  final ModificarAdministrador modificar;

  @override
  State<_DialogoAdministrador> createState() => _DialogoAdministradorState();
}

class _DialogoAdministradorState extends State<_DialogoAdministrador> {
  final _formulario = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.existente?.nombre);
  late final _apellido = TextEditingController(
    text: widget.existente?.apellido,
  );
  late final _dni = TextEditingController(text: widget.existente?.dni);
  late final _email = TextEditingController(text: widget.existente?.email);
  late final _telefono = TextEditingController(
    text: widget.existente?.telefono,
  );
  late final _identificador = TextEditingController(
    text: widget.existente?.identificadorAcceso,
  );
  final _contrasena = TextEditingController();
  bool _enviando = false;
  String? _mensaje;

  bool get _esAlta => widget.existente == null;

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _apellido,
      _dni,
      _email,
      _telefono,
      _identificador,
      _contrasena,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _obligatorio(String? v, {int min = 1}) =>
      (v == null || v.trim().length < min)
      ? (min == 1 ? 'Campo obligatorio' : 'Mínimo $min caracteres')
      : null;

  Map<String, Object?> _cambios(Administrador a) {
    final cambios = <String, Object?>{};
    void si(String campo, String nuevo, String? actual) {
      if (nuevo.trim() != (actual ?? '')) cambios[campo] = nuevo.trim();
    }

    si('nombre', _nombre.text, a.nombre);
    si('apellido', _apellido.text, a.apellido);
    si('dni', _dni.text, a.dni);
    si('identificador_acceso', _identificador.text, a.identificadorAcceso);
    // El contrato no admite null en estos campos: vaciarlos no se envía.
    if (_email.text.trim().isNotEmpty) si('email', _email.text, a.email);
    if (_telefono.text.trim().isNotEmpty) {
      si('telefono', _telefono.text, a.telefono);
    }
    return cambios;
  }

  Future<void> _guardar() async {
    if (_enviando || !_formulario.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _mensaje = null;
    });
    try {
      final existente = widget.existente;
      if (existente == null) {
        await widget.crear(
          AdministradorCreate(
            nombre: _nombre.text.trim(),
            apellido: _apellido.text.trim(),
            dni: _dni.text.trim(),
            identificadorAcceso: _identificador.text.trim(),
            contrasena: _contrasena.text,
            email: _email.text.trim(),
            telefono: _telefono.text.trim(),
          ),
        );
      } else {
        final cambios = _cambios(existente);
        if (cambios.isNotEmpty) {
          await widget.modificar(existente.idCuentaAcceso, cambios);
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _mensaje = _mensajeError(e);
      });
    }
  }

  Widget _campo(
    String clave,
    String etiqueta,
    TextEditingController c, {
    String? Function(String?)? validar,
    bool oculto = false,
    TextInputType? teclado,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: TextFormField(
      key: Key('administrador-campo-$clave'),
      controller: c,
      obscureText: oculto,
      keyboardType: teclado,
      decoration: InputDecoration(labelText: etiqueta),
      validator: validar,
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_esAlta ? 'Nuevo administrador' : 'Modificar administrador'),
    content: SingleChildScrollView(
      child: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _campo('nombre', 'Nombre', _nombre, validar: _obligatorio),
            _campo('apellido', 'Apellido', _apellido, validar: _obligatorio),
            _campo('dni', 'DNI', _dni, validar: _obligatorio),
            _campo(
              'identificador',
              'Identificador de acceso',
              _identificador,
              validar: (v) => _obligatorio(v, min: 3),
            ),
            if (_esAlta)
              _campo(
                'contrasena',
                'Contraseña (mín. 8)',
                _contrasena,
                oculto: true,
                validar: (v) =>
                    (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
              ),
            _campo(
              'email',
              'Email (opcional)',
              _email,
              teclado: TextInputType.emailAddress,
            ),
            _campo(
              'telefono',
              'Teléfono (opcional)',
              _telefono,
              teclado: TextInputType.phone,
            ),
            if (_mensaje != null)
              Text(
                _mensaje!,
                key: const Key('administrador-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        key: const Key('administrador-cancelar'),
        onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('administrador-guardar'),
        onPressed: _enviando ? null : _guardar,
        child: Text(_esAlta ? 'Crear' : 'Guardar'),
      ),
    ],
  );
}
