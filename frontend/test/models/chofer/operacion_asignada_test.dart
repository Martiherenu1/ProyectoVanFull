import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/chofer/operacion_asignada.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';

import '../../fixtures/chofer/operacion_asignada_fixture.dart';

void main() {
  test('lee el detalle real contratado reutilizando ViajeResumen', () {
    final d = OperacionAsignada.fromJson(detalleJson());
    expect(d.viaje, isA<ViajeResumen>());
    expect(d.viaje.idViaje, 41);
    expect(d.viaje.fecha, DateTime(2026, 10, 30));
    expect(d.viaje.horario, '07:30');
    expect(d.capacidadPlanificada, 18);
    expect(d.paradas.map((p) => p.idParada), [11, 12]);
    expect(d.paradas.map((p) => p.orden), [1, 2]);
    expect(d.paradas.first.latitud, -34.0);
    expect(d.paradas.first.longitud, -58.5);
    expect(d.paradas.first.comprometida, isTrue);
    expect(d.paradas.last.comprometida, isFalse);
    expect(d.pasajerosConReserva.map((p) => p.estado), [
      EstadoReservaOperacion.consolidada,
      EstadoReservaOperacion.provisional,
    ]);
    final p = d.pasajerosConReserva.first;
    expect(
      [p.idReserva, p.idPasajero, p.idViaje, p.ordenParada],
      [61, 21, 41, 1],
    );
    expect([p.nombre, p.apellido, p.dni], ['Ana', 'Prueba', '90000011']);
    expect(p.fotografia, isNull);
    expect(d.pasajerosConReserva.last.fotografia, 'foto-referenciada');
    expect(d.pasajerosConReserva.map((p) => p.abordajeRegistrado), [
      true,
      false,
    ]);
    expect(d.integrantesNomina.single.idIntegranteNomina, 71);
    expect(d.cantidades.consolidadas, 1);
    expect(d.cantidades.provisionales, 1);
    expect(d.cantidades.totalReservas, 2);
    expect(d.cantidades.totalNomina, 1);
    expect(d.cantidades.abordajesRegistrados, 1);
  });

  test('admite null requerido y omisiones que emite el backend', () {
    final json = detalleJson();
    (json['viaje'] as Map<String, dynamic>)
      ..remove('horario')
      ..['id_chofer'] = null
      ..['id_vehiculo'] = null;
    json['capacidad_planificada'] = null;
    final d = OperacionAsignada.fromJson(json);
    expect(d.capacidadPlanificada, isNull);
    expect(d.viaje.horario, isNull);
    expect(d.viaje.idChofer, isNull);
    expect(d.viaje.idVehiculo, isNull);
    final parada = d.paradas.last;
    expect([
      parada.nombreDescripcion,
      parada.direccion,
      parada.latitud,
      parada.longitud,
    ], everyElement(isNull));
  });

  test(
    'no trata la omisión de fotografía o capacidad como null contratado',
    () {
      final sinCapacidad = detalleJson()..remove('capacidad_planificada');
      expect(
        () => OperacionAsignada.fromJson(sinCapacidad),
        throwsFormatException,
      );
      final sinFoto = detalleJson();
      (sinFoto['pasajeros_con_reserva'] as List).first.remove('fotografia');
      expect(() => OperacionAsignada.fromJson(sinFoto), throwsFormatException);
    },
  );

  test('listas vacías y cantidades cero son un detalle disponible', () {
    final json = detalleJson()
      ..['paradas'] = []
      ..['pasajeros_con_reserva'] = []
      ..['integrantes_nomina'] = []
      ..['cantidades'] = {
        'consolidadas': 0,
        'provisionales': 0,
        'total_reservas': 0,
        'total_nomina': 0,
        'abordajes_registrados': 0,
      };
    final d = OperacionAsignada.fromJson(json);
    expect(d.paradas, isEmpty);
    expect(d.pasajerosConReserva, isEmpty);
    expect(d.integrantesNomina, isEmpty);
    expect(d.cantidades.totalReservas, 0);
    expect(d.cantidades.totalNomina, 0);
  });

  test(
    'no interpreta una reserva cancelada como provisional o consolidada',
    () {
      final json = detalleJson();
      (json['pasajeros_con_reserva'] as List).first['estado'] = 'cancelada';
      expect(() => OperacionAsignada.fromJson(json), throwsFormatException);
    },
  );

  test('no inventa abordaje cuando falta la marca requerida', () {
    final json = detalleJson();
    (json['pasajeros_con_reserva'] as List).first.remove('abordaje_registrado');
    expect(() => OperacionAsignada.fromJson(json), throwsA(isA<TypeError>()));
  });

  test('listas inmutables e independientes del JSON de entrada', () {
    final json = detalleJson();
    final d = OperacionAsignada.fromJson(json);
    (json['paradas'] as List).clear();
    (json['pasajeros_con_reserva'] as List).clear();
    (json['integrantes_nomina'] as List).clear();
    expect(d.paradas.length, 2);
    expect(d.pasajerosConReserva.length, 2);
    expect(d.integrantesNomina.length, 1);
    expect(() => d.paradas.clear(), throwsUnsupportedError);
    expect(() => d.pasajerosConReserva.clear(), throwsUnsupportedError);
    expect(() => d.integrantesNomina.clear(), throwsUnsupportedError);
  });
}
