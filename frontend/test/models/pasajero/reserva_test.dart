import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';
import 'package:frontend/models/pasajero/reserva.dart';

Map<String, dynamic> reservaJson() => {
  'id_reserva': 41,
  'id_pasajero': 7,
  'id_viaje': 12,
  'id_recorrido': 3,
  'orden_parada': 2,
  'fecha': '2026-10-30',
  'horario': '06:15',
  'sentido': 'IDA',
  'estado': 'consolidada',
};

void main() {
  group('Reserva', () {
    test('lee todos los campos del contrato', () {
      final reserva = Reserva.fromJson(reservaJson());

      expect(reserva.idReserva, 41);
      expect(reserva.idViaje, 12);
      expect(reserva.idRecorrido, 3);
      expect(reserva.ordenParada, 2);
      expect(reserva.fecha, DateTime(2026, 10, 30));
      expect(reserva.horario, '06:15');
      expect(reserva.sentido, SentidoViaje.ida);
      expect(reserva.estado, EstadoReserva.consolidada);
    });

    test('el horario nulo queda nulo', () {
      final reserva = Reserva.fromJson(reservaJson()..['horario'] = null);

      expect(reserva.horario, isNull);
    });

    test('consolidada se muestra como Confirmada', () {
      expect(EstadoReserva.consolidada.etiqueta, 'Confirmada');
      expect(EstadoReserva.provisional.etiqueta, 'Provisional');
    });

    test('rechaza una fecha imposible, un sentido o un estado desconocido', () {
      expect(
        () => Reserva.fromJson(reservaJson()..['fecha'] = '2026-02-31'),
        throwsFormatException,
      );
      expect(
        () => Reserva.fromJson(reservaJson()..['sentido'] = 'LATERAL'),
        throwsFormatException,
      );
      expect(
        () => Reserva.fromJson(reservaJson()..['estado'] = 'pagada'),
        throwsFormatException,
      );
    });
  });

  group('ReservaRechazada', () {
    test('lee el cuerpo de error del contrato', () {
      final rechazo = ReservaRechazada.fromJson({
        'error': {
          'codigo': 'CUPO_NO_DISPONIBLE',
          'mensaje': 'No hay lugares disponibles en este viaje.',
          'detalles': {'lista_espera': true},
        },
      });

      expect(rechazo.codigo, 'CUPO_NO_DISPONIBLE');
      expect(rechazo.mensaje, 'No hay lugares disponibles en este viaje.');
      expect(rechazo.listaEspera, isTrue);
    });

    test('sin detalles, no hay lista de espera', () {
      final rechazo = ReservaRechazada.fromJson({
        'error': {'codigo': 'VIAJE_NO_RESERVABLE', 'mensaje': 'No admite.'},
      });

      expect(rechazo.listaEspera, isFalse);
    });
  });
}
