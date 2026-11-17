import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/format/fecha_legible.dart';
import 'package:frontend/models/pasajero/comprobante_propio.dart';

Map<String, dynamic> json({
  String tipo = 'RECIBO',
  Object? idPago = 5,
  Object? idContratacion,
  Object? idMovimientoCuenta,
  Object? fechaHora = '2026-10-24T18:05:00',
  Object? importe = 11600,
  Object? medioPago = 'TRANSFERENCIA',
}) => {
  'id_comprobante': 9,
  'tipo': tipo,
  'id_pago': idPago,
  'id_contratacion': idContratacion,
  'id_movimiento_cuenta': idMovimientoCuenta,
  'fecha_hora': fechaHora,
  'importe': importe,
  'medio_pago': medioPago,
};

void main() {
  group('ComprobantePropio', () {
    test('lee un recibo con el origen, la fecha, el importe y el medio', () {
      final c = ComprobantePropio.fromJson(json(importe: 11600.5));

      expect(c.idComprobante, 9);
      expect(c.tipo, TipoComprobante.recibo);
      expect(c.idPago, 5);
      expect(c.idContratacion, isNull);
      expect(c.idMovimientoCuenta, isNull);
      expect(c.fechaHora, DateTime(2026, 10, 24, 18, 5));
      expect(c.importe, 11600.5);
      expect(c.medioPago, 'TRANSFERENCIA');
      expect(c.medioPagoLegible, 'Transferencia');
    });

    test('una factura no tiene fecha ni medio y el importe puede faltar', () {
      final c = ComprobantePropio.fromJson(
        json(
          tipo: 'FACTURA',
          idPago: null,
          idContratacion: 8,
          fechaHora: null,
          importe: null,
          medioPago: null,
        ),
      );

      expect(c.tipo, TipoComprobante.factura);
      expect(c.idContratacion, 8);
      expect(c.fechaHora, isNull);
      expect(c.importe, isNull);
      expect(c.medioPago, isNull);
      expect(c.medioPagoLegible, isNull);
    });

    test('lee los cuatro tipos del contrato', () {
      final lectura = {
        for (final tipo in TipoComprobante.values)
          tipo.valorApi: ComprobantePropio.fromJson(json(tipo: tipo.valorApi))
              .tipo
              .etiqueta,
      };

      expect(lectura, {
        'RECIBO': 'Recibo',
        'FACTURA': 'Factura',
        'NOTA_DE_CREDITO': 'Nota de crédito',
        'NOTA_DE_DEBITO': 'Nota de débito',
      });
    });

    test('un medio que la app no conoce se muestra tal cual', () {
      final c = ComprobantePropio.fromJson(json(medioPago: 'CHEQUE'));
      expect(c.medioPagoLegible, 'CHEQUE');
    });

    test('rechaza un tipo o una fecha inválidos en vez de mostrarlos', () {
      expect(
        () => ComprobantePropio.fromJson(json(tipo: 'TICKET')),
        throwsFormatException,
      );
      expect(
        () => ComprobantePropio.fromJson(json(fechaHora: 'ayer')),
        throwsFormatException,
      );
    });
  });

  group('fechaHoraLegible', () {
    test('escribe dd/mm/aaaa HH:MM con ceros a la izquierda', () {
      expect(fechaHoraLegible(DateTime(2026, 3, 4, 7, 5)), '04/03/2026 07:05');
    });

    test('pasa un instante con zona a la hora del dispositivo', () {
      final instante = DateTime.utc(2026, 10, 24, 18, 5);
      final local = instante.toLocal();
      expect(
        fechaHoraLegible(instante),
        '${fechaLegible(local)} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}',
      );
    });
  });
}
