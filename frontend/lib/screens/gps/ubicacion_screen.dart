import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/maps/configuracion_mapa.dart';
import '../../models/gps/ubicacion_viaje.dart';
import '../../widgets/gps/mapa_ultima_posicion.dart';

class UbicacionScreen extends StatefulWidget {
  const UbicacionScreen({
    required this.idViaje,
    required this.consultar,
    this.alcance,
    this.invalidaciones,
    this.contextoVigente,
    this.configuracionMapa,
    this.prepararMapa,
    this.crearVisorMapa,
    super.key,
  });
  final int idViaje;
  final Future<UbicacionViaje> Function(int) consultar;

  /// La composición autenticada los inyecta; opcionales para usos aislados.
  /// Solo retiran UI/resultados anteriores, no reemplazan autenticación.
  final Object? alcance;
  final Listenable? invalidaciones;
  final bool Function()? contextoVigente;
  final ConfiguracionMapa? configuracionMapa;
  final PrepararMapa? prepararMapa;
  final ConstructorVisorMapa? crearVisorMapa;
  @override
  State<UbicacionScreen> createState() => _UbicacionScreenState();
}

class _UbicacionScreenState extends State<UbicacionScreen> {
  Timer? _timer;
  UbicacionViaje? _posicion;
  bool _cargando = false, _bloqueada = false, _enVuelo = false;
  bool _consultarAlTerminar = false;
  int _generacion = 0;
  Object _alcanceMapa = Object();
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.invalidaciones?.addListener(_invalidada);
    _reiniciar();
  }

  @override
  void didUpdateWidget(covariant UbicacionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.invalidaciones != widget.invalidaciones) {
      oldWidget.invalidaciones?.removeListener(_invalidada);
      widget.invalidaciones?.addListener(_invalidada);
    }
    if (oldWidget.idViaje != widget.idViaje ||
        oldWidget.consultar != widget.consultar ||
        oldWidget.alcance != widget.alcance ||
        oldWidget.invalidaciones != widget.invalidaciones ||
        oldWidget.contextoVigente != widget.contextoVigente) {
      _reiniciar();
    }
  }

  bool get _contextoVigente {
    try {
      return widget.contextoVigente?.call() ?? true;
    } catch (_) {
      return false;
    }
  }

  void _invalidada() {
    if (mounted && !_contextoVigente) _retirar();
  }

  void _reiniciar() {
    _generacion++;
    _alcanceMapa = Object();
    _posicion = null;
    _error = null;
    _bloqueada = false;
    _timer?.cancel();
    if (!_contextoVigente) {
      _retirar();
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _consultar());
    // Un GET anterior no se cancela; esperar sin solapar otra consulta.
    _consultarAlTerminar = _enVuelo;
    if (!_enVuelo) unawaited(_consultar());
  }

  void _retirar() {
    _generacion++;
    _consultarAlTerminar = false;
    _timer?.cancel();
    _alcanceMapa = Object();
    setState(() {
      _posicion = null;
      _cargando = false;
      _bloqueada = true;
      _error = 'Ubicación no disponible para esta sesión o viaje.';
    });
  }

  bool _puedeAplicar(int g) {
    if (!mounted || g != _generacion) return false;
    if (!_contextoVigente) {
      _retirar();
      return false;
    }
    return true;
  }

  Future<void> _consultar() async {
    if (_enVuelo || _bloqueada || !mounted) return;
    if (!_contextoVigente) {
      _retirar();
      return;
    }
    final g = _generacion;
    final id = widget.idViaje;
    final fuente = widget.consultar;
    _enVuelo = true;
    setState(() => _cargando = true);
    try {
      final p = await fuente(id);
      if (!_puedeAplicar(g)) return;
      if (!posicionDelViaje(p, id) ||
          (_posicion != null && p.fecha.isBefore(_posicion!.fecha))) {
        throw const FormatException(
          'Posición no válida para actualizar la vista',
        );
      }
      setState(() {
        _posicion = p;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!_puedeAplicar(g)) return;
      if (e.statusCode == 404 && e.codigo == 'UBICACION_NO_DISPONIBLE') {
        setState(() {
          _posicion = null;
          _error = 'Todavía no hay una posición disponible.';
        });
      } else if ([401, 403, 404].contains(e.statusCode)) {
        _retirar();
      } else {
        setState(() {
          _error = 'Consulta interrumpida. Última posición recibida; no es ubicación actual.';
        });
      }
    } catch (_) {
      if (_puedeAplicar(g)) {
        setState(() {
          _error = 'Sin actualización de ubicación. Revisá la conexión.';
        });
      }
    } finally {
      _enVuelo = false;
      if (mounted) {
        if (g == _generacion) setState(() => _cargando = false);
        if (_consultarAlTerminar) {
          _consultarAlTerminar = false;
          unawaited(_consultar());
        }
      }
    }
  }

  @override
  void dispose() {
    _generacion++;
    widget.invalidaciones?.removeListener(_invalidada);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ubicación del viaje')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) Text(_error!),
          if (_cargando) const Text('Actualizando ubicación…'),
          if (_posicion case final p?) ...[
            Text('Última posición: ${p.latitud}, ${p.longitud}'),
            Text('Fecha informada: ${p.fecha.toLocal()}'),
            Text(
              p.desactualizada || _error != null
                  ? 'Información desactualizada / sin actualización confirmada.'
                  : 'No marcada desactualizada en la última consulta.',
            ),
            const Text('La antigüedad real de captura no está verificada.'),
            Text(
              p.etaMinutos == null
                  ? 'ETA no disponible.'
                  : 'ETA informado por el servidor: ${p.etaMinutos} min.',
            ),
            MapaUltimaPosicion(
              key: ValueKey(_alcanceMapa),
              idViaje: widget.idViaje,
              posicion: p,
              alcance: _alcanceMapa,
              permitido: !_bloqueada,
              configuracion: widget.configuracionMapa,
              preparar: widget.prepararMapa,
              crearVisor: widget.crearVisorMapa,
            ),
          ] else if (_error == null)
            const Text('Consultando ubicación…'),
          OutlinedButton(
            onPressed: _bloqueada || _enVuelo ? null : _consultar,
            child: const Text('Actualizar ubicación'),
          ),
          TextButton(
            onPressed: () =>
                showLicensePage(context: context, applicationName: 'VanFull'),
            child: const Text('Avisos y licencias'),
          ),
        ],
      ),
    ),
  );
}
