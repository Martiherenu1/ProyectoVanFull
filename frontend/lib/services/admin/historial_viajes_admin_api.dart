import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../models/admin/historial_viaje.dart';

/// Adaptador de CU-026: historial de viajes (`/administracion/historial-viajes`).
///
/// Solo lectura. Qué es un viaje «anterior» lo decide FastAPI.
final class HistorialViajesAdminApi {
  const HistorialViajesAdminApi(this._client);

  final ApiClient _client;

  Future<List<HistorialViaje>> listar(HistorialFiltros filtros) async {
    final query = filtros.toQuery();
    final json = await _client.get(
      'administracion/historial-viajes',
      queryParameters: query.isEmpty ? null : query,
    );
    try {
      final items = (json as Map<String, dynamic>)['items'] as List;
      return items
          .map((e) => HistorialViaje.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      throw ApiProtocolException(200, 'Historial de viajes inválido.');
    }
  }

  Future<HistorialViajeDetalle> detalle(int idViaje) async {
    final json = await _client.get('administracion/historial-viajes/$idViaje');
    try {
      return HistorialViajeDetalle.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      throw ApiProtocolException(200, 'Detalle de viaje inválido.');
    }
  }
}
