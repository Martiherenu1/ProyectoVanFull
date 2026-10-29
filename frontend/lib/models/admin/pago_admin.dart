import '../pasajero/pago.dart';

/// Pago del contrato, conservando cliente y fecha para la decisión administrativa.
final class PagoAdmin extends Pago {
  const PagoAdmin({
    required super.idPago,
    required super.importe,
    required super.medioPago,
    required super.estado,
    required this.idCliente,
    required this.fechaHora,
  });

  factory PagoAdmin.fromJson(Map<String, dynamic> json) {
    final pago = Pago.fromJson(json);
    return PagoAdmin(
      idPago: pago.idPago,
      importe: pago.importe,
      medioPago: pago.medioPago,
      estado: pago.estado,
      idCliente: json['id_cliente'] as int,
      fechaHora: DateTime.parse(json['fecha_hora'] as String),
    );
  }
  final int idCliente;
  final DateTime fechaHora;
}
