import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../models/admin/chofer_admin.dart';

final class ChoferesAdminApi {
  const ChoferesAdminApi(this._client);

  final ApiClient _client;

  Future<List<ChoferAdmin>> listar() async {
    final cuerpo = await _client.get('choferes');
    if (cuerpo is! List) {
      throw const ApiProtocolException(200, 'Respuesta de choferes inválida.');
    }
    try {
      return List.unmodifiable(
        cuerpo.map((item) => ChoferAdmin.fromJson(item as Map<String, dynamic>)),
      );
    } on FormatException {
      throw const ApiProtocolException(200, 'Respuesta de choferes inválida.');
    } on TypeError {
      throw const ApiProtocolException(200, 'Respuesta de choferes inválida.');
    }
  }

  Future<ChoferAdmin> crear(ChoferAdminCreate solicitud) =>
      _chofer(() => _client.post('choferes', body: solicitud.toJson()));

  Future<ChoferAdmin> actualizar(int idPersona, ChoferAdminUpdate solicitud) =>
      _chofer(
        () => _client.patch('choferes/$idPersona', body: solicitud.toJson()),
      );

  Future<ChoferAdmin> _chofer(Future<Object?> Function() solicitud) async {
    final cuerpo = await solicitud();
    if (cuerpo is! Map<String, dynamic>) {
      throw const ApiProtocolException(200, 'Respuesta de chofer inválida.');
    }
    try {
      return ChoferAdmin.fromJson(cuerpo);
    } on FormatException {
      throw const ApiProtocolException(200, 'Respuesta de chofer inválida.');
    } on TypeError {
      throw const ApiProtocolException(200, 'Respuesta de chofer inválida.');
    }
  }
}
