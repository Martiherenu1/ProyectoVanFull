import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../models/admin/reserva_admin.dart';
import 'consulta_reservas_admin.dart';

final class ReservasAdminApi implements ConsultaReservasAdmin {
  const ReservasAdminApi(this._client);
  final ApiClient _client;

  @override
  Future<List<ReservaAdmin>> listar() async {
    final json = await _client.get('reservas');
    try {
      return (json as List)
          .map((item) => ReservaAdmin.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      throw const ApiProtocolException(200, 'Listado de reservas inválido.');
    }
  }
}

final class ConsultaReservasAdminProtegida implements ConsultaReservasAdmin {
  const ConsultaReservasAdminProtegida(this.cargar);
  final Future<List<ReservaAdmin>> Function() cargar;

  @override
  Future<List<ReservaAdmin>> listar() => cargar();
}
