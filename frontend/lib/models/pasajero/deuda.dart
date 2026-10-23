/// Valores de Deuda.estado que informa GET /pasajeros/me/deuda.
enum EstadoDeuda {
  alDia('al_dia'),
  conDeuda('con_deuda');

  const EstadoDeuda(this.valorApi);

  final String valorApi;
}

/// Lectura de Deuda (CU-006). El saldo es derivado: lo calcula el backend a
/// partir de los movimientos de la cuenta corriente y acá solo se muestra.
class Deuda {
  const Deuda({required this.saldo, required this.estado});

  factory Deuda.fromJson(Map<String, dynamic> json) => Deuda(
    saldo: (json['saldo'] as num).toDouble(),
    estado: EstadoDeuda.values.firstWhere(
      (estado) => estado.valorApi == json['estado'],
      orElse: () => throw const FormatException('Estado de deuda inválido'),
    ),
  );

  final double saldo;
  final EstadoDeuda estado;
}
