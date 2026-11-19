import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/admin/abono_gestion.dart';

typedef ListarAbonos = Future<List<AbonoGestion>> Function(int? idPasajero);
typedef ListarServiciosAbono = Future<List<ServicioAbono>> Function();
typedef CrearAbono = Future<AbonoGestion> Function(AbonoGestionCreate datos);
typedef ModificarAbono = Future<AbonoGestion> Function(
  int id,
  Map<String, Object?> cambios,
);
typedef AgregarPeriodo = Future<AbonoGestion> Function(int id, String periodo);

/// CU-028: administración y dueño gestionan abonos mensuales.
///
/// Alta, consulta, modalidad y días, y períodos. Sin estados editables,
/// advertencia/suspensión ni habilitación excepcional: la v1.3 los deja
/// pendientes. Pagos y deuda se gestionan en otros casos de uso.
class AbonosAdminScreen extends StatefulWidget {
  const AbonosAdminScreen({
    required this.listar,
    required this.listarServicios,
    required this.crear,
    required this.modificar,
    required this.agregarPeriodo,
    super.key,
  });

  final ListarAbonos listar;
  final ListarServiciosAbono listarServicios;
  final CrearAbono crear;
  final ModificarAbono modificar;
  final AgregarPeriodo agregarPeriodo;

  @override
  State<AbonosAdminScreen> createState() => _AbonosAdminScreenState();
}

class _AbonosAdminScreenState extends State<AbonosAdminScreen> {
  final _filtroPasajero = TextEditingController();
  int? _idPasajero;
  List<AbonoGestion>? _items;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _filtroPasajero.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _items = null;
      _error = false;
    });
    try {
      final items = await widget.listar(_idPasajero);
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _filtrar() {
    final texto = _filtroPasajero.text.trim();
    _idPasajero = texto.isEmpty ? null : int.tryParse(texto);
    _cargar();
  }

  Future<void> _abrirAlta() async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoAbono(
        listarServicios: widget.listarServicios,
        crear: widget.crear,
      ),
    );
    if (guardado == true) await _cargar();
  }

  Future<void> _modificar(AbonoGestion a) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoModificar(abono: a, modificar: widget.modificar),
    );
    if (guardado == true) await _cargar();
  }

  Future<void> _agregarPeriodo(AbonoGestion a) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoPeriodo(abono: a, agregar: widget.agregarPeriodo),
    );
    if (guardado == true) await _cargar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Abonos mensuales')),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('abonos-nuevo'),
      onPressed: _abrirAlta,
      icon: const Icon(Icons.add),
      label: const Text('Nuevo abono'),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('abonos-filtro-pasajero'),
                  controller: _filtroPasajero,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'N.º de pasajero (opcional)',
                  ),
                  onSubmitted: (_) => _filtrar(),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              FilledButton(
                key: const Key('abonos-buscar'),
                onPressed: _filtrar,
                child: const Text('Buscar'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _cuerpo()),
      ],
    ),
  );

  Widget _cuerpo() {
    if (_error) {
      return Center(
        key: const Key('abonos-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No se pudo cargar la lista de abonos.'),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const Key('abonos-reintentar'),
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
        key: Key('abonos-cargando'),
        child: CircularProgressIndicator(),
      );
    }
    if (items.isEmpty) {
      return const Center(
        key: Key('abonos-vacio'),
        child: Text('No se encontraron abonos.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _fila(items[i]),
    );
  }

  Widget _fila(AbonoGestion a) {
    final periodos = a.periodos.map((p) => p.periodo).join(', ');
    return ListTile(
      key: Key('abono-${a.idAbonoMensual}'),
      isThreeLine: true,
      title: Text('${a.pasajero} · ${a.tipoServicio}'),
      subtitle: Text(
        '${modalidadesAbono[a.modalidad] ?? 'Sin modalidad'}'
        '${a.diasSemanales == null ? '' : ' · ${a.diasSemanales}'}'
        ' · ${a.estado}\n'
        'Períodos: ${periodos.isEmpty ? 'ninguno' : periodos}',
      ),
      trailing: Wrap(
        children: [
          IconButton(
            key: Key('abono-periodo-${a.idAbonoMensual}'),
            tooltip: 'Agregar período',
            icon: const Icon(Icons.event_available_outlined),
            onPressed: () => _agregarPeriodo(a),
          ),
          IconButton(
            key: Key('abono-editar-${a.idAbonoMensual}'),
            tooltip: 'Modificar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _modificar(a),
          ),
        ],
      ),
    );
  }
}

String _mensajeError(Object e) => switch (e) {
  ApiException(codigo: 'PASAJERO_NO_ENCONTRADO') =>
    'No existe un pasajero con ese número.',
  ApiException(codigo: 'PASAJERO_DADO_DE_BAJA') =>
    'El pasajero está dado de baja.',
  ApiException(codigo: 'SERVICIO_SIN_ABONO') =>
    'Solo los servicios universitarios y laborales tienen abono.',
  ApiException(codigo: 'SERVICIO_NO_ENCONTRADO') =>
    'El servicio elegido ya no existe.',
  ApiException(codigo: 'ABONO_NO_ENCONTRADO') => 'El abono ya no existe.',
  ApiException(codigo: 'PERIODO_DUPLICADO') => 'El abono ya tiene ese período.',
  ApiException(statusCode: 403) => 'No tenés permiso para gestionar abonos.',
  ApiException(:final mensaje) => mensaje,
  _ => 'No se pudo completar la operación. Probá de nuevo.',
};

String? _obligatorio(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;

String? _validarPeriodo(String? v, {required bool obligatorio}) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return obligatorio ? 'Campo obligatorio' : null;
  return periodoValido(t) ? null : 'Formato AAAA-MM';
}

class _DialogoAbono extends StatefulWidget {
  const _DialogoAbono({required this.listarServicios, required this.crear});

  final ListarServiciosAbono listarServicios;
  final CrearAbono crear;

  @override
  State<_DialogoAbono> createState() => _DialogoAbonoState();
}

class _DialogoAbonoState extends State<_DialogoAbono> {
  final _formulario = GlobalKey<FormState>();
  final _pasajero = TextEditingController();
  final _dias = TextEditingController();
  final _importe = TextEditingController();
  final _periodo = TextEditingController();
  List<ServicioAbono>? _servicios;
  int? _idServicio;
  String _modalidad = 'IDA_VUELTA';
  bool _enviando = false;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    widget
        .listarServicios()
        .then((todos) {
          if (!mounted) return;
          setState(
            () => _servicios = todos
                .where((s) => s.admiteAbono)
                .toList(growable: false),
          );
        })
        .catchError((Object _) {
          if (mounted) {
            setState(() {
              _servicios = const [];
              _mensaje = 'No se pudieron cargar los servicios.';
            });
          }
        });
  }

  @override
  void dispose() {
    for (final c in [_pasajero, _dias, _importe, _periodo]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Acepta coma o punto; máximo dos decimales (la columna es NUMERIC(12,2)).
  static double? _leerImporte(String texto) {
    final limpio = texto.trim().replaceAll(',', '.');
    if (limpio.isEmpty) return null;
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(limpio)) return double.nan;
    return double.parse(limpio);
  }

  Future<void> _guardar() async {
    if (_enviando || !_formulario.currentState!.validate()) return;
    if (_idServicio == null) {
      setState(() => _mensaje = 'Elegí un servicio.');
      return;
    }
    setState(() {
      _enviando = true;
      _mensaje = null;
    });
    try {
      final periodo = _periodo.text.trim();
      await widget.crear(
        AbonoGestionCreate(
          idPasajero: int.parse(_pasajero.text.trim()),
          idServicio: _idServicio!,
          modalidad: _modalidad,
          diasSemanales: _dias.text.trim(),
          importeAcordado: _leerImporte(_importe.text),
          periodo: periodo.isEmpty ? null : periodo,
        ),
      );
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
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nuevo abono'),
    content: SingleChildScrollView(
      child: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('abono-campo-pasajero'),
              controller: _pasajero,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'N.º de pasajero'),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                return (n == null || n <= 0) ? 'Número válido' : null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_servicios == null)
              const LinearProgressIndicator(
                key: Key('abono-servicios-cargando'),
              )
            else
              DropdownButtonFormField<int>(
                key: const Key('abono-campo-servicio'),
                initialValue: _idServicio,
                decoration: const InputDecoration(labelText: 'Servicio'),
                items: [
                  for (final s in _servicios!)
                    DropdownMenuItem(
                      value: s.idServicio,
                      child: Text('${s.tipo} (${s.idServicio})'),
                    ),
                ],
                onChanged: (v) => setState(() => _idServicio = v),
              ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              key: const Key('abono-campo-modalidad'),
              initialValue: _modalidad,
              decoration: const InputDecoration(labelText: 'Modalidad'),
              items: [
                for (final m in modalidadesAbono.entries)
                  DropdownMenuItem(value: m.key, child: Text(m.value)),
              ],
              onChanged: (v) => setState(() => _modalidad = v ?? _modalidad),
            ),
            TextFormField(
              key: const Key('abono-campo-dias'),
              controller: _dias,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'Días (ej. L,M,X,J,V)',
              ),
              validator: _obligatorio,
            ),
            TextFormField(
              key: const Key('abono-campo-importe'),
              controller: _importe,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Importe acordado (opcional)',
              ),
              validator: (v) {
                final n = _leerImporte(v ?? '');
                return (n != null && n.isNaN)
                    ? 'Importe válido, con hasta 2 decimales'
                    : null;
              },
            ),
            TextFormField(
              key: const Key('abono-campo-periodo'),
              controller: _periodo,
              decoration: const InputDecoration(
                labelText: 'Primer período (opcional, AAAA-MM)',
              ),
              validator: (v) => _validarPeriodo(v, obligatorio: false),
            ),
            if (_mensaje != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  _mensaje!,
                  key: const Key('abono-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        key: const Key('abono-cancelar'),
        onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('abono-guardar'),
        onPressed: _enviando ? null : _guardar,
        child: const Text('Crear'),
      ),
    ],
  );
}

class _DialogoModificar extends StatefulWidget {
  const _DialogoModificar({required this.abono, required this.modificar});

  final AbonoGestion abono;
  final ModificarAbono modificar;

  @override
  State<_DialogoModificar> createState() => _DialogoModificarState();
}

class _DialogoModificarState extends State<_DialogoModificar> {
  final _formulario = GlobalKey<FormState>();
  late final _dias = TextEditingController(text: widget.abono.diasSemanales);
  late String? _modalidad = widget.abono.modalidad;
  bool _enviando = false;
  String? _mensaje;

  @override
  void dispose() {
    _dias.dispose();
    super.dispose();
  }

  Map<String, Object?> _cambios() => {
    if (_modalidad != null && _modalidad != widget.abono.modalidad)
      'modalidad': _modalidad,
    if (_dias.text.trim() != (widget.abono.diasSemanales ?? ''))
      'dias_semanales': _dias.text.trim(),
  };

  Future<void> _guardar() async {
    if (_enviando || !_formulario.currentState!.validate()) return;
    final cambios = _cambios();
    if (cambios.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _enviando = true;
      _mensaje = null;
    });
    try {
      await widget.modificar(widget.abono.idAbonoMensual, cambios);
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
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Modificar abono de ${widget.abono.pasajero}'),
    content: Form(
      key: _formulario,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            key: const Key('abono-mod-modalidad'),
            initialValue: _modalidad,
            decoration: const InputDecoration(labelText: 'Modalidad'),
            items: [
              for (final m in modalidadesAbono.entries)
                DropdownMenuItem(value: m.key, child: Text(m.value)),
            ],
            onChanged: (v) => setState(() => _modalidad = v),
          ),
          TextFormField(
            key: const Key('abono-mod-dias'),
            controller: _dias,
            maxLength: 30,
            decoration: const InputDecoration(labelText: 'Días'),
            validator: _obligatorio,
          ),
          if (_mensaje != null)
            Text(
              _mensaje!,
              key: const Key('abono-mod-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('abono-mod-guardar'),
        onPressed: _enviando ? null : _guardar,
        child: const Text('Guardar'),
      ),
    ],
  );
}

class _DialogoPeriodo extends StatefulWidget {
  const _DialogoPeriodo({required this.abono, required this.agregar});

  final AbonoGestion abono;
  final AgregarPeriodo agregar;

  @override
  State<_DialogoPeriodo> createState() => _DialogoPeriodoState();
}

class _DialogoPeriodoState extends State<_DialogoPeriodo> {
  final _formulario = GlobalKey<FormState>();
  final _periodo = TextEditingController();
  bool _enviando = false;
  String? _mensaje;

  @override
  void dispose() {
    _periodo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_enviando || !_formulario.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _mensaje = null;
    });
    try {
      await widget.agregar(widget.abono.idAbonoMensual, _periodo.text.trim());
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
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Período para ${widget.abono.pasajero}'),
    content: Form(
      key: _formulario,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            key: const Key('periodo-campo'),
            controller: _periodo,
            decoration: const InputDecoration(labelText: 'Período (AAAA-MM)'),
            validator: (v) => _validarPeriodo(v, obligatorio: true),
          ),
          if (_mensaje != null)
            Text(
              _mensaje!,
              key: const Key('periodo-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('periodo-guardar'),
        onPressed: _enviando ? null : _guardar,
        child: const Text('Agregar'),
      ),
    ],
  );
}
