import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/admin/tarifa_gestion.dart';

typedef ListarTarifas = Future<List<TarifaGestion>> Function();
typedef CrearTarifa = Future<TarifaGestion> Function(TarifaGestionCreate datos);
typedef ModificarTarifa = Future<TarifaGestion> Function(
  int id,
  Map<String, Object?> cambios,
);

/// CU-031: el dueño lista, crea y modifica tarifas.
///
/// Sin descuentos especiales, vigencias ni historial: la v1.3 los deja
/// pendientes. Modificar una tarifa no recalcula contrataciones ya hechas.
class TarifasAdminScreen extends StatefulWidget {
  const TarifasAdminScreen({
    required this.listar,
    required this.crear,
    required this.modificar,
    super.key,
  });

  final ListarTarifas listar;
  final CrearTarifa crear;
  final ModificarTarifa modificar;

  @override
  State<TarifasAdminScreen> createState() => _TarifasAdminScreenState();
}

class _TarifasAdminScreenState extends State<TarifasAdminScreen> {
  List<TarifaGestion>? _items;
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

  Future<void> _abrirFormulario([TarifaGestion? existente]) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoTarifa(
        existente: existente,
        crear: widget.crear,
        modificar: widget.modificar,
      ),
    );
    if (guardado == true) await _cargar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tarifas')),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('tarifas-nueva'),
      onPressed: _abrirFormulario,
      icon: const Icon(Icons.add),
      label: const Text('Nueva tarifa'),
    ),
    body: _cuerpo(),
  );

  Widget _cuerpo() {
    if (_error) {
      return Center(
        key: const Key('tarifas-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No se pudo cargar la lista de tarifas.'),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const Key('tarifas-reintentar'),
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
        key: Key('tarifas-cargando'),
        child: CircularProgressIndicator(),
      );
    }
    if (items.isEmpty) {
      return const Center(
        key: Key('tarifas-vacio'),
        child: Text('Todavía no hay tarifas.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _fila(items[i]),
    );
  }

  Widget _fila(TarifaGestion t) => ListTile(
    key: Key('tarifa-${t.idTarifa}'),
    title: Text(t.nombre),
    subtitle: Text(
      '\$ ${t.importe.toStringAsFixed(2)}'
      '${t.tipo == null ? '' : ' · ${t.tipo}'}'
      '${t.fechaVigencia == null ? '' : ' · vigencia ${t.fechaVigencia}'}',
    ),
    trailing: IconButton(
      key: Key('tarifa-editar-${t.idTarifa}'),
      tooltip: 'Modificar',
      icon: const Icon(Icons.edit_outlined),
      onPressed: () => _abrirFormulario(t),
    ),
  );
}

String _mensajeError(Object e) => switch (e) {
  ApiException(statusCode: 403) => 'Solo el dueño puede gestionar tarifas.',
  ApiException(codigo: 'TARIFA_NO_ENCONTRADA') => 'La tarifa ya no existe.',
  ApiException(:final mensaje) => mensaje,
  _ => 'No se pudo completar la operación. Probá de nuevo.',
};

class _DialogoTarifa extends StatefulWidget {
  const _DialogoTarifa({
    required this.existente,
    required this.crear,
    required this.modificar,
  });

  final TarifaGestion? existente;
  final CrearTarifa crear;
  final ModificarTarifa modificar;

  @override
  State<_DialogoTarifa> createState() => _DialogoTarifaState();
}

class _DialogoTarifaState extends State<_DialogoTarifa> {
  final _formulario = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.existente?.nombre);
  late final _importe = TextEditingController(
    text: widget.existente?.importe.toStringAsFixed(2),
  );
  late final _tipo = TextEditingController(text: widget.existente?.tipo);
  late final _vigencia = TextEditingController(
    text: widget.existente?.fechaVigencia,
  );
  bool _enviando = false;
  String? _mensaje;

  bool get _esAlta => widget.existente == null;

  @override
  void dispose() {
    for (final c in [_nombre, _importe, _tipo, _vigencia]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Acepta coma o punto; máximo dos decimales (la columna es NUMERIC(12,2)).
  static double? _leerImporte(String? texto) {
    final limpio = (texto ?? '').trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(limpio)) return null;
    final importe = double.parse(limpio);
    return importe <= 9999999999.99 ? importe : null;
  }

  String? _validarImporte(String? v) =>
      _leerImporte(v) == null ? 'Importe válido, con hasta 2 decimales' : null;

  String? _validarVigencia(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final fecha = DateTime.tryParse(t);
    return fecha != null &&
            fecha.year > 0 &&
            t.length == 10 &&
            fecha.toIso8601String().split('T').first == t
        ? null
        : 'Formato AAAA-MM-DD';
  }

  Map<String, Object?> _cambios(TarifaGestion t) {
    final cambios = <String, Object?>{};
    final nombre = _nombre.text.trim();
    if (nombre != t.nombre) cambios['nombre'] = nombre;
    final importe = _leerImporte(_importe.text)!;
    if (importe != t.importe) cambios['importe'] = importe;
    // `tipo` y `fecha_vigencia` aceptan null: vaciar el campo los borra.
    final tipo = _tipo.text.trim();
    if (tipo != (t.tipo ?? '')) cambios['tipo'] = tipo.isEmpty ? null : tipo;
    final vigencia = _vigencia.text.trim();
    if (vigencia != (t.fechaVigencia ?? '')) {
      cambios['fecha_vigencia'] = vigencia.isEmpty ? null : vigencia;
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
          TarifaGestionCreate(
            nombre: _nombre.text.trim(),
            importe: _leerImporte(_importe.text)!,
            tipo: _tipo.text.trim(),
            fechaVigencia: _vigencia.text.trim(),
          ),
        );
      } else {
        final cambios = _cambios(existente);
        if (cambios.isNotEmpty) {
          await widget.modificar(existente.idTarifa, cambios);
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
    TextInputType? teclado,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: TextFormField(
      key: Key('tarifa-campo-$clave'),
      controller: c,
      keyboardType: teclado,
      decoration: InputDecoration(labelText: etiqueta),
      validator: validar,
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_esAlta ? 'Nueva tarifa' : 'Modificar tarifa'),
    content: SingleChildScrollView(
      child: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _campo(
              'nombre',
              'Nombre',
              _nombre,
              validar: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            _campo(
              'importe',
              'Importe',
              _importe,
              validar: _validarImporte,
              teclado: const TextInputType.numberWithOptions(decimal: true),
            ),
            _campo('tipo', 'Tipo (opcional)', _tipo),
            _campo(
              'vigencia',
              'Vigencia (opcional, AAAA-MM-DD)',
              _vigencia,
              validar: _validarVigencia,
            ),
            if (_mensaje != null)
              Text(
                _mensaje!,
                key: const Key('tarifa-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        key: const Key('tarifa-cancelar'),
        onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('tarifa-guardar'),
        onPressed: _enviando ? null : _guardar,
        child: Text(_esAlta ? 'Crear' : 'Guardar'),
      ),
    ],
  );
}
