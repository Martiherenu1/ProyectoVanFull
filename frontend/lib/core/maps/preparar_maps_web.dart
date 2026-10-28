import 'dart:js_interop';

import 'configuracion_mapa.dart';

@JS('vanfullMapsPreparar')
external JSPromise<JSBoolean> _preparar(JSString clave, JSString mapIdWeb);

Future<bool> prepararMaps(ConfiguracionMapa configuracion) async {
  if (configuracion.destino != DestinoMapa.web || !configuracion.disponible) {
    return false;
  }
  try {
    return (await _preparar(
      configuracion.clave.toJS,
      configuracion.mapIdWeb.toJS,
    ).toDart).toDart;
  } catch (_) {
    return false;
  }
}
