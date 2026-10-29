import '../../core/api/api_client.dart';
import '../../models/admin/viaje_admin_resumen.dart';
import '../../models/admin/viaje_create.dart';
import '../../models/admin/viaje_update.dart';
import '../../models/chofer/viaje_resumen.dart';

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

  Future<ViajeResumen> cancelarViaje(int idViaje) async {
    final cuerpo = await _client.post('viajes/$idViaje/cancelacion');
    if (cuerpo is! Map<String, dynamic>) {
      throw const ViajeCreadoInvalidoException();
    }
    try {
      return ViajeAdminResumen.fromJson(cuerpo);
    } on FormatException {
      throw const ViajeCreadoInvalidoException();
    } on TypeError {
      throw const ViajeCreadoInvalidoException();
    }
  }

  Future<ViajeCreado> crearViaje(ViajeCreate solicitud) async {
    final cuerpo = await _client.post('viajes', body: solicitud.toJson());
    if (cuerpo is! Map<String, dynamic>) {
      throw const ViajeCreadoInvalidoException();
    }
    return ViajeCreado.fromJson(cuerpo);
  }

  Future<ViajeResumen> actualizarViaje(
    int idViaje,
    ViajeUpdate solicitud,
  ) async {
    final cuerpo = await _client.patch(
      'viajes/$idViaje',
      body: solicitud.toJson(),
    );
    if (cuerpo is! Map<String, dynamic>) {
      throw const ViajeCreadoInvalidoException();
    }
    try {
      return ViajeAdminResumen.fromJson(cuerpo);
    } on FormatException {
      throw const ViajeCreadoInvalidoException();
    } on TypeError {
      throw const ViajeCreadoInvalidoException();
    }
  }
}
