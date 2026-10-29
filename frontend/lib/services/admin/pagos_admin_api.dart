import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../models/admin/pago_admin.dart';

enum DecisionPago {
  confirmar('CONFIRMADO'),
  rechazar('RECHAZADO');

  const DecisionPago(this.valorApi);
  final String valorApi;
}

final class PagosAdminApi {
  const PagosAdminApi(this._client);
  final ApiClient _client;

  PagoAdmin _leer(Object? json) {
    try {
      return PagoAdmin.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      throw const ApiProtocolException(200, 'Respuesta de pago inválida.');
    }
  }

  Future<List<PagoAdmin>> pendientes() async {
    final json = await _client.get('pagos/pendientes');
    if (json is! List) {
      throw const ApiProtocolException(200, 'Listado de pagos inválido.');
    }
    return json.map(_leer).toList(growable: false);
  }

  Future<PagoAdmin> decidir(int id, DecisionPago decision) async => _leer(
    await _client.post(
      'pagos/$id/confirmacion',
      body: {'decision': decision.valorApi},
    ),
  );
}
