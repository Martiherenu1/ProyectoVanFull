import '../../core/api/api_client.dart';

/// POST /ausencias: tanto 200 como 201 confirman el mismo aviso.
class AusenciasApi {
  const AusenciasApi(this._cliente);
  final ApiClient _cliente;

  Future<void> informar(int idViaje, {required String accessToken}) async {
    final cuerpo = await _cliente.post(
      'ausencias',
      body: {'id_viaje': idViaje},
      accessToken: accessToken,
    );
    if (cuerpo is! Map<String, dynamic> ||
        cuerpo['id_ausencia'] is! int ||
        cuerpo['id_pasajero'] is! int ||
        cuerpo['id_viaje'] != idViaje) {
      throw const FormatException('Respuesta de ausencia inválida.');
    }
  }
}
