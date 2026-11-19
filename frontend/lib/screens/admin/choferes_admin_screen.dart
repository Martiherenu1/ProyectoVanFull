import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../models/admin/chofer_admin.dart';

typedef CargarChoferes = Future<List<ChoferAdmin>> Function();
typedef CrearChofer = Future<ChoferAdmin> Function(ChoferAdminCreate datos);
typedef ActualizarChofer = Future<ChoferAdmin> Function(
  int idPersona,
  ChoferAdminUpdate datos,
);

class ChoferesAdminScreen extends StatefulWidget {
  const ChoferesAdminScreen({
    required this.cargar,
    required this.crear,
    required this.actualizar,
    super.key,
  });

  final CargarChoferes cargar;
  final CrearChofer crear;
  final ActualizarChofer actualizar;

  @override
  State<ChoferesAdminScreen> createState() => _ChoferesAdminScreenState();
}

class _ChoferesAdminScreenState extends State<ChoferesAdminScreen> {
  List<ChoferAdmin> _choferes = const [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final choferes = await widget.cargar();
      if (!mounted) return;
      setState(() {
        _choferes = List.unmodifiable(choferes);
        _cargando = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = error.mensaje;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No pudimos cargar los choferes. Volvé a intentar.';
      });
    }
  }

  Future<void> _abrirFormulario([ChoferAdmin? chofer]) async {
    final guardado = await showDialog<ChoferAdmin>(
      context: context,
      builder: (_) => _FormularioChofer(
        chofer: chofer,
        guardar: (datos) => chofer == null
            ? widget.crear(
                ChoferAdminCreate(
                  nombre: datos.nombre,
                  apellido: datos.apellido,
                  dni: datos.dni,
                  direccion: datos.direccion,
                  telefono: datos.telefono,
                  email: datos.email,
                  cuil: datos.cuil,
                  registroConducir: datos.registroConducir,
                  fechaVencimientoRegistro: datos.fechaVencimientoRegistro,
                ),
              )
            : widget.actualizar(
                chofer.idPersona,
                ChoferAdminUpdate(
                  nombre: datos.nombre,
                  apellido: datos.apellido,
                  dni: datos.dni,
                  direccion: datos.direccion,
                  telefono: datos.telefono,
                  email: datos.email,
                  cuil: datos.cuil,
                  registroConducir: datos.registroConducir,
                  fechaVencimientoRegistro: datos.fechaVencimientoRegistro,
                ),
              ),
      ),
    );
    if (!mounted || guardado == null) return;
    final actualizados = [..._choferes];
    final indice = actualizados.indexWhere(
      (item) => item.idPersona == guardado.idPersona,
    );
    if (indice == -1) {
      actualizados.add(guardado);
    } else {
      actualizados[indice] = guardado;
    }
    actualizados.sort((a, b) => a.idPersona.compareTo(b.idPersona));
    setState(() => _choferes = List.unmodifiable(actualizados));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Administrar choferes'),
      actions: [
        IconButton(
          key: const Key('actualizar-choferes'),
          tooltip: 'Actualizar choferes',
          onPressed: _cargando ? null : _cargar,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('registrar-chofer'),
      onPressed: () => _abrirFormulario(),
      icon: const Icon(Icons.add),
      label: const Text('Registrar chofer'),
    ),
    body: _contenido(),
  );

  Widget _contenido() {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Cargando choferes'),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, key: const Key('error-choferes')),
            const SizedBox(height: 16),
            FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_choferes.isEmpty) {
      return const Center(child: Text('No hay choferes registrados.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _choferes.length,
      itemBuilder: (context, index) {
        final chofer = _choferes[index];
        return Card(
          key: Key('chofer-${chofer.idPersona}'),
          child: ListTile(
            title: Text('${chofer.nombre} ${chofer.apellido}'),
            subtitle: Text(
              'DNI: ${chofer.dni}\n'
              'Registro: ${chofer.registroConducir ?? 'Sin informar'} · '
              'Vence: ${_fechaVisible(chofer.fechaVencimientoRegistro)}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              key: Key('editar-chofer-${chofer.idPersona}'),
              tooltip: 'Modificar ${chofer.nombre} ${chofer.apellido}',
              onPressed: () => _abrirFormulario(chofer),
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        );
      },
    );
  }
}

final class _DatosChofer {
  const _DatosChofer({
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.direccion,
    required this.telefono,
    required this.email,
    required this.cuil,
    required this.registroConducir,
    required this.fechaVencimientoRegistro,
  });

  final String nombre;
  final String apellido;
  final String dni;
  final String? direccion;
  final String? telefono;
  final String? email;
  final String? cuil;
  final String? registroConducir;
  final DateTime? fechaVencimientoRegistro;
}

typedef _GuardarChofer = Future<ChoferAdmin> Function(_DatosChofer datos);

class _FormularioChofer extends StatefulWidget {
  const _FormularioChofer({required this.chofer, required this.guardar});

  final ChoferAdmin? chofer;
  final _GuardarChofer guardar;

  @override
  State<_FormularioChofer> createState() => _FormularioChoferState();
}

class _FormularioChoferState extends State<_FormularioChofer> {
  final _formulario = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _campos;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.chofer;
    _campos = {
      'nombre': TextEditingController(text: c?.nombre ?? ''),
      'apellido': TextEditingController(text: c?.apellido ?? ''),
      'dni': TextEditingController(text: c?.dni ?? ''),
      'direccion': TextEditingController(text: c?.direccion ?? ''),
      'telefono': TextEditingController(text: c?.telefono ?? ''),
      'email': TextEditingController(text: c?.email ?? ''),
      'cuil': TextEditingController(text: c?.cuil ?? ''),
      'registro': TextEditingController(text: c?.registroConducir ?? ''),
      'vencimiento': TextEditingController(
        text: c?.fechaVencimientoRegistro == null
            ? ''
            : _fechaIso(c!.fechaVencimientoRegistro!),
      ),
    };
  }

  String? _requerido(String? valor) => valor == null || valor.trim().isEmpty
      ? 'Este campo es obligatorio.'
      : null;

  String? _fechaValida(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return null;
    final fecha = DateTime.tryParse(texto);
    return fecha == null || _fechaIso(fecha) != texto
        ? 'Usá el formato AAAA-MM-DD.'
        : null;
  }

  String? _nuloSiVacio(String campo) {
    final valor = _campos[campo]!.text.trim();
    return valor.isEmpty ? null : valor;
  }

  Future<void> _guardar() async {
    if (_guardando || !_formulario.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final vencimiento = _nuloSiVacio('vencimiento');
    try {
      final chofer = await widget.guardar(
        _DatosChofer(
          nombre: _campos['nombre']!.text.trim(),
          apellido: _campos['apellido']!.text.trim(),
          dni: _campos['dni']!.text.trim(),
          direccion: _nuloSiVacio('direccion'),
          telefono: _nuloSiVacio('telefono'),
          email: _nuloSiVacio('email'),
          cuil: _nuloSiVacio('cuil'),
          registroConducir: _nuloSiVacio('registro'),
          fechaVencimientoRegistro: vencimiento == null
              ? null
              : DateTime.parse(vencimiento),
        ),
      );
      if (mounted) Navigator.of(context).pop(chofer);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = error.mensaje;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'No pudimos guardar el chofer. Volvé a intentar.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.chofer == null ? 'Registrar chofer' : 'Modificar chofer'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: _formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _campo('nombre', 'Nombre', 80, requerido: true),
              _campo('apellido', 'Apellido', 80, requerido: true),
              _campo('dni', 'DNI', 20, requerido: true),
              _campo('direccion', 'Dirección (opcional)', 200),
              _campo('telefono', 'Teléfono (opcional)', 30),
              _campo('email', 'Email (opcional)', 120),
              _campo('cuil', 'CUIL (opcional)', 20),
              _campo('registro', 'Registro de conducir (opcional)', 40),
              TextFormField(
                key: const Key('chofer-vencimiento'),
                controller: _campos['vencimiento'],
                decoration: const InputDecoration(
                  labelText: 'Vencimiento del registro (AAAA-MM-DD, opcional)',
                ),
                validator: _fechaValida,
              ),
              if (_error != null)
                Text(_error!, key: const Key('error-guardar-chofer')),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _guardando ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('guardar-chofer'),
        onPressed: _guardando ? null : _guardar,
        child: Text(_guardando ? 'Guardando…' : 'Guardar'),
      ),
    ],
  );

  Widget _campo(String clave, String etiqueta, int maximo, {bool requerido = false}) =>
      TextFormField(
        key: Key('chofer-$clave'),
        controller: _campos[clave],
        maxLength: maximo,
        decoration: InputDecoration(labelText: etiqueta),
        validator: requerido ? _requerido : null,
      );

  @override
  void dispose() {
    for (final controller in _campos.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

String _fechaIso(DateTime fecha) =>
    '${fecha.year.toString().padLeft(4, '0')}-'
    '${fecha.month.toString().padLeft(2, '0')}-'
    '${fecha.day.toString().padLeft(2, '0')}';

String _fechaVisible(DateTime? fecha) => fecha == null
    ? 'Sin informar'
    : '${fecha.day.toString().padLeft(2, '0')}/'
          '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
