import 'package:geolocator/geolocator.dart';

/// Doble de plataforma: ninguna llamada obtiene datos del dispositivo.
class PlataformaUbicacionFake extends GeolocatorPlatform {
  LocationPermission permiso = LocationPermission.whileInUse;
  bool servicio = true;
  Object? falloServicio;
  Object? falloPermiso;
  bool ajustesAbiertos = true;
  final llamadas = <String>[];

  @override
  Future<bool> isLocationServiceEnabled() async {
    llamadas.add('servicio');
    if (falloServicio != null) throw falloServicio!;
    return servicio;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    llamadas.add('permiso');
    if (falloPermiso != null) throw falloPermiso!;
    return permiso;
  }

  @override
  Future<LocationPermission> requestPermission() {
    llamadas.add('solicitarPermiso');
    throw StateError('No debe solicitar permisos');
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    llamadas.add('posicion');
    throw StateError('No debe obtener posiciones');
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) {
    llamadas.add('ultimaPosicion');
    throw StateError('No debe obtener posiciones');
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    llamadas.add('stream');
    throw StateError('No debe abrir streams');
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async {
    llamadas.add('precision');
    return LocationAccuracyStatus.reduced;
  }

  @override
  Future<bool> openAppSettings() async {
    llamadas.add('ajustesApp');
    return ajustesAbiertos;
  }

  @override
  Future<bool> openLocationSettings() async {
    llamadas.add('ajustesUbicacion');
    return ajustesAbiertos;
  }
}
