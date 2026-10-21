import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';

// Respuestas sintéticas del contrato; no datos de demo ni prueba HTTP.
Map<String, dynamic> respuesta() => {
  'id_viaje': 41,
  'id_servicio': 2,
  'id_recorrido': 3,
  'id_vehiculo': 4,
  'id_chofer': 5,
  'fecha': '2026-10-30',
  'horario': '07:30',
  'sentido': 'IDA',
  'estado': 'programado',
};

void main() {
  test('lee los campos de Viaje sin confundir identificadores con nombres', () {
    final viaje = ViajeResumen.fromJson(respuesta());
    expect(viaje.idViaje, 41);
    expect(viaje.idServicio, 2);
    expect(viaje.idRecorrido, 3);
    expect(viaje.idVehiculo, 4);
    expect(viaje.idChofer, 5);
    expect(viaje.fecha, DateTime(2026, 10, 30));
    expect(viaje.fecha.isUtc, isFalse);
    expect(viaje.fecha.hour, 0);
    expect(viaje.horario, '07:30');
    expect(viaje.sentido, SentidoViaje.ida);
    expect(viaje.estado, EstadoViaje.programado);
  });

  test('acepta horario omitido y asignaciones nulas u omitidas', () {
    final json = respuesta()
      ..remove('horario')
      ..remove('id_chofer')
      ..['id_vehiculo'] = null;
    final viaje = ViajeResumen.fromJson(json);
    expect(viaje.horario, isNull);
    expect(viaje.idChofer, isNull);
    expect(viaje.idVehiculo, isNull);
  });

  test('reconoce vuelta y todos los estados contratados', () {
    for (final estado in EstadoViaje.values) {
      final viaje = ViajeResumen.fromJson(
        respuesta()
          ..['sentido'] = 'VUELTA'
          ..['estado'] = estado.valorApi,
      );
      expect(viaje.sentido, SentidoViaje.vuelta);
      expect(viaje.estado, estado);
    }
  });

  test(
    'no convierte fechas imposibles ni valores desconocidos en datos válidos',
    () {
      for (final cambio in [
        {'fecha': '2026-02-30'},
        {'fecha': '30/10/2026'},
        {'fecha': '2026-10-30T00:00:00Z'},
        {'fecha': '2026-10-30T00:00:00-03:00'},
        {'sentido': 'OTRO'},
        {'estado': 'otro'},
      ]) {
        expect(
          () => ViajeResumen.fromJson(respuesta()..addAll(cambio)),
          throwsFormatException,
        );
      }
    },
  );
}
