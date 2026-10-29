import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../models/pasajero/deuda.dart';
import 'consulta_deuda_admin.dart';

final class DeudaAdminApi implements ConsultaDeudaAdmin {
  const DeudaAdminApi(this._client);
  final ApiClient _client;

  @override
  Future<Deuda> consultar(int idCliente) async {
    if (idCliente <= 0) throw ArgumentError.value(idCliente, 'idCliente');
    final json = await _client.get('clientes/$idCliente/deuda');
    try {
      final deuda = Deuda.fromJson(json as Map<String, dynamic>);
      if (!deuda.saldo.isFinite || deuda.saldo < 0) {
        throw const FormatException('Saldo inválido');
      }
      return deuda;
    } catch (_) {
      throw const ApiProtocolException(200, 'Respuesta de deuda inválida.');
    }
  }
}

/// Conserva la interfaz inyectable de la pantalla con la protección de sesión.
final class ConsultaDeudaAdminProtegida implements ConsultaDeudaAdmin {
  const ConsultaDeudaAdminProtegida(this.consultarCliente);
  final Future<Deuda?> Function(int) consultarCliente;

  @override
  Future<Deuda?> consultar(int idCliente) => consultarCliente(idCliente);
}
