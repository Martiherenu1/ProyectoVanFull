import 'models/gps/ubicacion_viaje.dart';
import 'core/maps/configuracion_mapa.dart';
import 'widgets/gps/mapa_ultima_posicion.dart';
import 'adapters/chofer/captura_gps_android.dart';
import 'controllers/chofer/seguimiento_gps_controller.dart';
import 'screens/chofer/panel_gps.dart';
import 'screens/gps/ubicacion_screen.dart';
import 'services/gps/ubicacion_api.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'adapters/chofer/comprobador_ubicacion_android.dart';
import 'controllers/chofer/ejecucion_viaje_controller.dart';
import 'controllers/chofer/asistencia_ubicacion_inicio.dart';
import 'core/api/api_error.dart';
import 'core/api/auth_api.dart';
import 'core/api/http_api_client.dart';
import 'core/api/pasajero_api.dart';
import 'core/navigation/role_router.dart';
import 'core/session/sesion_app.dart';
import 'core/session/sesion_controller.dart';
import 'core/theme/app_spacing.dart';
import 'models/admin/viaje_create.dart';
import 'models/admin/viaje_update.dart';
import 'models/chofer/operacion_asignada.dart';
import 'models/chofer/viaje_resumen.dart';
import 'screens/admin/crear_viaje_admin_screen.dart';
import 'screens/admin/viajes_dia_admin_screen.dart';
import 'screens/chofer/chofer_shell.dart';
import 'screens/pasajero/pasajero_shell.dart';
import 'services/admin/viajes_admin_api.dart';
import 'services/admin/registro_pagos_admin_api.dart';
import 'screens/admin/registrar_pago_admin_screen.dart';
import 'services/admin/pagos_admin_api.dart';
import 'services/admin/deuda_admin_api.dart';
import 'screens/admin/consultar_deuda_admin_screen.dart';
import 'screens/admin/pagos_pendientes_screen.dart';
import 'models/admin/pago_admin.dart';
import 'services/admin/viajes_dia_admin_api.dart';
import 'services/chofer/detalle_viaje_chofer_api.dart';
import 'services/chofer/ejecucion_viaje_api.dart';
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
    this.comprobarUbicacionInicio,
    this.asistenciaUbicacionInicio,
    this.configuracionMapa,
    this.prepararMapa,
    this.crearVisorMapa,
    super.key,
  });

  final String apiBaseUrl;
  final CrearTransporteHttp? crearTransporte;
  final ComprobarUbicacionInicio? comprobarUbicacionInicio;
  final AsistenciaUbicacionInicio? asistenciaUbicacionInicio;

  // Reemplazos del visor/loader para verificar la composición sin Maps real.
  final ConfiguracionMapa? configuracionMapa;
  final PrepararMapa? prepararMapa;
  final ConstructorVisorMapa? crearVisorMapa;

  @override
  State<VanFullBootstrap> createState() => _VanFullBootstrapState();
}

class _VanFullBootstrapState extends State<VanFullBootstrap> {
  late final http.Client _transporte;
  late final SesionController _sesion;
  late final PasajeroApi _pasajero;
  late final ViajesDiaAdminApi _viajesDiaAdmin;
  late final ViajesAdminApi _viajesAdmin;
  late final RegistroPagosAdminApi _registroPagosAdmin;
  late final PagosAdminApi _pagosAdmin;
  late final DeudaAdminApi _deudaAdmin;
  late final ViajesChoferApi _viajesChofer;
  late final DetalleViajeChoferApi _detalleChofer;
  late final EjecucionViajeApi _ejecucionChofer;
  late final UbicacionApi _gpsApi;
  late final ComprobarUbicacionInicio _comprobarUbicacion;
  late final AsistenciaUbicacionInicio? _asistenciaUbicacion;

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
    _registroPagosAdmin = RegistroPagosAdminApi(httpClient);
    _pagosAdmin = PagosAdminApi(httpClient);
    _deudaAdmin = DeudaAdminApi(httpClient);
    _viajesChofer = ViajesChoferApi(httpClient);
    _detalleChofer = DetalleViajeChoferApi(httpClient);
    _ejecucionChofer = EjecucionViajeApi(httpClient);
    _gpsApi = UbicacionApi(httpClient);
    final comprobador = ComprobadorUbicacionAndroid();
    _comprobarUbicacion =
        widget.comprobarUbicacionInicio ??
        () {
          if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
            throw UnsupportedError(
              'El inicio requiere comprobar ubicación en Android.',
            );
          }
          return comprobador.comprobar();
        };
    // Comprobar no solicita permisos ni abre Ajustes. Esas acciones solo se
    // invocan desde botones explícitos, y nunca desencadenan la escritura.
    _asistenciaUbicacion =
        widget.asistenciaUbicacionInicio ??
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? AsistenciaUbicacionInicio(
                solicitarPermiso: comprobador.solicitarPermiso,
                abrirAjustesApp: comprobador.abrirAjustesApp,
                abrirAjustesUbicacion: comprobador.abrirAjustesUbicacion,
              )
            : null);
  }

  @override
  void dispose() {
    _sesion.dispose();
    _transporte.close();
    super.dispose();
  }

  /// Ubicación del viaje de una reserva consolidada (RN-030). A diferencia de
  /// Administración, un 403 acá no cierra la sesión: significa que esa reserva
  /// no da acceso, y la pantalla lo muestra como «ubicación no disponible».
  Widget _pantallaUbicacionPasajero(SesionController controller, int idViaje) {
    final sesion = controller.sesion;
    final generacion = controller.generacion;
    bool vigente() =>
        mounted &&
        controller.generacion == generacion &&
        identical(controller.sesion, sesion);
    return UbicacionScreen(
      idViaje: idViaje,
      consultar: (viaje) {
        if (!vigente()) {
          throw StateError('La sesión de esta vista ya no está vigente.');
        }
        return _gpsApi.consultar(viaje);
      },
      alcance: Object(),
      invalidaciones: controller,
      contextoVigente: vigente,
      configuracionMapa: widget.configuracionMapa,
      prepararMapa: widget.prepararMapa,
      crearVisorMapa: widget.crearVisorMapa,
    );
  }

  @override
  Widget build(BuildContext context) => SesionApp(
    controller: _sesion,
    entradaPasajero: (controller) => PasajeroShell(
      api: _pasajero,
      onSalir: controller.salir,
      pantallaUbicacion: (idViaje) =>
          _pantallaUbicacionPasajero(controller, idViaje),
    ),
    entradaAdministrador: (controller) => _EntradaAdministracion(
      controller: controller,
      listar: _viajesDiaAdmin,
      crear: _viajesAdmin,
      registrarPagos: _registroPagosAdmin,
      pagos: _pagosAdmin,
      deuda: _deudaAdmin,
      configuracionMapa: widget.configuracionMapa,
      prepararMapa: widget.prepararMapa,
      crearVisorMapa: widget.crearVisorMapa,
      gpsApi: _gpsApi,
      onSalir: controller.salir,
    ),
    entradaChofer: (controller) => _EntradaChofer(
      controller: controller,
      listar: _viajesChofer,
      detalle: _detalleChofer,
      ejecucion: _ejecucionChofer,
      gpsApi: _gpsApi,
      comprobarUbicacion: _comprobarUbicacion,
      asistenciaUbicacion: _asistenciaUbicacion,
      onSalir: controller.salir,
    ),
  );
}

class _EntradaAdministracion extends StatefulWidget {
  const _EntradaAdministracion({
    required this.controller,
    required this.listar,
    required this.crear,
    required this.registrarPagos,
    required this.pagos,
    required this.deuda,
    required this.configuracionMapa,
    required this.prepararMapa,
    required this.crearVisorMapa,
    required this.gpsApi,
    required this.onSalir,
  });

  final SesionController controller;
  final ViajesDiaAdminApi listar;
  final ViajesAdminApi crear;
  final RegistroPagosAdminApi registrarPagos;
  final PagosAdminApi pagos;
  final DeudaAdminApi deuda;
  final ConfiguracionMapa? configuracionMapa;
  final PrepararMapa? prepararMapa;
  final ConstructorVisorMapa? crearVisorMapa;
  final UbicacionApi gpsApi;
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
              onViajeSeleccionado: _abrirUbicacion,
              actualizarViaje: _actualizarViaje,
              cancelarViaje: _cancelarViaje,
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: SafeArea(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton(
                      key: const Key('admin-salir'),
                      onPressed: widget.onSalir,
                      child: const Text('Cerrar sesión'),
                    ),
                    OutlinedButton(
                      key: const Key('admin-pagos-pendientes'),
                      onPressed: _abrirPagos,
                      child: const Text('Pagos pendientes'),
                    ),
                    OutlinedButton(
                      key: const Key('admin-consultar-deuda'),
                      onPressed: _abrirDeuda,
                      child: const Text('Consultar deuda'),
                    ),
                    OutlinedButton(
                      key: const Key('admin-registrar-pago'),
                      onPressed: _abrirRegistroPago,
                      child: const Text('Registrar pago'),
                    ),
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

  void _abrirRegistroPago() {
    final controller = widget.controller;
    final generacion = controller.generacion;
    final token = controller.token;
    final api = widget.registrarPagos;
    bool vigente() =>
        mounted &&
        !_accesoDenegado &&
        token != null &&
        controller.generacion == generacion &&
        controller.token == token;
    if (!vigente()) return;
    final pantalla = RegistrarPagoAdminScreen(
      registrar:
          ({required idCliente, required importe, required medio}) async {
            if (!vigente()) throw StateError('La sesión ya no está vigente.');
            final pago = await _protegerAcceso(
              controller: controller,
              solicitud: () => api.registrar(
                idCliente: idCliente,
                importe: importe,
                medio: medio,
              ),
              onAccesoDenegado: _denegarAcceso,
            );
            if (!vigente()) throw StateError('La sesión ya no está vigente.');
            return pago;
          },
    );
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => pantalla));
  }

  void _abrirDeuda() {
    final controller = widget.controller;
    final generacion = controller.generacion;
    final token = controller.token;
    final api = widget.deuda;
    bool vigente() =>
        mounted &&
        !_accesoDenegado &&
        token != null &&
        controller.generacion == generacion &&
        controller.token == token;
    if (!vigente()) return;
    final consulta = ConsultaDeudaAdminProtegida((id) async {
      if (!vigente()) throw StateError('La sesión ya no está vigente.');
      final resultado = await _protegerAcceso(
        controller: controller,
        solicitud: () => api.consultar(id),
        onAccesoDenegado: _denegarAcceso,
      );
      if (!vigente()) throw StateError('La sesión ya no está vigente.');
      return resultado;
    });
    final pantalla = ConsultarDeudaAdminScreen(
      consulta: consulta,
      alcance: Object(),
    );
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => pantalla));
  }

  void _abrirPagos() {
    final controller = widget.controller;
    final generacion = controller.generacion;
    final token = controller.token;
    final api = widget.pagos;
    bool vigente() =>
        mounted &&
        !_accesoDenegado &&
        token != null &&
        controller.generacion == generacion &&
        controller.token == token;
    Future<T> proteger<T>(Future<T> Function() operacion) async {
      if (!vigente()) throw StateError('La sesión ya no está vigente.');
      final resultado = await _protegerAcceso(
        controller: controller,
        solicitud: operacion,
        onAccesoDenegado: _denegarAcceso,
      );
      if (!vigente()) throw StateError('La sesión ya no está vigente.');
      return resultado;
    }

    if (!vigente()) return;
    final pantalla = PagosPendientesScreen(
      cargar: () => proteger<List<PagoAdmin>>(api.pendientes),
      decidir: (id, decision) => proteger(() => api.decidir(id, decision)),
    );
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => pantalla));
  }

  void _abrirUbicacion(int id) {
    final controller = widget.controller;
    final sesion = controller.sesion;
    final generacion = controller.generacion;
    final api = widget.gpsApi;
    if (sesion == null || _accesoDenegado) return;
    // Identidad opaca propia de la ruta; nunca usa el token como key.
    final alcance = Object();
    bool vigente() =>
        mounted &&
        !_accesoDenegado &&
        controller.generacion == generacion &&
        identical(controller.sesion, sesion);
    Future<UbicacionViaje> consultar(int viaje) {
      if (!vigente()) {
        throw StateError('La sesión de esta vista ya no está vigente.');
      }
      return _protegerAcceso(
        controller: controller,
        solicitud: () => api.consultar(viaje),
        onAccesoDenegado: _denegarAcceso,
      );
    }

    // Crear una vez evita renovar funciones/fuentes al reconstruir la ruta.
    final pantalla = UbicacionScreen(
      idViaje: id,
      consultar: consultar,
      alcance: alcance,
      invalidaciones: controller,
      contextoVigente: vigente,
      configuracionMapa: widget.configuracionMapa,
      prepararMapa: widget.prepararMapa,
      crearVisorMapa: widget.crearVisorMapa,
    );
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => pantalla));
  }

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

  Future<ViajeResumen> _actualizarViaje(int idViaje, ViajeUpdate solicitud) {
    return _protegerAcceso(
      controller: widget.controller,
      solicitud: () => widget.crear.actualizarViaje(idViaje, solicitud),
      onAccesoDenegado: _denegarAcceso,
    );
  }

  Future<ViajeResumen> _cancelarViaje(int idViaje) async {
    final generacion = widget.controller.generacion;
    final token = widget.controller.token;
    bool vigente() =>
        mounted &&
        !_accesoDenegado &&
        token != null &&
        widget.controller.generacion == generacion &&
        widget.controller.token == token;
    if (!vigente()) throw StateError('La sesión ya no está vigente.');
    final resultado = await _protegerAcceso(
      controller: widget.controller,
      solicitud: () => widget.crear.cancelarViaje(idViaje),
      onAccesoDenegado: _denegarAcceso,
    );
    if (!vigente()) throw StateError('La sesión ya no está vigente.');
    return resultado;
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
    required this.ejecucion,
    required this.gpsApi,
    required this.comprobarUbicacion,
    required this.asistenciaUbicacion,
    required this.onSalir,
  });

  final SesionController controller;
  final ViajesChoferApi listar;
  final DetalleViajeChoferApi detalle;
  final EjecucionViajeApi ejecucion;
  final UbicacionApi gpsApi;
  final ComprobarUbicacionInicio comprobarUbicacion;
  final AsistenciaUbicacionInicio? asistenciaUbicacion;
  final VoidCallback onSalir;

  @override
  State<_EntradaChofer> createState() => _EntradaChoferState();
}

class _EntradaChoferState extends State<_EntradaChofer> {
  bool _accesoDenegado = false;
  late final int _generacion;
  late final String? _token;
  late final AccionesEjecucionViaje _acciones;
  late final AsistenciaUbicacionInicio? _asistencia;
  late final SeguimientoGpsController _gps;

  @override
  void initState() {
    super.initState();
    _generacion = widget.controller.generacion;
    _token = widget.controller.token;
    _gps = SeguimientoGpsController(
      comprobar: _comprobarUbicacion,
      capturar: capturarGpsAndroid,
      sesionVigente: () => _vigente && !_accesoDenegado,
      enviar: (id, p) {
        _exigirSesion();
        return widget.gpsApi.enviar(
          id,
          p.latitude,
          p.longitude,
          p.timestamp,
          _token!,
        );
      },
    );
    _acciones = AccionesEjecucionViaje(
      iniciar: (id) => _ejecutar(widget.ejecucion.iniciar, id),
      finalizar: (id) => _ejecutar(widget.ejecucion.finalizar, id),
    );
    final asistencia = widget.asistenciaUbicacion;
    _asistencia = asistencia == null
        ? null
        : AsistenciaUbicacionInicio(
            solicitarPermiso: () => _accionLocal(asistencia.solicitarPermiso),
            abrirAjustesApp: () => _accionLocal(asistencia.abrirAjustesApp),
            abrirAjustesUbicacion: () =>
                _accionLocal(asistencia.abrirAjustesUbicacion),
          );
  }

  bool get _vigente =>
      mounted &&
      _token != null &&
      widget.controller.generacion == _generacion &&
      widget.controller.token == _token;

  void _exigirSesion() {
    if (!_vigente || _accesoDenegado) {
      throw const RechazoOperacionViaje(MotivoRechazoViaje.noAutenticado);
    }
  }

  Future<CondicionesUbicacionInicio> _comprobarUbicacion() async {
    _exigirSesion();
    final condiciones = await widget.comprobarUbicacion();
    _exigirSesion();
    return condiciones;
  }

  Future<T> _accionLocal<T>(Future<T> Function() accion) async {
    _exigirSesion();
    final resultado = await accion();
    _exigirSesion();
    return resultado;
  }

  Future<ViajeResumen> _ejecutar(
    CambiarEstadoViajeChofer enviar,
    int id,
  ) async {
    _exigirSesion();
    try {
      return await enviar(id);
    } on RechazoOperacionViaje catch (error) {
      if (error.motivo == MotivoRechazoViaje.sinPermiso) _denegarAcceso();
      rethrow;
    }
  }

  void _viajeAceptado(ViajeResumen viaje, bool inicioConfirmado) {
    if (!_vigente || _accesoDenegado) return;
    _gps.confirmar(
      viaje,
      iniciar:
          inicioConfirmado &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
  }

  @override
  Widget build(BuildContext context) => _accesoDenegado
      ? _AccesoDenegado(
          key: const Key('chofer-acceso-denegado'),
          onSalir: widget.onSalir,
        )
      : PanelGps(
          controller: _gps,
          child: ChoferShell(
            cargarViajes: _cargarViajes,
            cargarDetalle: _cargarDetalle,
            acciones: _acciones,
            comprobarUbicacionInicio: _comprobarUbicacion,
            asistenciaUbicacionInicio: _asistencia,
            onViajeAceptado: _viajeAceptado,
            onSalir: widget.onSalir,
          ),
        );

  Future<List<ViajeResumen>> _cargarViajes(DateTime fecha) async {
    _exigirSesion();
    final viajes = await _protegerAcceso<List<ViajeResumen>>(
      controller: widget.controller,
      solicitud: () => widget.listar.cargarViajes(fecha),
      onAccesoDenegado: _denegarAcceso,
    );
    return viajes;
  }

  Future<OperacionAsignada?> _cargarDetalle(int idViaje) async {
    _exigirSesion();
    final detalle = await _protegerAcceso<OperacionAsignada?>(
      controller: widget.controller,
      solicitud: () => widget.detalle.cargarDetalle(idViaje),
      onAccesoDenegado: _denegarAcceso,
    );
    return detalle;
  }

  @override
  void dispose() {
    _gps.dispose();
    super.dispose();
  }

  void _denegarAcceso() {
    if (!_vigente || _accesoDenegado) return;
    _gps.detener('Acceso no disponible. GPS detenido.');
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
