import 'package:flutter/foundation.dart';

import 'configuracion_mapa.dart';

/// Android recibe su clave por Manifest. No precalentar ni pedir ubicación.
Future<bool> prepararMaps(ConfiguracionMapa configuracion) async =>
    defaultTargetPlatform == TargetPlatform.android &&
    configuracion.destino == DestinoMapa.android &&
    configuracion.disponible;
