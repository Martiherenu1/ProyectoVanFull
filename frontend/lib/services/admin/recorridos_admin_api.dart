import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../models/admin/recorrido_gestion.dart';

/// Adaptador de CU-019: recorridos y paradas (`/administracion/...`).
///
/// FastAPI hace cumplir RN-021 (paradas comprometidas) y las reservas; acá solo
/// se arma el pedido y se valida la forma de la respuesta.
final class RecorridosAdminApi {
  const RecorridosAdminApi(this._client);

  final ApiClient _client;

  Future<List<RecorridoGestion>> listarRecorridos() async {
    final json = await _client.get('administracion/recorridos');
    return _lista(json, RecorridoGestion.fromJson, 'recorridos');
  }

  Future<List<ParadaCatalogo>> listarParadas() async {
    final json = await _client.get('administracion/paradas');
    return _lista(json, ParadaCatalogo.fromJson, 'paradas');
  }

  Future<ParadaCatalogo> crearParada(ParadaCatalogoCreate datos) async {
    final json = await _client.post(
      'administracion/paradas',
      body: datos.toJson(),
    );
    return _uno(json, ParadaCatalogo.fromJson, 'Parada inválida.');
  }

  /// [idParadas] en orden: la primera es el orden 1.
  Future<RecorridoGestion> crearRecorrido(List<int> idParadas) async {
    final json = await _client.post(
      'administracion/recorridos',
      body: {'id_paradas': idParadas},
    );
    return _uno(json, RecorridoGestion.fromJson, 'Recorrido inválido.');
  }

  /// PATCH: deja el recorrido con estas paradas, en este orden (todo o nada).
  Future<RecorridoGestion> reemplazarParadas(
    int idRecorrido,
    List<int> idParadas,
  ) async {
    final json = await _client.patch(
      'administracion/recorridos/$idRecorrido',
      body: {'id_paradas': idParadas},
    );
    return _uno(json, RecorridoGestion.fromJson, 'Recorrido inválido.');
  }

  List<T> _lista<T>(
    Object? json,
    T Function(Map<String, dynamic>) leer,
    String que,
  ) {
    try {
      final items = (json as Map<String, dynamic>)['items'] as List;
      return items
          .map((e) => leer(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      throw ApiProtocolException(200, 'Listado de $que inválido.');
    }
  }

  T _uno<T>(
    Object? json,
    T Function(Map<String, dynamic>) leer,
    String mensaje,
  ) {
    try {
      return leer(json as Map<String, dynamic>);
    } catch (_) {
      throw ApiProtocolException(200, mensaje);
    }
  }
}
