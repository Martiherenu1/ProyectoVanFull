import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';

/// Función inyectable para crear un viaje con los campos de `ViajeCreate`.
typedef CrearViaje = Future<void> Function({
  required int idServicio,
  required int idRecorrido,
  required int? idVehiculo,
  required int? idChofer,
  required DateTime fecha,
  required String? horario,
  required String sentido,
  required int? capacidadPlanificada,
});

class CrearViajeAdminScreen extends StatefulWidget {
  const CrearViajeAdminScreen({required this.crearViaje, super.key});

  final CrearViaje crearViaje;

  @override
  State<CrearViajeAdminScreen> createState() => _CrearViajeAdminScreenState();
}

class _CrearViajeAdminScreenState extends State<CrearViajeAdminScreen> {
  final _formulario = GlobalKey<FormState>();
  final _servicio = TextEditingController();
  final _recorrido = TextEditingController();
  final _vehiculo = TextEditingController();
  final _chofer = TextEditingController();
  final _fecha = TextEditingController();
  final _horario = TextEditingController();
  final _capacidad = TextEditingController();

  String? _sentido;
  bool _enviando = false;
  bool _exito = false;
  bool _error = false;

  @override
  void dispose() {
    _servicio.dispose();
    _recorrido.dispose();
    _vehiculo.dispose();
    _chofer.dispose();
    _fecha.dispose();
    _horario.dispose();
    _capacidad.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando || !_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _enviando = true;
      _exito = false;
      _error = false;
    });

    try {
      await widget.crearViaje(
        idServicio: int.parse(_servicio.text.trim()),
        idRecorrido: int.parse(_recorrido.text.trim()),
        idVehiculo: _enteroOpcional(_vehiculo.text),
        idChofer: _enteroOpcional(_chofer.text),
        fecha: _fechaIso(_fecha.text.trim())!,
        horario: _textoOpcional(_horario.text),
        sentido: _sentido!,
        capacidadPlanificada: _enteroOpcional(_capacidad.text),
      );
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _exito = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.admin,
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Crear viaje')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Form(
                  key: _formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Datos del viaje',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _campoEntero(
                        key: const Key('id-servicio'),
                        controller: _servicio,
                        label: 'Servicio (ID)',
                        obligatorio: true,
                      ),
                      _campoEntero(
                        key: const Key('id-recorrido'),
                        controller: _recorrido,
                        label: 'Recorrido (ID)',
                        obligatorio: true,
                      ),
                      _campoEntero(
                        key: const Key('id-vehiculo'),
                        controller: _vehiculo,
                        label: 'Vehículo (ID, opcional)',
                        obligatorio: false,
                      ),
                      _campoEntero(
                        key: const Key('id-chofer'),
                        controller: _chofer,
                        label: 'Chofer (ID, opcional)',
                        obligatorio: false,
                      ),
                      TextFormField(
                        key: const Key('fecha'),
                        controller: _fecha,
                        decoration: const InputDecoration(
                          labelText: 'Fecha (AAAA-MM-DD)',
                        ),
                        validator: _validarFecha,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        key: const Key('horario'),
                        controller: _horario,
                        decoration: const InputDecoration(
                          labelText: 'Horario (opcional)',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        key: const Key('sentido'),
                        initialValue: _sentido,
                        decoration: const InputDecoration(labelText: 'Sentido'),
                        items: const [
                          DropdownMenuItem(value: 'IDA', child: Text('Ida')),
                          DropdownMenuItem(
                            value: 'VUELTA',
                            child: Text('Vuelta'),
                          ),
                        ],
                        onChanged: _enviando
                            ? null
                            : (valor) => setState(() => _sentido = valor),
                        validator: (valor) =>
                            valor == null ? 'Seleccioná un sentido.' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _campoEntero(
                        key: const Key('capacidad-planificada'),
                        controller: _capacidad,
                        label: 'Capacidad planificada (opcional)',
                        obligatorio: false,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      ElevatedButton(
                        key: const Key('crear-viaje'),
                        onPressed: _enviando ? null : _enviar,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, AppSpacing.adminRowHeight),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _enviando ? 'Creando viaje…' : 'Crear viaje',
                        ),
                      ),
                      if (_exito) ...[
                        const SizedBox(height: AppSpacing.lg),
                        const Text(
                          'Viaje creado correctamente.',
                          key: Key('creacion-exitosa'),
                        ),
                      ],
                      if (_error) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'No pudimos crear el viaje. Volvé a intentar.',
                          key: const Key('creacion-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _campoEntero({
    required Key key,
    required TextEditingController controller,
    required String label,
    required bool obligatorio,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextFormField(
      key: key,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      decoration: InputDecoration(labelText: label),
      validator: (valor) => _validarEntero(valor, obligatorio: obligatorio),
    ),
  );

  static String? _validarEntero(String? valor, {required bool obligatorio}) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return obligatorio ? 'Campo obligatorio.' : null;
    return int.tryParse(texto) == null ? 'Ingresá un número entero.' : null;
  }

  static String? _validarFecha(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Campo obligatorio.';
    return _fechaIso(texto) == null ? 'Usá el formato AAAA-MM-DD.' : null;
  }

  static DateTime? _fechaIso(String texto) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(texto)) return null;
    final fecha = DateTime.tryParse(texto);
    if (fecha == null ||
        fecha.year != int.parse(texto.substring(0, 4)) ||
        fecha.month != int.parse(texto.substring(5, 7)) ||
        fecha.day != int.parse(texto.substring(8, 10))) {
      return null;
    }
    return fecha;
  }

  static int? _enteroOpcional(String valor) {
    final texto = valor.trim();
    return texto.isEmpty ? null : int.parse(texto);
  }

  static String? _textoOpcional(String valor) {
    final texto = valor.trim();
    return texto.isEmpty ? null : texto;
  }
}
