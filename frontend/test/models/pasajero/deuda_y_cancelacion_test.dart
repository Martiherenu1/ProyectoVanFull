import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/format/importe.dart';
import 'package:frontend/models/pasajero/deuda.dart';
import 'package:frontend/models/pasajero/reserva.dart';

void main() {
  group('Deuda', () {
    test('lee saldo y estado del contrato', () {
      final deuda = Deuda.fromJson({'saldo': 11600.5, 'estado': 'con_deuda'});

      expect(deuda.saldo, 11600.5);
      expect(deuda.estado, EstadoDeuda.conDeuda);
    });

    test('acepta un saldo entero y rechaza un estado desconocido', () {
      expect(Deuda.fromJson({'saldo': 0, 'estado': 'al_dia'}).saldo, 0.0);
      expect(
        () => Deuda.fromJson({'saldo': 0, 'estado': 'moroso'}),
        throwsFormatException,
      );
    });
  });

  group('ResultadoCancelacion', () {
    test('lee la reserva cancelada y la consecuencia aplicada', () {
      final resultado = ResultadoCancelacion.fromJson({
        'reserva': {
          'id_reserva': 41,
          'id_pasajero': 7,
          'id_viaje': 12,
          'id_recorrido': 3,
          'orden_parada': 2,
          'fecha': '2026-10-30',
          'horario': '06:15',
          'sentido': 'IDA',
          'estado': 'cancelada',
        },
        'cupo_liberado': true,
        'penalidad_aplicada': false,
        'importe_penalidad': 0,
        'motivo': 'Cancelación en término.',
      });

      expect(resultado.reserva.estado, EstadoReserva.cancelada);
      expect(resultado.cupoLiberado, isTrue);
      expect(resultado.penalidadAplicada, isFalse);
      expect(resultado.importePenalidad, 0.0);
      expect(resultado.motivo, 'Cancelación en término.');
    });
  });

  group('importeLegible', () {
    test('punto de miles, coma decimal y dos decimales', () {
      expect(importeLegible(11600), r'$ 11.600,00');
      expect(importeLegible(2900), r'$ 2.900,00');
      expect(importeLegible(38500.5), r'$ 38.500,50');
      expect(importeLegible(1234567.89), r'$ 1.234.567,89');
      expect(importeLegible(0), r'$ 0,00');
      expect(importeLegible(999.999), r'$ 1.000,00');
    });

    test('un negativo lleva signo', () {
      expect(importeLegible(-150), r'-$ 150,00');
    });
  });
}
