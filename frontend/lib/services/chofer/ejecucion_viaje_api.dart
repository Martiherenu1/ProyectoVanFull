import '../../controllers/chofer/ejecucion_viaje_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../models/chofer/viaje_resumen.dart';

/// CU-030: transporte de las acciones inyectables, sin sesión ni reintentos.
/// El contenedor externo conserva la propiedad del cliente y su base /api/.
final class EjecucionViajeApi {
  const EjecucionViajeApi(this._client);

  final ApiClient _client;

  Future<ViajeResumen> iniciar(int idViaje) =>
      _enviar(idViaje, 'inicio', permiteEnCurso: true);

  Future<ViajeResumen> finalizar(int idViaje) =>
      _enviar(idViaje, 'finalizacion', permiteEnCurso: false);

  Future<ViajeResumen> _enviar(
    int idViaje,
    String operacion, {
    required bool permiteEnCurso,
  }) async {
    try {
      final respuesta = await _client.post('/viajes/$idViaje/$operacion');
      if (respuesta is! Map<String, dynamic>) {
        throw const ResultadoViajeIncierto();
      }
      final viaje = ViajeResumen.fromJson(respuesta);
      if (viaje.idViaje != idViaje ||
          (viaje.estado != EstadoViaje.finalizado &&
              !(permiteEnCurso && viaje.estado == EstadoViaje.enCurso))) {
        throw const ResultadoViajeIncierto();
      }
      return viaje;
    } on ApiException catch (error) {
      final motivo = switch (error.statusCode) {
        400 => MotivoRechazoViaje.validacion,
        401 => MotivoRechazoViaje.noAutenticado,
        403 => MotivoRechazoViaje.sinPermiso,
        404 => MotivoRechazoViaje.noDisponible,
        409 => MotivoRechazoViaje.conflicto,
        _ => null,
      };
      if (motivo != null) {
        throw RechazoOperacionViaje(motivo, codigo: error.codigo);
      }
      throw const ResultadoViajeIncierto();
    } catch (_) {
      // Incluye red, protocolo y DTO inválido: el POST pudo haberse aplicado.
      // No conservar ni exponer cuerpos, mensajes o detalles del servidor.
      throw const ResultadoViajeIncierto();
    }
  }
}
