import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/maps/configuracion_mapa.dart';

void main() {
  test('Android requiere solo clave, nunca Map ID', () {
    expect(const ConfiguracionMapa.android(clave: 'prueba').disponible, true);
    expect(const ConfiguracionMapa.android(clave: 'prueba').mapIdWeb, isEmpty);
    expect(const ConfiguracionMapa.android().disponible, false);
    expect(const ConfiguracionMapa.android(clave: ' ').disponible, false);
    expect(const ConfiguracionMapa().disponible, false);
  });
  test('Web requiere su clave y Map ID, no configuración parcial', () {
    expect(const ConfiguracionMapa.web(clave: 'prueba').disponible, false);
    expect(const ConfiguracionMapa.web(mapIdWeb: 'prueba').disponible, false);
    expect(
      const ConfiguracionMapa.web(clave: 'prueba', mapIdWeb: 'mapa').disponible,
      true,
    );
  });
}
