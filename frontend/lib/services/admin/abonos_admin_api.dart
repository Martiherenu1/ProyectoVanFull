import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../models/admin/abono_gestion.dart';

/// Adaptador de CU-028: abonos mensuales (`/administracion/abonos`).
///
/// FastAPI decide qué servicios admiten abono y los estados; acá solo se arma
/// el pedido y se valida la forma de la respuesta.
final class AbonosAdminApi {
  const AbonosAdminApi(this._client);

  final ApiClient _client;

  Future<List<AbonoGestion>> listar({int? idPasajero}) async {
    final json = await _client.get(
      'administracion/abonos',
      queryParameters: idPasajero == null
          ? null
          : {'id_pasajero': '$idPasajero'},
    );
    try {
      final items = (json as Map<String, dynamic>)['items'] as List;
      return items
          .map((e) => AbonoGestion.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      throw ApiProtocolException(200, 'Listado de abonos inválido.');
    }
  }

  /// Servicios del catálogo (consulta pública del contrato).
  Future<List<ServicioAbono>> listarServicios() async {
    final json = await _client.get('servicios');
    try {
      return (json as List)
          .map((e) => ServicioAbono.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      throw ApiProtocolException(200, 'Listado de servicios inválido.');
    }
  }

  Future<AbonoGestion> crear(AbonoGestionCreate datos) async {
    final json = await _client.post(
      'administracion/abonos',
      body: datos.toJson(),
    );
    return _uno(json);
  }

  /// Solo modalidad y días: el estado no se edita a mano.
  Future<AbonoGestion> modificar(int id, Map<String, Object?> cambios) async {
    final json = await _client.patch(
      'administracion/abonos/$id',
      body: cambios,
    );
    return _uno(json);
  }

  Future<AbonoGestion> agregarPeriodo(int id, String periodo) async {
    final json = await _client.post(
      'administracion/abonos/$id/periodos',
      body: {'periodo': periodo},
    );
    return _uno(json);
  }

  AbonoGestion _uno(Object? json) {
    try {
      return AbonoGestion.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      throw ApiProtocolException(200, 'Abono inválido.');
    }
  }
}
