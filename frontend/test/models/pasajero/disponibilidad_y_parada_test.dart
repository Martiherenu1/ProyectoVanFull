import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';
import 'package:frontend/models/pasajero/disponibilidad_viaje.dart';
import 'package:frontend/models/pasajero/parada.dart';

Map<String, dynamic> disponibilidadJson() => {
  'id_viaje': 12,
  'id_servicio': 2,
  'id_recorrido': 3,
  'fecha': '2026-10-30',
  'horario': '06:15',
  'sentido': 'IDA',
  'cupo_disponible': 14,
};

void main() {
  group('DisponibilidadViaje', () {
    test('lee todos los campos del contrato', () {
      final viaje = DisponibilidadViaje.fromJson(disponibilidadJson());

      expect(viaje.idViaje, 12);
      expect(viaje.idServicio, 2);
      expect(viaje.idRecorrido, 3);
      expect(viaje.fecha, DateTime(2026, 10, 30));
      expect(viaje.horario, '06:15');
      expect(viaje.sentido, SentidoViaje.ida);
      expect(viaje.cupoDisponible, 14);
    });

    test('horario y cupo ausentes quedan nulos, no en cero', () {
      final json = disponibilidadJson()
        ..remove('horario')
        ..remove('cupo_disponible');
      final viaje = DisponibilidadViaje.fromJson(json);

      expect(viaje.horario, isNull);
      expect(viaje.cupoDisponible, isNull);
    });

    test('rechaza una fecha imposible en vez de mostrar otro día', () {
      final json = disponibilidadJson()..['fecha'] = '2026-02-31';

      expect(
        () => DisponibilidadViaje.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza un sentido desconocido', () {
      final json = disponibilidadJson()..['sentido'] = 'LATERAL';

      expect(
        () => DisponibilidadViaje.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Parada', () {
    test('lee los campos y convierte las coordenadas a double', () {
      final parada = Parada.fromJson({
        'id_parada': 7,
        'orden': 2,
        'nombre_descripcion': 'Plaza Belgrano',
        'direccion': 'Belgrano 100',
        'latitud': -26,
        'longitud': -65.2,
        'comprometida': true,
      });

      expect(parada.idParada, 7);
      expect(parada.orden, 2);
      expect(parada.latitud, -26.0);
      expect(parada.longitud, -65.2);
      expect(parada.comprometida, isTrue);
      expect(parada.titulo, 'Plaza Belgrano');
      expect(parada.detalle, 'Belgrano 100');
    });

    test('sin nombre usa la dirección, y sin ninguna el orden', () {
      final conDireccion = Parada.fromJson({
        'id_parada': 1,
        'orden': 1,
        'direccion': 'Av. San Martín 1240',
        'comprometida': false,
      });
      final vacia = Parada.fromJson({
        'id_parada': 2,
        'orden': 4,
        'comprometida': false,
      });

      expect(conDireccion.titulo, 'Av. San Martín 1240');
      expect(conDireccion.detalle, isNull);
      expect(vacia.titulo, 'Parada 4');
      expect(vacia.detalle, isNull);
    });
  });
}
