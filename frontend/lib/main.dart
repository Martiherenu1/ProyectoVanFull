import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'core/api/api_error.dart';
import 'core/api/auth_api.dart';
import 'core/api/http_api_client.dart';
import 'core/api/pasajero_api.dart';
import 'core/navigation/role_router.dart';
import 'core/session/sesion_app.dart';
import 'core/session/sesion_controller.dart';
import 'core/theme/app_spacing.dart';
import 'models/admin/viaje_create.dart';
import 'models/chofer/operacion_asignada.dart';
import 'models/chofer/viaje_resumen.dart';
import 'screens/admin/crear_viaje_admin_screen.dart';
import 'screens/admin/viajes_dia_admin_screen.dart';
import 'screens/chofer/chofer_shell.dart';
import 'screens/pasajero/pasajero_shell.dart';
import 'services/admin/viajes_admin_api.dart';
import 'services/admin/viajes_dia_admin_api.dart';
import 'services/chofer/detalle_viaje_chofer_api.dart';
import 'services/chofer/viajes_chofer_api.dart';

/// URL base de la API, con el prefijo `/api`. En el emulador de Android el
/// host es `10.0.2.2`: `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api`.
const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000/api',
);

void main() => runApp(const VanFullBootstrap());

typedef CrearTransporteHttp = http.Client Function();

/// Compone una sola sesión y un solo transporte para todas las áreas.
class VanFullBootstrap extends StatefulWidget {
  const VanFullBootstrap({
    this.apiBaseUrl = _apiBaseUrl,
    this.crearTransporte,
    super.key,
  });

  final String apiBaseUrl;
  final CrearTransporteHttp? crearTransporte;

  @override
  State<VanFullBootstrap> createState() => _VanFullBootstrapState();
}

class _VanFullBootstrapState extends State<VanFullBootstrap> {
  late final http.Client _transporte;
  late final SesionController _sesion;
  late final PasajeroApi _pasajero;
  late final ViajesDiaAdminApi _viajesDiaAdmin;
  late final ViajesAdminApi _viajesAdmin;
  late final ViajesChoferApi _viajesChofer;
  late final DetalleViajeChoferApi _detalleChofer;

  @override
  void initState() {
    super.initState();
    _transporte = widget.crearTransporte?.call() ?? http.Client();
    late final SesionController sesion;
    final httpClient = HttpApiClient(
      baseUri: Uri.parse(widget.apiBaseUrl),
      transport: _transporte,
      accessTokenProvider: () => sesion.token,
      onNoAutorizado: (token) => sesion.invalidar(token),
    );
    final auth = AuthApi(httpClient);
    sesion = SesionController(
      iniciarSesion: auth.iniciarSesion,
      cerrarSesion: auth.cerrarSesion,
    );
    _sesion = sesion;
    _pasajero = PasajeroApi(httpClient);
    _viajesDiaAdmin = ViajesDiaAdminApi(httpClient);
    _viajesAdmin = ViajesAdminApi(httpClient);
    _viajesChofer = ViajesChoferApi(httpClient);
    _detalleChofer = DetalleViajeChoferApi(httpClient);
  }

  @override
  void dispose() {
    _sesion.dispose();
    _transporte.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SesionApp(
    controller: _sesion,
    entradaPasajero: (controller) =>
        PasajeroShell(api: _pasajero, onSalir: controller.salir),
    entradaAdministrador: (controller) => _EntradaAdministracion(
      controller: controller,
      listar: _viajesDiaAdmin,
      crear: _viajesAdmin,
      onSalir: controller.salir,
    ),
    entradaChofer: (controller) => _EntradaChofer(
      controller: controller,
      listar: _viajesChofer,
      detalle: _detalleChofer,
      onSalir: controller.salir,
    ),
  );
}

class _EntradaAdministracion extends StatefulWidget {
  const _EntradaAdministracion({
    required this.controller,
    required this.listar,
    required this.crear,
    required this.onSalir,
  });

  final SesionController controller;
  final ViajesDiaAdminApi listar;
  final ViajesAdminApi crear;
  final VoidCallback onSalir;

  @override
  State<_EntradaAdministracion> createState() => _EntradaAdministracionState();
}

class _EntradaAdministracionState extends State<_EntradaAdministracion> {
  bool _accesoDenegado = false;

  @override
  Widget build(BuildContext context) => _accesoDenegado
      ? _AccesoDenegado(
          key: const Key('admin-acceso-denegado'),
          onSalir: widget.onSalir,
        )
      : Stack(
          children: [
            ViajesDiaAdminScreen(
              fecha: DateTime.now(),
              cargarViajes: _cargarViajes,
              onViajeSeleccionado: (_) {},
            ),
            Positioned(
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: SafeArea(
                child: Row(
                  children: [
                    OutlinedButton(
                      key: const Key('admin-salir'),
                      onPressed: widget.onSalir,
                      child: const Text('Cerrar sesión'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton.icon(
                      key: const Key('admin-crear-viaje'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CrearViajeAdminScreen(crearViaje: _crearViaje),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Crear viaje'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

  Future<List<ViajeResumen>> _cargarViajes(DateTime fecha) async {
    return _protegerAcceso(
      controller: widget.controller,
      solicitud: () => widget.listar.cargarViajes(fecha),
      onAccesoDenegado: _denegarAcceso,
    );
  }

  Future<void> _crearViaje({
    required int idServicio,
    required int idRecorrido,
    required int? idVehiculo,
    required int? idChofer,
    required DateTime fecha,
    required String? horario,
    required String sentido,
    required int? capacidadPlanificada,
  }) async {
    final sentidoViaje = SentidoViaje.values.singleWhere(
      (valor) => valor.valorApi == sentido,
    );
    await _protegerAcceso(
      controller: widget.controller,
      solicitud: () => widget.crear.crearViaje(
        ViajeCreate(
          idServicio: idServicio,
          idRecorrido: idRecorrido,
          idVehiculo: idVehiculo,
          idChofer: idChofer,
          fecha: fecha,
          horario: horario,
          sentido: sentidoViaje,
          capacidadPlanificada: capacidadPlanificada,
        ),
      ),
      onAccesoDenegado: _denegarAcceso,
    );
  }

  void _denegarAcceso() {
    if (!mounted || _accesoDenegado) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _accesoDenegado = true);
  }
}

class _EntradaChofer extends StatefulWidget {
  const _EntradaChofer({
    required this.controller,
    required this.listar,
    required this.detalle,
    required this.onSalir,
  });

  final SesionController controller;
  final ViajesChoferApi listar;
  final DetalleViajeChoferApi detalle;
  final VoidCallback onSalir;

  @override
  State<_EntradaChofer> createState() => _EntradaChoferState();
}

class _EntradaChoferState extends State<_EntradaChofer> {
  bool _accesoDenegado = false;

  @override
  Widget build(BuildContext context) => _accesoDenegado
      ? _AccesoDenegado(
          key: const Key('chofer-acceso-denegado'),
          onSalir: widget.onSalir,
        )
      : ChoferShell(
          cargarViajes: _cargarViajes,
          cargarDetalle: _cargarDetalle,
          onSalir: widget.onSalir,
        );

  Future<List<ViajeResumen>> _cargarViajes(DateTime fecha) => _protegerAcceso(
    controller: widget.controller,
    solicitud: () => widget.listar.cargarViajes(fecha),
    onAccesoDenegado: _denegarAcceso,
  );

  Future<OperacionAsignada?> _cargarDetalle(int idViaje) => _protegerAcceso(
    controller: widget.controller,
    solicitud: () => widget.detalle.cargarDetalle(idViaje),
    onAccesoDenegado: _denegarAcceso,
  );

  void _denegarAcceso() {
    if (!mounted || _accesoDenegado) return;
    setState(() => _accesoDenegado = true);
  }
}

class _AccesoDenegado extends StatelessWidget {
  const _AccesoDenegado({required this.onSalir, super.key});

  final VoidCallback onSalir;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Acceso denegado.'),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: onSalir,
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    ),
  );
}

Future<T> _protegerAcceso<T>({
  required SesionController controller,
  required Future<T> Function() solicitud,
  required VoidCallback onAccesoDenegado,
}) async {
  final generacion = controller.generacion;
  final token = controller.token;
  try {
    return await solicitud();
  } on ApiException catch (error) {
    if (error.statusCode == 403 &&
        controller.generacion == generacion &&
        controller.token == token) {
      onAccesoDenegado();
    }
    rethrow;
  }
}

class VanFullApp extends StatelessWidget {
  const VanFullApp({
    this.roles = const [],
    this.fechaAdmin,
    this.cargarViajesAdmin,
    this.onViajeAdminSeleccionado,
    super.key,
  });

  final List<String> roles;
  final DateTime? fechaAdmin;
  final CargarViajesDelDia? cargarViajesAdmin;
  final ValueChanged<int>? onViajeAdminSeleccionado;

  @override
  Widget build(BuildContext context) {
    return RoleRouter(
      roles: roles,
      fechaAdmin: fechaAdmin,
      cargarViajesAdmin: cargarViajesAdmin,
      onViajeAdminSeleccionado: onViajeAdminSeleccionado,
    );
  }
}
