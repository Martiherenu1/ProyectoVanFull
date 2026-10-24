import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../models/chofer/operacion_asignada.dart';

/// No conserva datos recibidos ni detalles de deserialización.
final class DetalleViajeInvalidoException implements Exception {
  const DetalleViajeInvalidoException();

  @override
  String toString() => 'La respuesta del detalle del viaje es inválida.';
}

/// Adaptador CU-029. La base del cliente externo ya incluye /api/.
/// El propietario del cliente administra su sesión y ciclo de vida.
final class DetalleViajeChoferApi {
  const DetalleViajeChoferApi(this._client);

  final ApiClient _client;

  Future<OperacionAsignada?> cargarDetalle(int idViaje) async {
    final Object? respuesta;
    try {
      respuesta = await _client.get('/choferes/me/viajes/$idViaje');
    } on ApiException catch (error) {
      // Inexistente y ajeno tienen la misma representación para la pantalla.
      if (error.statusCode == 404) return null;
      rethrow;
    }
    if (respuesta is! Map<String, dynamic>) {
      throw const DetalleViajeInvalidoException();
    }
    try {
      final detalle = OperacionAsignada.fromJson(respuesta);
      if (detalle.viaje.idViaje != idViaje) {
        throw const DetalleViajeInvalidoException();
      }
      return detalle;
    } on FormatException {
      throw const DetalleViajeInvalidoException();
    } on TypeError {
      throw const DetalleViajeInvalidoException();
    }
  }
}
