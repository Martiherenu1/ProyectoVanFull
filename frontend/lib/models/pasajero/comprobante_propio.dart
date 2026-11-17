/// Valores contratados de ComprobantePropio.tipo (CU-035).
enum TipoComprobante {
  recibo('RECIBO', 'Recibo'),
  factura('FACTURA', 'Factura'),
  notaDeCredito('NOTA_DE_CREDITO', 'Nota de crédito'),
  notaDeDebito('NOTA_DE_DEBITO', 'Nota de débito');

  const TipoComprobante(this.valorApi, this.etiqueta);

  final String valorApi;
  final String etiqueta;
}

/// Lectura de ComprobantePropio en GET /pasajeros/me/comprobantes (CU-035,
/// RF-037). La tabla `comprobante` solo guarda el tipo y un origen, así que
/// fecha, importe y medio son los del origen y pueden faltar: una FACTURA no
/// tiene fecha y su importe puede no estar. No se inventan ni se completan.
class ComprobantePropio {
  const ComprobantePropio({
    required this.idComprobante,
    required this.tipo,
    this.idPago,
    this.idContratacion,
    this.idMovimientoCuenta,
    this.fechaHora,
    this.importe,
    this.medioPago,
  });

  factory ComprobantePropio.fromJson(Map<String, dynamic> json) {
    final fechaTexto = json['fecha_hora'] as String?;
    DateTime? fechaHora;
    if (fechaTexto != null) {
      fechaHora = DateTime.tryParse(fechaTexto);
      if (fechaHora == null) {
        throw const FormatException('Fecha de comprobante inválida');
      }
    }
    return ComprobantePropio(
      idComprobante: json['id_comprobante'] as int,
      tipo: TipoComprobante.values.firstWhere(
        (tipo) => tipo.valorApi == json['tipo'],
        orElse: () =>
            throw const FormatException('Tipo de comprobante inválido'),
      ),
      idPago: json['id_pago'] as int?,
      idContratacion: json['id_contratacion'] as int?,
      idMovimientoCuenta: json['id_movimiento_cuenta'] as int?,
      fechaHora: fechaHora,
      importe: (json['importe'] as num?)?.toDouble(),
      medioPago: json['medio_pago'] as String?,
    );
  }

  final int idComprobante;
  final TipoComprobante tipo;

  /// Exactamente uno de los tres orígenes viene informado (MR-R28): el pago de
  /// un RECIBO, la contratación de una FACTURA o el movimiento de una nota.
  final int? idPago;
  final int? idContratacion;
  final int? idMovimientoCuenta;

  /// La del pago o la del movimiento; `null` en una FACTURA.
  final DateTime? fechaHora;

  /// El del pago, el acordado de la contratación (puede faltar) o el del
  /// movimiento.
  final double? importe;

  /// Valor de la base (`EFECTIVO`, `TRANSFERENCIA`, …); solo en un RECIBO.
  final String? medioPago;

  /// El medio de pago como se le dice al pasajero. Un valor que la app no
  /// conoce se muestra tal cual en vez de esconderlo.
  String? get medioPagoLegible => switch (medioPago) {
    null => null,
    'EFECTIVO' => 'Efectivo',
    'TRANSFERENCIA' => 'Transferencia',
    'BILLETERA' => 'Billetera virtual',
    'MERCADO_PAGO' => 'Mercado Pago',
    'CUENTA_CORRIENTE' => 'Cuenta corriente',
    final otro => otro,
  };
}
