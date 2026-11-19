import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../models/admin/tarifa_gestion.dart';

/// Adaptador de CU-031: el dueño gestiona tarifas (`/administracion/tarifas`).
///
/// El rol `dueno` y las reglas las valida FastAPI. Modificar una tarifa no
/// recalcula contrataciones ni reservas (A2/RN-012: pendiente de decisión).
final class TarifasAdminApi {
  const TarifasAdminApi(this._client);

  final ApiClient _client;

  static const _ruta = 'administracion/tarifas';

  Future<List<TarifaGestion>> listar() async {
    final json = await _client.get(_ruta);
    try {
      final items = (json as Map<String, dynamic>)['items'] as List;
      return items
          .map((e) => TarifaGestion.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      throw const ApiProtocolException(200, 'Listado de tarifas inválido.');
    }
  }

  Future<TarifaGestion> crear(TarifaGestionCreate datos) async =>
      _tarifa(await _client.post(_ruta, body: datos.toJson()));

  /// [cambios] lleva solo los campos modificados, con los nombres del contrato.
  /// `tipo` y `fecha_vigencia` aceptan `null` para vaciarlos.
  Future<TarifaGestion> modificar(
    int idTarifa,
    Map<String, Object?> cambios,
  ) async => _tarifa(await _client.patch('$_ruta/$idTarifa', body: cambios));

  TarifaGestion _tarifa(Object? json) {
    try {
      return TarifaGestion.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      throw const ApiProtocolException(200, 'Tarifa inválida.');
    }
  }
}
