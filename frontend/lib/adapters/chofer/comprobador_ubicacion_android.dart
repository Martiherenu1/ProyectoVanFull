import 'package:geolocator/geolocator.dart';

import '../../controllers/chofer/condiciones_ubicacion_inicio.dart';
import '../../controllers/chofer/asistencia_ubicacion_inicio.dart';

/// comprobar() solo consulta condiciones; no pide permisos ni abre Ajustes.
/// Las otras acciones requieren una pulsación explícita independiente. Ninguna
/// obtiene posiciones/streams ni inicia viajes. La composición limita Android.
class ComprobadorUbicacionAndroid {
  ComprobadorUbicacionAndroid({GeolocatorPlatform? plataforma})
    : _plataforma = plataforma ?? GeolocatorPlatform.instance;

  final GeolocatorPlatform _plataforma;

  Future<CondicionesUbicacionInicio> comprobar() async {
    final servicio = await _plataforma.isLocationServiceEnabled();
    final permiso = await _plataforma.checkPermission();
    return CondicionesUbicacionInicio(
      servicioActivado: servicio,
      permisoConcedido:
          permiso == LocationPermission.whileInUse ||
          permiso == LocationPermission.always,
      permisoDenegadoPermanentemente:
          permiso == LocationPermission.deniedForever,
    );
  }

  Future<ResultadoPermisoUbicacion> solicitarPermiso() async =>
      switch (await _plataforma.requestPermission()) {
        LocationPermission.whileInUse ||
        LocationPermission.always => ResultadoPermisoUbicacion.concedido,
        LocationPermission.deniedForever =>
          ResultadoPermisoUbicacion.denegadoPermanentemente,
        _ => ResultadoPermisoUbicacion.denegado,
      };

  Future<bool> abrirAjustesApp() => _plataforma.openAppSettings();
  Future<bool> abrirAjustesUbicacion() => _plataforma.openLocationSettings();
}
