import '../../core/api/api_client.dart';
import '../../models/admin/viaje_admin_resumen.dart';
import '../../models/chofer/viaje_resumen.dart';

/// Respuesta incompatible con `list[Viaje]`, sin conservar datos recibidos.
final class ListadoViajesAdminInvalidoException implements Exception {
  const ListadoViajesAdminInvalidoException();

  @override
  String toString() => 'La respuesta del listado administrativo es inválida.';
}

/// Consulta los viajes del día de CU-018 con un [ApiClient] externo.
///
/// El propietario del cliente aporta la sesión y controla su ciclo de vida.
/// Este adaptador no autentica, reintenta ni reordena la respuesta del backend.
final class ViajesDiaAdminApi {
  const ViajesDiaAdminApi(this._client);

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
      'viajes',
      queryParameters: {'fecha': fechaTexto},
    );
    if (respuesta is! List) {
      throw const ListadoViajesAdminInvalidoException();
    }
    try {
      return List<ViajeResumen>.unmodifiable(
        respuesta.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const ListadoViajesAdminInvalidoException();
          }
          return ViajeAdminResumen.fromJson(item);
        }),
      );
    } on FormatException {
      throw const ListadoViajesAdminInvalidoException();
    } on TypeError {
      throw const ListadoViajesAdminInvalidoException();
    }
  }
}
