import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/format/importe.dart';

void main() {
  test('leerImporte acepta las formas habituales', () {
    expect(leerImporte('11600'), 11600);
    expect(leerImporte(r'$ 11.600'), 11600);
    expect(leerImporte('11.600,50'), 11600.5);
    expect(leerImporte('11600,5'), 11600.5);
    expect(leerImporte('11600.5'), 11600.5);
    expect(leerImporte('1.234.567'), 1234567);
  });

  test('leerImporte rechaza lo que no es un importe', () {
    for (final texto in ['', 'abc', '-5', '10,555', '1,2,3', '12.5.6']) {
      expect(leerImporte(texto), isNull, reason: texto);
    }
  });

  test('importeEditable usa coma solo si hay centavos', () {
    expect(importeEditable(11600), '11600');
    expect(importeEditable(11600.5), '11600,50');
    expect(importeEditable(0.07), '0,07');
  });
}
