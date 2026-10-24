import '../../core/api/api_client.dart';
import '../../models/admin/viaje_create.dart';

/// Adaptador administrativo de la creación parcial de CU-018.
///
/// El [ApiClient] externo aporta el token y conserva su ciclo de vida. La
/// autorización y las reglas del viaje se validan en FastAPI.
/// [ApiClient] acepta cualquier respuesta 2xx; este adaptador no distingue
/// específicamente el 201 declarado para esta operación.
/// Este adaptador todavía no está conectado a un formulario administrativo.
final class ViajesAdminApi {
  const ViajesAdminApi(this._client);

  final ApiClient _client;

  Future<ViajeCreado> crearViaje(ViajeCreate solicitud) async {
    final cuerpo = await _client.post('viajes', body: solicitud.toJson());
    if (cuerpo is! Map<String, dynamic>) {
      throw const ViajeCreadoInvalidoException();
    }
    return ViajeCreado.fromJson(cuerpo);
  }
}
