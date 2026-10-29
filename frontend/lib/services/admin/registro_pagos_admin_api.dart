import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../models/admin/borrador_imputacion_pago.dart';
import '../../models/pasajero/pago.dart';

/// Integración parcial CU-014/#84. Usa transporte y permisos existentes.
final class RegistroPagosAdminApi {
  const RegistroPagosAdminApi(this._client);
  final ApiClient _client;

  Future<Pago> registrar({
    required int idCliente,
    required double importe,
    required MedioPago medio,
    BorradorImputacionPago? borrador,
  }) async {
    if (borrador?.tieneDatos ?? false) {
      throw UnsupportedError('Tipo y respaldo aún no pueden guardarse.');
    }
    // Bloqueo técnico de #84: no simular en Flutter la imputación del efectivo.
    if (medio == MedioPago.efectivo) {
      throw UnsupportedError('Efectivo pendiente de integración.');
    }
    if (idCliente <= 0 || !importe.isFinite || importe < 0) {
      throw ArgumentError('Datos de pago inválidos.');
    }
    final json = await _client.post(
      'pagos',
      body: {
        'id_cliente': idCliente,
        'importe': importe,
        'medio_pago': medio.valorApi,
      },
    );
    try {
      if (json is! Map<String, dynamic> || json['id_cliente'] != idCliente) {
        throw const FormatException();
      }
      return Pago.fromJson(json);
    } catch (_) {
      throw const ApiProtocolException(
        201,
        'Respuesta de registro de pago inválida.',
      );
    }
  }
}
