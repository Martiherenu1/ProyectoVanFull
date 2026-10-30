/// BILLETERA es independiente de MERCADO_PAGO. Checkout solo se ofrece con
/// activación explícita; CUENTA_CORRIENTE no es un pago del pasajero.
enum MedioPago {
  efectivo('EFECTIVO', 'Efectivo'),
  transferencia('TRANSFERENCIA', 'Transferencia'),
  billetera('BILLETERA', 'Billetera virtual'),
  mercadoPago('MERCADO_PAGO', 'Mercado Pago (Checkout Pro)');

  const MedioPago(this.valorApi, this.etiqueta);

  final String valorApi;
  final String etiqueta;
}

/// Valores contratados de Pago.estado.
enum EstadoPago {
  pendiente('PENDIENTE', 'Pendiente'),
  confirmado('CONFIRMADO', 'Confirmado'),
  rechazado('RECHAZADO', 'Rechazado');

  const EstadoPago(this.valorApi, this.etiqueta);

  final String valorApi;
  final String etiqueta;
}

/// Lectura de Pago en POST /pagos (CU-014). Al registrarlo queda pendiente:
/// lo confirma administración (CU-016, RN-015) y recién ahí baja la deuda.
class Pago {
  const Pago({
    required this.idPago,
    required this.importe,
    required this.medioPago,
    required this.estado,
  });

  factory Pago.fromJson(Map<String, dynamic> json) => Pago(
    idPago: json['id_pago'] as int,
    importe: (json['importe'] as num).toDouble(),
    medioPago: json['medio_pago'] as String,
    estado: EstadoPago.values.firstWhere(
      (estado) => estado.valorApi == json['estado'],
      orElse: () => throw const FormatException('Estado de pago inválido'),
    ),
  );

  final int idPago;
  final double importe;

  /// Tal como lo devuelve el backend: puede ser un medio que el pasajero no
  /// elige (por ejemplo, uno que registró administración).
  final String medioPago;
  final EstadoPago estado;
}
