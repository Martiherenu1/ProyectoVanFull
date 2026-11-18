import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../models/admin/administrador.dart';

/// Adaptador de CU-032: el dueño gestiona cuentas de administrador.
///
/// El rol `dueno` y las reglas (DNI e identificador únicos, sin borrado físico)
/// las valida FastAPI; acá solo se arma el pedido y se valida la forma.
final class AdministradoresAdminApi {
  const AdministradoresAdminApi(this._client);

  final ApiClient _client;

  Future<List<Administrador>> listar() async {
    final json = await _client.get('administradores');
    try {
      final items = (json as Map<String, dynamic>)['items'] as List;
      return items
          .map((e) => Administrador.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      throw const ApiProtocolException(
        200,
        'Listado de administradores inválido.',
      );
    }
  }

  Future<Administrador> crear(AdministradorCreate datos) async =>
      _administrador(
        await _client.post('administradores', body: datos.toJson()),
      );

  /// [cambios] lleva solo los campos modificados, con los nombres del contrato.
  Future<Administrador> modificar(
    int idCuentaAcceso,
    Map<String, Object?> cambios,
  ) async => _administrador(
    await _client.patch('administradores/$idCuentaAcceso', body: cambios),
  );

  Future<Administrador> deshabilitar(int idCuentaAcceso) async =>
      _administrador(
        await _client.post('administradores/$idCuentaAcceso/deshabilitacion'),
      );

  Administrador _administrador(Object? json) {
    try {
      return Administrador.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      throw const ApiProtocolException(200, 'Administrador inválido.');
    }
  }
}
