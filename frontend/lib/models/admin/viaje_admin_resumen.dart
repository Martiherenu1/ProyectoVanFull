import '../chofer/viaje_resumen.dart';

/// Lectura administrativa de `Viaje`, con la capacidad usada por CU-018.
final class ViajeAdminResumen extends ViajeResumen {
  const ViajeAdminResumen({
    required super.idViaje,
    required super.idServicio,
    required super.idRecorrido,
    required super.fecha,
    required super.sentido,
    required super.estado,
    super.idVehiculo,
    super.idChofer,
    super.horario,
    this.capacidadPlanificada,
  });

  factory ViajeAdminResumen.fromJson(Map<String, dynamic> json) {
    final base = ViajeResumen.fromJson(json);
    final capacidad = json['capacidad_planificada'];
    if (capacidad != null && capacidad is! int) {
      throw const FormatException('Capacidad planificada inválida');
    }
    return ViajeAdminResumen(
      idViaje: base.idViaje,
      idServicio: base.idServicio,
      idRecorrido: base.idRecorrido,
      idVehiculo: base.idVehiculo,
      idChofer: base.idChofer,
      fecha: base.fecha,
      horario: base.horario,
      sentido: base.sentido,
      estado: base.estado,
      capacidadPlanificada: capacidad as int?,
    );
  }

  final int? capacidadPlanificada;
}
