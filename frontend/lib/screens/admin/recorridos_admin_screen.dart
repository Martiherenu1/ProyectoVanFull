import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/admin/recorrido_gestion.dart';

typedef ListarRecorridos = Future<List<RecorridoGestion>> Function();
typedef ListarParadasCatalogo = Future<List<ParadaCatalogo>> Function();
typedef CrearParadaCatalogo = Future<ParadaCatalogo> Function(
  ParadaCatalogoCreate datos,
);
typedef CrearRecorrido = Future<RecorridoGestion> Function(List<int> idParadas);
typedef ReemplazarParadas = Future<RecorridoGestion> Function(
  int idRecorrido,
  List<int> idParadas,
);

/// CU-019: administración lista recorridos y edita sus paradas.
///
/// Las paradas comprometidas se muestran bloqueadas (RN-021): no se quitan ni
/// se mueven. Lo hace cumplir FastAPI; acá solo se evita proponerlo. La marca
/// es de solo lectura: cómo se compromete una parada está pendiente.
class RecorridosAdminScreen extends StatefulWidget {
  const RecorridosAdminScreen({
    required this.listar,
    required this.listarParadas,
    required this.crearParada,
    required this.crear,
    required this.reemplazar,
    super.key,
  });

  final ListarRecorridos listar;
  final ListarParadasCatalogo listarParadas;
  final CrearParadaCatalogo crearParada;
  final CrearRecorrido crear;
  final ReemplazarParadas reemplazar;

  @override
  State<RecorridosAdminScreen> createState() => _RecorridosAdminScreenState();
}

class _RecorridosAdminScreenState extends State<RecorridosAdminScreen> {
  List<RecorridoGestion>? _items;
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

  Future<void> _abrirEditor([RecorridoGestion? existente]) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _EditorRecorrido(
          existente: existente,
          listarParadas: widget.listarParadas,
          crearParada: widget.crearParada,
          crear: widget.crear,
          reemplazar: widget.reemplazar,
        ),
      ),
    );
    if (guardado == true) await _cargar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recorridos')),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('recorridos-nuevo'),
      onPressed: _abrirEditor,
      icon: const Icon(Icons.add),
      label: const Text('Nuevo recorrido'),
    ),
    body: _cuerpo(),
  );

  Widget _cuerpo() {
    if (_error) {
      return Center(
        key: const Key('recorridos-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No se pudo cargar la lista de recorridos.'),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const Key('recorridos-reintentar'),
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
        key: Key('recorridos-cargando'),
        child: CircularProgressIndicator(),
      );
    }
    if (items.isEmpty) {
      return const Center(
        key: Key('recorridos-vacio'),
        child: Text('Todavía no hay recorridos.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _fila(items[i]),
    );
  }

  Widget _fila(RecorridoGestion r) => ListTile(
    key: Key('recorrido-${r.idRecorrido}'),
    title: Text('Recorrido ${r.idRecorrido}'),
    subtitle: Text(
      r.paradas.isEmpty
          ? 'Sin paradas'
          : r.paradas.map((p) => p.etiqueta).join(' → '),
    ),
    trailing: IconButton(
      key: Key('recorrido-editar-${r.idRecorrido}'),
      tooltip: 'Modificar paradas',
      icon: const Icon(Icons.edit_outlined),
      onPressed: () => _abrirEditor(r),
    ),
  );
}

String _mensajeError(Object e) => switch (e) {
  ApiException(codigo: 'PARADA_COMPROMETIDA') =>
    'La modificación impide respetar una parada comprometida (RN-021). '
        'Elegí una alternativa que la conserve en su lugar.',
  ApiException(codigo: 'PARADA_CON_RESERVAS') =>
    'Hay reservas en una parada que querés quitar o cambiar.',
  ApiException(codigo: 'PARADA_NO_ENCONTRADA') =>
    'Alguna de las paradas ya no existe.',
  ApiException(:final mensaje) => mensaje,
  _ => 'No se pudo completar la operación. Probá de nuevo.',
};

class _ItemEditor {
  const _ItemEditor(this.idParada, this.etiqueta, this.comprometida);
  final int idParada;
  final String etiqueta;
  final bool comprometida;
}

class _EditorRecorrido extends StatefulWidget {
  const _EditorRecorrido({
    required this.existente,
    required this.listarParadas,
    required this.crearParada,
    required this.crear,
    required this.reemplazar,
  });

  final RecorridoGestion? existente;
  final ListarParadasCatalogo listarParadas;
  final CrearParadaCatalogo crearParada;
  final CrearRecorrido crear;
  final ReemplazarParadas reemplazar;

  @override
  State<_EditorRecorrido> createState() => _EditorRecorridoState();
}

class _EditorRecorridoState extends State<_EditorRecorrido> {
  late List<_ItemEditor> _items = [
    for (final p in widget.existente?.paradas ?? const <ParadaDeRecorrido>[])
      _ItemEditor(p.idParada, p.etiqueta, p.comprometida),
  ];
  late final List<int> _original = _items.map((i) => i.idParada).toList();
  List<ParadaCatalogo> _catalogo = const [];
  bool _catalogoError = false;
  bool _enviando = false;
  String? _mensaje;

  bool get _esAlta => widget.existente == null;
  bool get _cambio {
    final actual = _items.map((i) => i.idParada).toList();
    if (actual.length != _original.length) return true;
    for (var i = 0; i < actual.length; i++) {
      if (actual[i] != _original[i]) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }

  Future<void> _cargarCatalogo() async {
    try {
      final catalogo = await widget.listarParadas();
      if (mounted) {
        setState(() {
          _catalogo = catalogo;
          _catalogoError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _catalogoError = true);
    }
  }

  List<ParadaCatalogo> get _disponibles {
    final usadas = _items.map((i) => i.idParada).toSet();
    return _catalogo.where((p) => !usadas.contains(p.idParada)).toList();
  }

  void _agregar(ParadaCatalogo p) => setState(
    () => _items = [..._items, _ItemEditor(p.idParada, p.etiqueta, false)],
  );

  void _quitar(int i) => setState(() => _items = [..._items]..removeAt(i));

  void _mover(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _items.length) return;
    final copia = [..._items];
    final aux = copia[i];
    copia[i] = copia[j];
    copia[j] = aux;
    setState(() => _items = copia);
  }

  /// Una comprometida no se mueve (RN-021); tampoco una vecina puede cruzarla,
  /// porque eso cambiaría su orden.
  bool _puedeMover(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _items.length) return false;
    return !_items[i].comprometida && !_items[j].comprometida;
  }

  Future<void> _nuevaParada() async {
    final creada = await showDialog<ParadaCatalogo>(
      context: context,
      builder: (_) => _DialogoParada(crear: widget.crearParada),
    );
    if (creada == null || !mounted) return;
    setState(() => _catalogo = [..._catalogo, creada]);
    _agregar(creada);
  }

  Future<void> _guardar() async {
    if (_enviando || _items.isEmpty || !_cambio) return;
    setState(() {
      _enviando = true;
      _mensaje = null;
    });
    final ids = _items.map((i) => i.idParada).toList();
    try {
      final existente = widget.existente;
      if (existente == null) {
        await widget.crear(ids);
      } else {
        await widget.reemplazar(existente.idRecorrido, ids);
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _esAlta
            ? 'Nuevo recorrido'
            : 'Recorrido ${widget.existente!.idRecorrido}',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (_items.isEmpty)
          const Padding(
            key: Key('editor-sin-paradas'),
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text('Agregá al menos una parada.'),
          ),
        for (var i = 0; i < _items.length; i++) _fila(i),
        const SizedBox(height: AppSpacing.lg),
        _agregarParada(),
        if (_mensaje != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              _mensaje!,
              key: const Key('editor-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const Key('editor-guardar'),
          onPressed: (_enviando || _items.isEmpty || !_cambio)
              ? null
              : _guardar,
          child: Text(_esAlta ? 'Crear recorrido' : 'Guardar cambios'),
        ),
      ],
    ),
  );

  Widget _fila(int i) {
    final item = _items[i];
    return ListTile(
      key: Key('editor-parada-$i'),
      leading: CircleAvatar(child: Text('${i + 1}')),
      title: Text(item.etiqueta),
      subtitle: item.comprometida ? const Text('Comprometida (RN-021)') : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.comprometida)
            const Icon(Icons.lock_outline, key: Key('editor-candado'))
          else ...[
            IconButton(
              key: Key('editor-subir-$i'),
              tooltip: 'Subir',
              icon: const Icon(Icons.arrow_upward),
              onPressed: _puedeMover(i, -1) ? () => _mover(i, -1) : null,
            ),
            IconButton(
              key: Key('editor-bajar-$i'),
              tooltip: 'Bajar',
              icon: const Icon(Icons.arrow_downward),
              onPressed: _puedeMover(i, 1) ? () => _mover(i, 1) : null,
            ),
            IconButton(
              key: Key('editor-quitar-$i'),
              tooltip: 'Quitar',
              icon: const Icon(Icons.close),
              onPressed: () => _quitar(i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _agregarParada() {
    if (_catalogoError) {
      return OutlinedButton(
        key: const Key('editor-reintentar-catalogo'),
        onPressed: _cargarCatalogo,
        child: const Text('No se pudo cargar el catálogo. Reintentar'),
      );
    }
    final disponibles = _disponibles;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (disponibles.isNotEmpty)
          PopupMenuButton<ParadaCatalogo>(
            key: const Key('editor-agregar'),
            onSelected: _agregar,
            itemBuilder: (_) => [
              for (final p in disponibles)
                PopupMenuItem(
                  key: Key('editor-opcion-${p.idParada}'),
                  value: p,
                  child: Text(p.etiqueta),
                ),
            ],
            child: const Chip(
              avatar: Icon(Icons.add_location_alt_outlined),
              label: Text('Agregar parada existente'),
            ),
          ),
        OutlinedButton.icon(
          key: const Key('editor-nueva-parada'),
          onPressed: _nuevaParada,
          icon: const Icon(Icons.add),
          label: const Text('Nueva parada'),
        ),
      ],
    );
  }
}

class _DialogoParada extends StatefulWidget {
  const _DialogoParada({required this.crear});

  final CrearParadaCatalogo crear;

  @override
  State<_DialogoParada> createState() => _DialogoParadaState();
}

class _DialogoParadaState extends State<_DialogoParada> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _direccion = TextEditingController();
  final _latitud = TextEditingController();
  final _longitud = TextEditingController();
  bool _enviando = false;
  String? _mensaje;

  @override
  void dispose() {
    for (final c in [_nombre, _direccion, _latitud, _longitud]) {
      c.dispose();
    }
    super.dispose();
  }

  static double? _leer(String texto) =>
      double.tryParse(texto.trim().replaceAll(',', '.'));

  String? _validarCoordenada(String? v, {required double limite}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final n = _leer(t);
    return (n == null || n.abs() > limite)
        ? 'Valor entre -$limite y $limite'
        : null;
  }

  /// Latitud y longitud van juntas o ninguna.
  String? _validarPar(String? v, TextEditingController otra) =>
      (v ?? '').trim().isEmpty != otra.text.trim().isEmpty
      ? 'Informá latitud y longitud, o ninguna'
      : null;

  Future<void> _guardar() async {
    if (_enviando || !_formulario.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _mensaje = null;
    });
    try {
      final creada = await widget.crear(
        ParadaCatalogoCreate(
          nombre: _nombre.text.trim(),
          direccion: _direccion.text.trim(),
          latitud: _leer(_latitud.text),
          longitud: _leer(_longitud.text),
        ),
      );
      if (mounted) Navigator.of(context).pop(creada);
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
      key: Key('parada-campo-$clave'),
      controller: c,
      keyboardType: teclado,
      decoration: InputDecoration(labelText: etiqueta),
      validator: validar,
    ),
  );

  @override
  Widget build(BuildContext context) {
    const numerico = TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    );
    return AlertDialog(
      title: const Text('Nueva parada'),
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
                validar: (v) => (v == null || v.trim().isEmpty)
                    ? 'Campo obligatorio'
                    : null,
              ),
              _campo('direccion', 'Dirección (opcional)', _direccion),
              _campo(
                'latitud',
                'Latitud (opcional)',
                _latitud,
                teclado: numerico,
                validar: (v) =>
                    _validarCoordenada(v, limite: 90) ??
                    _validarPar(v, _longitud),
              ),
              _campo(
                'longitud',
                'Longitud (opcional)',
                _longitud,
                teclado: numerico,
                validar: (v) =>
                    _validarCoordenada(v, limite: 180) ??
                    _validarPar(v, _latitud),
              ),
              if (_mensaje != null)
                Text(
                  _mensaje!,
                  key: const Key('parada-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('parada-cancelar'),
          onPressed: _enviando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('parada-guardar'),
          onPressed: _enviando ? null : _guardar,
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
