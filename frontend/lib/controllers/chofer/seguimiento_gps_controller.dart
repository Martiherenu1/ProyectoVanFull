import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api/api_error.dart';
import '../../models/chofer/viaje_resumen.dart';
import 'condiciones_ubicacion_inicio.dart';

typedef EnviarPosicion = Future<void> Function(int id, Position posicion);

/// Una sesión/una captura, sin cola ni reenvío de una posición fallida.
/// Un nuevo evento puede enviarse tras un fallo de red, nunca se reproduce el anterior.
class SeguimientoGpsController extends ChangeNotifier {
  SeguimientoGpsController({
    required this.comprobar,
    required this.capturar,
    required this.enviar,
    required this.sesionVigente,
  });
  final ComprobarUbicacionInicio comprobar;
  final Stream<Position> Function() capturar;
  final EnviarPosicion enviar;
  final bool Function() sesionVigente;
  StreamSubscription<Position>? _suscripcion;
  Future<void> _cancelacion = Future.value();
  int _generacion = 0;
  int? idViaje;
  final _cerrados = <int>{};
  final _observados = <int, ViajeResumen>{};
  bool activo = false,
      preparando = false,
      _enviando = false,
      _dispuesto = false;
  String estado = 'GPS detenido.';
  bool _enCurso = false;
  bool get puedeReactivar => !_dispuesto && _enCurso && !activo && !preparando;

  /// Recibe únicamente estados aceptados por CU-030, no respuestas HTTP crudas.
  /// Observar un viaje no lo selecciona ni reemplaza la captura actual.
  Iterable<int> get viajesReactivables =>
      _observados.keys.where((id) => id != idViaje || (!activo && !preparando));

  void confirmar(ViajeResumen viaje, {bool iniciar = false}) {
    if (_dispuesto || !sesionVigente()) return;
    if (viaje.estado == EstadoViaje.finalizado ||
        viaje.estado == EstadoViaje.cancelado) {
      _cerrados.add(viaje.idViaje);
      _observados.remove(viaje.idViaje);
      if (viaje.idViaje == idViaje) {
        _enCurso = false;
        detener();
      } else {
        _avisar();
      }
      return;
    }
    if (_cerrados.contains(viaje.idViaje)) return;
    if (viaje.estado == EstadoViaje.enCurso) {
      _observados[viaje.idViaje] = viaje;
      if (iniciar) {
        // Solo un inicio aceptado o una acción explícita cambia la selección.
        unawaited(reactivarViaje(viaje.idViaje));
        return;
      }
    } else {
      _observados.remove(viaje.idViaje);
    }
    if (viaje.idViaje == idViaje) {
      _enCurso = viaje.estado == EstadoViaje.enCurso;
      if (!_enCurso) {
        detener();
        return;
      }
    }
    _avisar();
  }

  Future<void> reactivarViaje(int id) async {
    if (_dispuesto || !sesionVigente() || !_observados.containsKey(id)) return;
    if (id != idViaje) {
      detener();
      idViaje = id;
      _enCurso = true;
    }
    await reactivar();
  }

  Future<void> reactivar() async {
    // Compatibilidad con acción explícita sin selección, solo si no es ambigua.
    if (idViaje == null && _observados.length == 1) {
      await reactivarViaje(_observados.keys.single);
      return;
    }
    if (!puedeReactivar || !sesionVigente()) return;
    final g = ++_generacion;
    preparando = true;
    _avisar();
    try {
      await _cancelacion;
      if (!_vigente(g)) return;
      final c = await comprobar();
      if (!_vigente(g)) return;
      if (!c.servicioActivado || !c.permisoConcedido) {
        estado = !c.servicioActivado
            ? 'Activá la ubicación para compartir GPS.'
            : 'Concedé permiso de ubicación para compartir GPS.';
        return;
      }
      activo = true;
      estado = 'Esperando ubicación. El viaje sigue en curso.';
      _suscripcion = capturar().listen(
        (p) => unawaited(_recibir(g, p)),
        onError: (Object _) {
          if (_vigente(g)) {
            detener(
              'GPS no disponible. Podés reactivarlo; el GPS no finaliza el viaje.',
            );
          }
        },
        onDone: () {
          if (_vigente(g)) detener('Captura interrumpida. Reactivá GPS.');
        },
      );
    } catch (_) {
      if (_vigente(g)) detener('No se pudo iniciar GPS. El viaje no finalizó.');
    } finally {
      if (_vigente(g)) {
        preparando = false;
        _avisar();
      }
    }
  }

  bool _vigente(int g) => !_dispuesto && g == _generacion && sesionVigente();

  Future<void> _recibir(int g, Position p) async {
    if (!_vigente(g) || !activo || _enviando || !_enCurso) return;
    _enviando = true;
    try {
      await enviar(idViaje!, p);
      if (_vigente(g)) {
        estado = 'Envío GPS procesado.';
        _avisar();
      }
    } on ApiException catch (e) {
      if (!_vigente(g)) return;
      if ([401, 403, 404, 409].contains(e.statusCode)) {
        _enCurso = false;
        _observados.remove(idViaje);
        detener(
          e.statusCode == 401
              ? 'Sesión no válida. GPS detenido.'
              : 'GPS detenido. Consultá el estado y acceso al viaje.',
        );
      } else {
        estado = 'No se pudo enviar GPS. Sin cola; se intentará con una nueva posición.';
        _avisar();
      }
    } catch (_) {
      if (_vigente(g)) {
        estado = 'Sin confirmación de envío. Verificá la conexión; no se guarda una cola.';
        _avisar();
      }
    } finally {
      _enviando = false;
    }
  }

  void detener([String mensaje = 'GPS detenido.']) {
    _generacion++;
    activo = false;
    preparando = false;
    final anterior = _suscripcion;
    _suscripcion = null;
    _cancelacion = _cancelacion
        .then((_) async {
          await anterior?.cancel();
        })
        .catchError((Object _) {});
    estado = mensaje;
    _avisar();
  }

  void _avisar() {
    if (!_dispuesto) notifyListeners();
  }

  @override
  void dispose() {
    _dispuesto = true;
    detener();
    super.dispose();
  }
}
