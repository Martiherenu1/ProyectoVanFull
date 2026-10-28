import 'package:flutter/foundation.dart';

enum DestinoMapa { sinMapa, android, web }

/// Configuración cliente: no es un secreto dentro de un APK/bundle.
/// Las claves deben restringirse por aplicación y API fuera del repositorio.
class ConfiguracionMapa {
  const ConfiguracionMapa()
    : destino = DestinoMapa.sinMapa,
      clave = '',
      mapIdWeb = '';
  const ConfiguracionMapa.android({this.clave = ''})
    : destino = DestinoMapa.android,
      mapIdWeb = '';
  const ConfiguracionMapa.web({this.clave = '', this.mapIdWeb = ''})
    : destino = DestinoMapa.web;

  final DestinoMapa destino;
  final String clave;
  final String mapIdWeb;

  bool get disponible =>
      clave.trim().isNotEmpty &&
      switch (destino) {
        DestinoMapa.android => true,
        DestinoMapa.web => mapIdWeb.trim().isNotEmpty,
        DestinoMapa.sinMapa => false,
      };

  factory ConfiguracionMapa.desdeEntorno() {
    if (kIsWeb) {
      return const ConfiguracionMapa.web(
        clave: String.fromEnvironment('VANFULL_MAPS_WEB_KEY'),
        mapIdWeb: String.fromEnvironment('VANFULL_MAPS_WEB_MAP_ID'),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const ConfiguracionMapa.android(
        clave: String.fromEnvironment('VANFULL_MAPS_ANDROID_KEY'),
      );
    }
    return const ConfiguracionMapa();
  }

  @override
  bool operator ==(Object other) =>
      other is ConfiguracionMapa &&
      destino == other.destino &&
      clave == other.clave &&
      mapIdWeb == other.mapIdWeb;
  @override
  int get hashCode => Object.hash(destino, clave, mapIdWeb);
}
