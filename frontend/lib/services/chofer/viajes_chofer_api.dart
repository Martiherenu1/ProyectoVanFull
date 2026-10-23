import '../../core/api/api_client.dart';
import '../../models/chofer/viaje_resumen.dart';

/// Respuesta incompatible con el listado CU-029, sin conservar datos recibidos.
final class ListadoViajesInvalidoException implements Exception {
  const ListadoViajesInvalidoException();

  @override
  String toString() => 'La respuesta del listado de viajes es inválida.';
}

/// Consume CU-029 con un cliente externo cuya base ya incluye /api/.
/// El propietario externo administra sesión y ciclo de vida del transporte.
final class ViajesChoferApi {
  const ViajesChoferApi(this._client);

  final ApiClient _client;

  Future<List<ViajeResumen>> cargarViajes(DateTime fecha) async {
    if (fecha.year < 1 || fecha.year > 9999) {
      throw ArgumentError('La fecha debe tener un año entre 1 y 9999.');
    }
    final fechaTexto =
        '${fecha.year.toString().padLeft(4, '0')}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}';
    // Fuera del bloque de deserialización: conservar errores del cliente.
    final respuesta = await _client.get(
      '/choferes/me/viajes',
      queryParameters: {'fecha': fechaTexto},
    );
    if (respuesta is! List) {
      throw const ListadoViajesInvalidoException();
    }
    try {
      return List<ViajeResumen>.unmodifiable(
        respuesta.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const ListadoViajesInvalidoException();
          }
          return ViajeResumen.fromJson(item);
        }),
      );
    } on FormatException {
      throw const ListadoViajesInvalidoException();
    } on TypeError {
      throw const ListadoViajesInvalidoException();
    }
  }
}
