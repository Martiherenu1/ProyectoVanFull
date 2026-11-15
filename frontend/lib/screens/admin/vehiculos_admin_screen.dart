import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../models/admin/vehiculo_admin.dart';

typedef CargarVehiculos = Future<List<VehiculoAdmin>> Function();
typedef CrearVehiculo = Future<VehiculoAdmin> Function(VehiculoCreate datos);
typedef ActualizarVehiculo = Future<VehiculoAdmin> Function(
  int idVehiculo,
  VehiculoUpdate datos,
);

class VehiculosAdminScreen extends StatefulWidget {
  const VehiculosAdminScreen({
    required this.cargar,
    required this.crear,
    required this.actualizar,
    super.key,
  });

  final CargarVehiculos cargar;
  final CrearVehiculo crear;
  final ActualizarVehiculo actualizar;

  @override
  State<VehiculosAdminScreen> createState() => _VehiculosAdminScreenState();
}

class _VehiculosAdminScreenState extends State<VehiculosAdminScreen> {
  List<VehiculoAdmin> _vehiculos = const [];
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
      final vehiculos = await widget.cargar();
      if (!mounted) return;
      setState(() {
        _vehiculos = List.unmodifiable(vehiculos);
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
        _error = 'No pudimos cargar los vehículos. Volvé a intentar.';
      });
    }
  }

  Future<void> _abrirFormulario([VehiculoAdmin? vehiculo]) async {
    final guardado = await showDialog<VehiculoAdmin>(
      context: context,
      builder: (_) => _FormularioVehiculo(
        vehiculo: vehiculo,
        guardar:
            ({
              required patente,
              required marca,
              required modelo,
              required capacidad,
              required disponibilidad,
            }) => vehiculo == null
            ? widget.crear(
                VehiculoCreate(
                  patente: patente,
                  marca: marca,
                  modelo: modelo,
                  capacidad: capacidad,
                  disponibilidad: disponibilidad,
                ),
              )
            : widget.actualizar(
                vehiculo.idVehiculo,
                VehiculoUpdate(
                  patente: patente,
                  marca: marca,
                  modelo: modelo,
                  capacidad: capacidad,
                  disponibilidad: disponibilidad,
                ),
              ),
      ),
    );
    if (!mounted || guardado == null) return;
    final actualizados = [..._vehiculos];
    final indice = actualizados.indexWhere(
      (item) => item.idVehiculo == guardado.idVehiculo,
    );
    if (indice == -1) {
      actualizados.add(guardado);
    } else {
      actualizados[indice] = guardado;
    }
    actualizados.sort((a, b) => a.idVehiculo.compareTo(b.idVehiculo));
    setState(() => _vehiculos = List.unmodifiable(actualizados));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Administrar vehículos'),
      actions: [
        IconButton(
          key: const Key('actualizar-vehiculos'),
          tooltip: 'Actualizar vehículos',
          onPressed: _cargando ? null : _cargar,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('registrar-vehiculo'),
      onPressed: () => _abrirFormulario(),
      icon: const Icon(Icons.add),
      label: const Text('Registrar vehículo'),
    ),
    body: _contenido(),
  );

  Widget _contenido() {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Cargando vehículos'),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, key: const Key('error-vehiculos')),
            const SizedBox(height: 16),
            FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_vehiculos.isEmpty) {
      return const Center(child: Text('No hay vehículos registrados.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _vehiculos.length,
      itemBuilder: (context, index) {
        final vehiculo = _vehiculos[index];
        final descripcion = [
          if (vehiculo.marca != null) vehiculo.marca!,
          if (vehiculo.modelo != null) vehiculo.modelo!,
        ].join(' ');
        return Card(
          key: Key('vehiculo-${vehiculo.idVehiculo}'),
          child: ListTile(
            title: Text(vehiculo.patente),
            subtitle: Text(
              '${descripcion.isEmpty ? 'Sin marca ni modelo' : descripcion}\n'
              'Capacidad: ${vehiculo.capacidad} · '
              '${vehiculo.disponibilidad ? 'Disponible' : 'No disponible'}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              key: Key('editar-vehiculo-${vehiculo.idVehiculo}'),
              tooltip: 'Modificar ${vehiculo.patente}',
              onPressed: () => _abrirFormulario(vehiculo),
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        );
      },
    );
  }
}

typedef _GuardarVehiculo = Future<VehiculoAdmin> Function({
  required String patente,
  required String? marca,
  required String? modelo,
  required int capacidad,
  required bool disponibilidad,
});

class _FormularioVehiculo extends StatefulWidget {
  const _FormularioVehiculo({required this.vehiculo, required this.guardar});

  final VehiculoAdmin? vehiculo;
  final _GuardarVehiculo guardar;

  @override
  State<_FormularioVehiculo> createState() => _FormularioVehiculoState();
}

class _FormularioVehiculoState extends State<_FormularioVehiculo> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _patente;
  late final TextEditingController _marca;
  late final TextEditingController _modelo;
  late final TextEditingController _capacidad;
  late bool _disponibilidad;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final vehiculo = widget.vehiculo;
    _patente = TextEditingController(text: vehiculo?.patente ?? '');
    _marca = TextEditingController(text: vehiculo?.marca ?? '');
    _modelo = TextEditingController(text: vehiculo?.modelo ?? '');
    _capacidad = TextEditingController(
      text: vehiculo == null ? '' : '${vehiculo.capacidad}',
    );
    _disponibilidad = vehiculo?.disponibilidad ?? true;
  }

  String? _requerido(String? valor) => valor == null || valor.trim().isEmpty
      ? 'Este campo es obligatorio.'
      : null;

  String? _capacidadValida(String? valor) {
    final numero = int.tryParse(valor?.trim() ?? '');
    return numero == null || numero < 1
        ? 'Indicá una capacidad mayor que cero.'
        : null;
  }

  String? _opcional(String? valor, int maximo) =>
      (valor?.trim().length ?? 0) > maximo
      ? 'Máximo $maximo caracteres.'
      : null;

  String? _nuloSiVacio(String valor) {
    final limpio = valor.trim();
    return limpio.isEmpty ? null : limpio;
  }

  Future<void> _guardar() async {
    if (_guardando || !_formulario.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final vehiculo = await widget.guardar(
        patente: _patente.text.trim(),
        marca: _nuloSiVacio(_marca.text),
        modelo: _nuloSiVacio(_modelo.text),
        capacidad: int.parse(_capacidad.text.trim()),
        disponibilidad: _disponibilidad,
      );
      if (mounted) Navigator.of(context).pop(vehiculo);
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
        _error = 'No pudimos guardar el vehículo. Volvé a intentar.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.vehiculo == null ? 'Registrar vehículo' : 'Modificar vehículo',
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('vehiculo-patente'),
                controller: _patente,
                maxLength: 10,
                decoration: const InputDecoration(labelText: 'Patente'),
                validator: _requerido,
              ),
              TextFormField(
                key: const Key('vehiculo-marca'),
                controller: _marca,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Marca (opcional)',
                ),
                validator: (valor) => _opcional(valor, 50),
              ),
              TextFormField(
                key: const Key('vehiculo-modelo'),
                controller: _modelo,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Modelo (opcional)',
                ),
                validator: (valor) => _opcional(valor, 50),
              ),
              TextFormField(
                key: const Key('vehiculo-capacidad'),
                controller: _capacidad,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Capacidad'),
                validator: _capacidadValida,
              ),
              SwitchListTile(
                key: const Key('vehiculo-disponibilidad'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Disponible'),
                value: _disponibilidad,
                onChanged: _guardando
                    ? null
                    : (valor) => setState(() => _disponibilidad = valor),
              ),
              if (_error != null)
                Text(_error!, key: const Key('error-guardar-vehiculo')),
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
        key: const Key('guardar-vehiculo'),
        onPressed: _guardando ? null : _guardar,
        child: Text(_guardando ? 'Guardando…' : 'Guardar'),
      ),
    ],
  );

  @override
  void dispose() {
    _patente.dispose();
    _marca.dispose();
    _modelo.dispose();
    _capacidad.dispose();
    super.dispose();
  }
}
