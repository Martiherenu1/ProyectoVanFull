import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/maps/configuracion_mapa.dart';
import '../../core/maps/preparar_maps.dart';
import '../../models/gps/ubicacion_viaje.dart';

typedef PrepararMapa = Future<bool> Function(ConfiguracionMapa configuracion);

abstract interface class ControlVisorMapa {
  Future<void> centrarEn(double latitud, double longitud);
  void dispose();
}

typedef ConstructorVisorMapa = Widget Function({
  required Key key,
  required UbicacionViaje posicion,
  required ConfiguracionMapa configuracion,
  required ValueChanged<ControlVisorMapa> onCreado,
});

bool posicionDelViaje(UbicacionViaje p, int idViaje) =>
    p.idViaje == idViaje &&
    p.latitud.isFinite &&
    p.longitud.isFinite &&
    p.latitud >= -90 &&
    p.latitud <= 90 &&
    p.longitud >= -180 &&
    p.longitud <= 180 &&
    p.fecha.isUtc;

/// No consulta GPS, red de VanFull ni permisos. Recibe una posición ya aceptada.
class MapaUltimaPosicion extends StatefulWidget {
  const MapaUltimaPosicion({
    required this.idViaje,
    required this.posicion,
    this.alcance,
    this.permitido = true,
    this.configuracion,
    this.preparar,
    this.crearVisor,
    super.key,
  });
  final int idViaje;
  final UbicacionViaje? posicion;
  final Object? alcance;
  final bool permitido;
  final ConfiguracionMapa? configuracion;
  final PrepararMapa? preparar;
  final ConstructorVisorMapa? crearVisor;

  @override
  State<MapaUltimaPosicion> createState() => _MapaUltimaPosicionState();
}

class _MapaUltimaPosicionState extends State<MapaUltimaPosicion> {
  late ConfiguracionMapa _configuracion;
  UbicacionViaje? _ultima;
  ControlVisorMapa? _control;
  int _generacion = 0;
  bool _cargando = false, _listo = false, _fallo = false, _centrando = false;
  bool _errorCamara = false;

  @override
  void initState() {
    super.initState();
    _configuracion = widget.configuracion ?? ConfiguracionMapa.desdeEntorno();
    _actualizar();
  }

  @override
  void didUpdateWidget(covariant MapaUltimaPosicion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final config = widget.configuracion ?? ConfiguracionMapa.desdeEntorno();
    if (widget.idViaje != oldWidget.idViaje ||
        widget.alcance != oldWidget.alcance ||
        config != _configuracion ||
        widget.crearVisor != oldWidget.crearVisor ||
        widget.preparar != oldWidget.preparar) {
      _limpiar();
      _ultima = null;
    }
    _configuracion = config;
    _actualizar();
  }

  void _actualizar() {
    final p = widget.posicion;
    if (!widget.permitido || p == null) {
      _limpiar();
      _ultima = null;
      return;
    }
    if (posicionDelViaje(p, widget.idViaje) &&
        (_ultima == null || !p.fecha.isBefore(_ultima!.fecha))) {
      _ultima = p;
    }
    if (_ultima != null &&
        _configuracion.disponible &&
        !_cargando &&
        !_listo &&
        !_fallo) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    final g = ++_generacion;
    _cargando = true;
    var listo = false;
    try {
      listo = await (widget.preparar ?? prepararMaps)(_configuracion);
    } catch (_) {
      // Una clave/servicio inválido nunca debe exponer detalles del proveedor.
    }
    if (!mounted || g != _generacion || !widget.permitido || _ultima == null) {
      return;
    }
    setState(() {
      _cargando = false;
      _listo = listo;
      _fallo = !listo;
    });
  }

  void _creado(int g, ControlVisorMapa control) {
    if (!mounted || g != _generacion || !widget.permitido || !_listo) {
      if (!identical(control, _control)) control.dispose();
      return;
    }
    if (identical(control, _control)) return;
    _control?.dispose();
    setState(() => _control = control);
  }

  Future<void> _centrar() async {
    final control = _control;
    final p = _ultima;
    if (control == null || p == null || _centrando) return;
    final g = _generacion;
    setState(() {
      _centrando = true;
      _errorCamara = false;
    });
    try {
      await control.centrarEn(p.latitud, p.longitud);
    } catch (_) {
      if (mounted && g == _generacion) setState(() => _errorCamara = true);
    } finally {
      if (mounted && g == _generacion) setState(() => _centrando = false);
    }
  }

  void _limpiar() {
    _generacion++;
    _control?.dispose();
    _control = null;
    _cargando = false;
    _listo = false;
    _fallo = false;
    _centrando = false;
    _errorCamara = false;
  }

  @override
  void dispose() {
    _limpiar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _ultima;
    if (!widget.permitido || p == null) return const SizedBox.shrink();
    if (!_configuracion.disponible || _fallo) {
      return const Text('Mapa no disponible.');
    }
    if (!_listo) return const Text('Preparando mapa…');
    final g = _generacion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Mapa de la última posición recibida del viaje ${p.idViaje}',
          child: SizedBox(
            height: 300, // Configuración visual, no regla del viaje.
            width: double.infinity,
            child: (widget.crearVisor ?? crearVisorGoogle)(
              key: ValueKey((widget.alcance, widget.idViaje, g)),
              posicion: p,
              configuracion: _configuracion,
              onCreado: (control) => _creado(g, control),
            ),
          ),
        ),
        OutlinedButton.icon(
          key: const Key('centrar-vehiculo'),
          onPressed: _control == null || _centrando ? null : _centrar,
          icon: const Icon(Icons.center_focus_strong),
          label: const Text('Centrar en vehículo'),
        ),
        if (_errorCamara) const Text('No se pudo centrar el mapa.'),
      ],
    );
  }
}

/// Construye configuración; no inicia el SDK hasta montar este widget.
/// Permite inspeccionar los flags en pruebas sin una vista de plataforma.
Widget crearVisorGoogle({
  required Key key,
  required UbicacionViaje posicion,
  required ConfiguracionMapa configuracion,
  required ValueChanged<ControlVisorMapa> onCreado,
}) {
  final web = configuracion.destino == DestinoMapa.web;
  final id = MarkerId('viaje-${posicion.idViaje}');
  final destino = LatLng(posicion.latitud, posicion.longitud);
  final info = InfoWindow(
    title: 'Última posición del viaje ${posicion.idViaje}',
  );
  final Marker marker = web
      ? AdvancedMarker(
          markerId: id,
          position: destino,
          infoWindow: info,
          consumeTapEvents: true,
          onTap: () {},
        )
      : Marker(
          markerId: id,
          position: destino,
          infoWindow: info,
          consumeTapEvents: true,
          onTap: () {},
        );
  return GoogleMap(
    key: key,
    mapId: web ? configuracion.mapIdWeb : null,
    markerType: web
        ? GoogleMapMarkerType.advancedMarker
        : GoogleMapMarkerType.marker,
    initialCameraPosition: CameraPosition(target: destino, zoom: 14),
    markers: {marker},
    myLocationEnabled: false,
    myLocationButtonEnabled: false,
    mapToolbarEnabled: false,
    trafficEnabled: false,
    indoorViewEnabled: false,
    buildingsEnabled: false,
    streetViewControlEnabled: false,
    mapTypeControlEnabled: false,
    fullscreenControlEnabled: false,
    onMapCreated: (control) => onCreado(_ControlGoogle(control)),
  );
}

class _ControlGoogle implements ControlVisorMapa {
  _ControlGoogle(this._control);
  final GoogleMapController _control;
  bool _dispuesto = false;
  @override
  Future<void> centrarEn(double latitud, double longitud) async {
    if (!_dispuesto) {
      await _control.moveCamera(
        CameraUpdate.newLatLng(LatLng(latitud, longitud)),
      );
    }
  }

  @override
  void dispose() {
    // GoogleMapState es dueño del controlador nativo y lo dispone al desmontar.
    // Aquí solo desconectamos el handle, evitando un segundo dispose nativo.
    _dispuesto = true;
  }
}
