import 'package:geolocator/geolocator.dart';

import '../../controllers/chofer/condiciones_ubicacion_inicio.dart';

/// Solo consulta condiciones del telefono; los errores llegan al bloqueo local
/// del controlador. No solicita permisos, ajustes, posiciones ni streams.
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
    );
  }
}
