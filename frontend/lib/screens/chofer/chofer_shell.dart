import 'package:flutter/material.dart';

import '../../controllers/chofer/ejecucion_viaje_controller.dart';
import '../../controllers/chofer/asistencia_ubicacion_inicio.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/chofer/viaje_resumen.dart';
import 'detalle_viaje_chofer_screen.dart';
import 'viajes_chofer_screen.dart';

/// Consulta CU-029 y acciones CU-030 opcionales; fuentes y sesión externas.
///
/// El contenedor conserva las mismas fuentes entre reconstrucciones y reemplaza
/// la key (o desmonta este widget) al cambiar de sesión. Debe resolver 401/403
/// antes de propagar el error a las pantallas; aquí no hay política de acceso.
/// [onSalir] solo delega la salida: no borra tokens ni cierra transportes.
class ChoferShell extends StatefulWidget {
  const ChoferShell({
    required this.cargarViajes,
    required this.cargarDetalle,
    required this.onSalir,
    this.fechaInicial,
    this.acciones,
    this.comprobarUbicacionInicio,
    this.asistenciaUbicacionInicio,
    super.key,
  });

  final CargarViajesChofer cargarViajes;
  final CargarDetalleViajeChofer cargarDetalle;
  final VoidCallback onSalir;
  final DateTime? fechaInicial;
  final AccionesEjecucionViaje? acciones;
  final ComprobarUbicacionInicio? comprobarUbicacionInicio;
  final AsistenciaUbicacionInicio? asistenciaUbicacionInicio;

  @override
  State<ChoferShell> createState() => _ChoferShellState();
}

class _ChoferShellState extends State<ChoferShell> {
  final _navigator = GlobalKey<NavigatorState>();
  final _fuentes = ValueNotifier(0);
  final _listado = ValueNotifier(0);
  bool _detalleAbierto = false;
  bool _listadoInvalidado = false;
  int _revisionRecarga = 0;
  int _operacionesEnVuelo = 0;
  AccionesEjecucionViaje? _acciones;
  final _coordinadores = <int, _CoordinadorConFuentes>{};
  int? _idDetalleActivo;

  _CoordinadorConFuentes _coordinadorPara(int id) => _coordinadores.putIfAbsent(
    id,
    () => _CoordinadorConFuentes(
      EjecucionViajeController(
        idViaje: id,
        cargarDetalle: widget.cargarDetalle,
        acciones: _acciones,
        comprobarUbicacionInicio: widget.comprobarUbicacionInicio,
      ),
      _fuentes.value,
    ),
  );

  bool _sincronizar(int id, _CoordinadorConFuentes entrada) {
    if (entrada.revision == _fuentes.value) return false;
    _actualizarFuentes(id, entrada);
    return true; // actualizarContexto ya inició una lectura.
  }

  void _actualizarFuentes(int id, _CoordinadorConFuentes entrada) {
    entrada.revision = _fuentes.value;
    entrada.controlador.actualizarContexto(
      idViaje: id,
      cargarDetalle: widget.cargarDetalle,
      acciones: _acciones,
      comprobarUbicacionInicio: widget.comprobarUbicacionInicio,
    );
  }

  @override
  void initState() {
    super.initState();
    _prepararAcciones();
  }

  void _prepararAcciones() {
    // Conservar identidad mientras no cambie la dependencia externa.
    final acciones = widget.acciones;
    _acciones = acciones == null
        ? null
        : AccionesEjecucionViaje(
            iniciar: (id) => _enviar(acciones.iniciar, id),
            finalizar: (id) => _enviar(acciones.finalizar, id),
            onRechazo: acciones.onRechazo,
          );
  }

  Future<ViajeResumen> _enviar(CambiarEstadoViajeChofer enviar, int id) async {
    if (!mounted) throw const ResultadoViajeIncierto();
    _operacionesEnVuelo++;
    // El coordinador ya resolvió ubicación y confirmación antes de invocarnos.
    _listadoInvalidado = true;
    _listado.value++;
    try {
      return await enviar(id);
    } finally {
      if (mounted) {
        _operacionesEnVuelo--;
        _recargarSiCorresponde();
      }
    }
  }

  void _recargarSiCorresponde() {
    if (_detalleAbierto || !_listadoInvalidado || _operacionesEnVuelo != 0) {
      return;
    }
    _listadoInvalidado = false;
    _revisionRecarga++;
    _listado.value++;
  }

  @override
  void didUpdateWidget(covariant ChoferShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.acciones != widget.acciones) _prepararAcciones();
    if (oldWidget.cargarViajes != widget.cargarViajes ||
        oldWidget.cargarDetalle != widget.cargarDetalle ||
        oldWidget.acciones != widget.acciones ||
        oldWidget.comprobarUbicacionInicio != widget.comprobarUbicacionInicio) {
      _fuentes.value++;
      final id = _idDetalleActivo;
      if (id != null) {
        final entrada = _coordinadores[id];
        if (entrada != null) _sincronizar(id, entrada);
      }
    }
  }

  @override
  void dispose() {
    // Único propietario de los coordinadores prestados al detalle.
    for (final entrada in _coordinadores.values) {
      entrada.controlador.dispose();
    }
    _coordinadores.clear();
    _fuentes.dispose();
    _listado.dispose();
    super.dispose();
  }

  Future<void> _abrirDetalle(int idViaje) async {
    if (_detalleAbierto) return;
    _detalleAbierto = true;
    _idDetalleActivo = idViaje;
    // El mismo propietario también permite activar/quitar acciones sin perder
    // el contexto de una ruta ya abierta. Sin acciones se mantiene solo lectura.
    final entrada = _coordinadorPara(idViaje);
    if (!_sincronizar(idViaje, entrada)) {
      // Si sigue ocupado, consultar() no duplica la solicitud en vuelo.
      entrada.controlador.consultar();
    }
    await _navigator.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) => ListenableBuilder(
          listenable: _fuentes,
          builder: (_, _) => DetalleViajeChoferScreen(
            idViaje: idViaje,
            cargarDetalle: widget.cargarDetalle,
            acciones: _acciones,
            comprobarUbicacionInicio: widget.comprobarUbicacionInicio,
            controlador: entrada.controlador,
            asistenciaUbicacionInicio: widget.asistenciaUbicacionInicio,
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (entrada.controlador.comprobandoUbicacion) {
      // Cancelar la comprobación local de la ruta cerrada, no un POST enviado.
      // La API existente invalida su generación y conserva pendiente/confirmación.
      _actualizarFuentes(idViaje, entrada);
    }
    _detalleAbierto = false;
    _idDetalleActivo = null;
    _recargarSiCorresponde();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: NavigatorPopHandler<Object?>(
      onPopWithResult: (_) => _navigator.currentState!.pop(),
      child: Navigator(
        key: _navigator,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => ListenableBuilder(
            listenable: Listenable.merge([_fuentes, _listado]),
            builder: (_, _) => ViajesChoferScreen(
              cargarViajes: widget.cargarViajes,
              fechaInicial: widget.fechaInicial,
              onViajeSeleccionado: _abrirDetalle,
              invalidado: _listadoInvalidado,
              revisionRecarga: _revisionRecarga,
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(AppSpacing.md),
      child: OutlinedButton.icon(
        onPressed: widget.onSalir,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.driverTouchTarget),
        ),
        icon: const Icon(Icons.logout),
        label: const Text('Cerrar sesión'),
      ),
    ),
  );
}

class _CoordinadorConFuentes {
  _CoordinadorConFuentes(this.controlador, this.revision);

  final EjecucionViajeController controlador;
  int revision;
}
