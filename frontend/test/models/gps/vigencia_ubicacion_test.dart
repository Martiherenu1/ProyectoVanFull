import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/gps/ubicacion_viaje.dart';
import 'package:frontend/models/gps/vigencia_ubicacion.dart';

final t = DateTime.utc(2026, 11, 16);
UbicacionViaje punto({
  int edad = 29,
  bool? marcada,
  bool sinCache = true,
  bool referencia = true,
  int segundo = 0,
}) => UbicacionViaje(
  1,
  0,
  0,
  t.add(Duration(seconds: segundo)),
  marcada ?? edad > 30,
  null,
  fechaEvaluacion: referencia ? t.add(Duration(seconds: segundo + edad)) : null,
  sinCache: sinCache,
);

void main() {
  for (final caso in [
    (29, 0, VigenciaUbicacion.sinMarca),
    (30, 0, VigenciaUbicacion.sinMarca),
    (31, 0, VigenciaUbicacion.desactualizada),
    (29, 2, VigenciaUbicacion.incierta),
    (28, 2, VigenciaUbicacion.sinMarca),
    (30, 1, VigenciaUbicacion.incierta),
  ]) {
    test('frontera A=${caso.$1}, RTT=${caso.$2}', () {
      final v = VigenciaUbicacion();
      v.aceptar(
        punto(edad: caso.$1),
        inicio: Duration.zero,
        recepcion: Duration(seconds: caso.$2),
      );
      expect(v.texto(Duration(seconds: caso.$2)), caso.$3);
    });
  }
  test('[29,31] no demuestra >30; dos segundos después sí', () {
    final v = VigenciaUbicacion();
    v.aceptar(
      punto(),
      inicio: Duration.zero,
      recepcion: const Duration(seconds: 2),
    );
    expect(v.texto(const Duration(seconds: 2)), VigenciaUbicacion.incierta);
    expect(v.texto(const Duration(seconds: 3)), VigenciaUbicacion.incierta);
    expect(
      v.texto(const Duration(seconds: 4)),
      VigenciaUbicacion.desactualizada,
    );
  });
  for (final tipo in [
    'sin S',
    'sin no-store',
    'S negativo',
    'bool incoherente',
    'RTT negativo',
    'sin reloj',
    'ciclo de vida',
  ]) {
    test('$tipo no produce vigencia acreditada', () {
      final v = VigenciaUbicacion();
      v.aceptar(
        punto(
          referencia: tipo != 'sin S',
          sinCache: tipo != 'sin no-store',
          edad: tipo == 'S negativo' ? -1 : 29,
          marcada: tipo == 'bool incoherente' ? false : null,
        ),
        inicio: tipo == 'sin reloj' ? null : const Duration(seconds: 2),
        recepcion: Duration(seconds: tipo == 'RTT negativo' ? 1 : 2),
        continuidad: tipo != 'ciclo de vida',
      );
      if (tipo == 'bool incoherente') {
        v.aceptar(
          punto(edad: 31, marcada: false),
          inicio: Duration.zero,
          recepcion: const Duration(seconds: 2),
        );
      }
      expect(
        v.texto(const Duration(seconds: 2)),
        VigenciaUbicacion.noVerificable,
      );
    });
  }
  test('S repetido no rejuvenece; pérdida de ancla no borra marca', () {
    final v = VigenciaUbicacion();
    v.aceptar(punto(), inicio: Duration.zero, recepcion: Duration.zero);
    v.aceptar(
      punto(),
      inicio: const Duration(seconds: 2),
      recepcion: const Duration(seconds: 2),
    );
    expect(
      v.texto(const Duration(seconds: 2)),
      VigenciaUbicacion.desactualizada,
    );
    v.invalidarAncla();
    v.aceptar(punto(referencia: false), inicio: null, recepcion: null);
    expect(v.texto(null), VigenciaUbicacion.desactualizada);
  });
  test('servidor true no se limpia con false repetido', () {
    final v = VigenciaUbicacion();
    v.aceptar(punto(edad: 31), inicio: Duration.zero, recepcion: Duration.zero);
    v.aceptar(punto(), inicio: Duration.zero, recepcion: Duration.zero);
    expect(v.texto(Duration.zero), VigenciaUbicacion.desactualizada);
  });
  test('nuevo S no borra desactualización alcanzada antes de recibirlo', () {
    final v = VigenciaUbicacion();
    v.aceptar(punto(), inicio: Duration.zero, recepcion: Duration.zero);
    v.aceptar(
      punto(edad: 30),
      inicio: const Duration(seconds: 2),
      recepcion: const Duration(seconds: 2),
    );
    expect(
      v.texto(const Duration(seconds: 2)),
      VigenciaUbicacion.desactualizada,
    );
  });
  test('vehículo detenido con T posterior es nueva posición', () {
    final v = VigenciaUbicacion();
    v.aceptar(punto(edad: 31), inicio: Duration.zero, recepcion: Duration.zero);
    v.aceptar(
      punto(edad: 0, segundo: 31),
      inicio: Duration.zero,
      recepcion: Duration.zero,
    );
    expect(v.texto(Duration.zero), VigenciaUbicacion.sinMarca);
    v.limpiar();
    expect(v.texto(Duration.zero), VigenciaUbicacion.noVerificable);
  });
  test('retroceso monotónico y S decreciente invalidan referencia', () {
    final v = VigenciaUbicacion();
    v.aceptar(
      punto(),
      inicio: const Duration(seconds: 5),
      recepcion: const Duration(seconds: 5),
    );
    expect(
      v.texto(const Duration(seconds: 4)),
      VigenciaUbicacion.noVerificable,
    );
    v.aceptar(
      punto(edad: 28),
      inicio: const Duration(seconds: 5),
      recepcion: const Duration(seconds: 5),
    );
    expect(
      v.texto(const Duration(seconds: 5)),
      VigenciaUbicacion.noVerificable,
    );
  });
}
